#!/usr/bin/env python3
"""Public XCUITest gestures against the already installed inline-test app.

Call run_touch_suite(device_udid, app_path, report_dir) AFTER existing inline
checks, BEFORE deleting their simulator. Returns a PASS receipt or raises;
ReplayTouchError.report_path identifies the always-written JSON on failure.
CLI: python3 tests/ui/run_replay_touch_tests.py --device UDID --app APP \
    --report-dir reports/replay-touch
No third-party Python modules, xcodegen, private HID, or app-side touch hooks.
Requires macOS/Xcode (intended: macOS 15 / Xcode 16.4); Linux exits 77, not PASS.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import shlex
import shutil
import subprocess
import sys
import time
import uuid
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
UI = Path(__file__).resolve().parent
BUNDLE = "com.minis.timantirecall.inlinetests"
SUITE = "TIMAntiRecallReplayTouchUITests"
TESTS = (
    "testSingleTapIncomingDoesNotSend", "testDoubleTapIncomingSendsExactlyOnce",
    "testDoubleTapOutgoingSendsExactlyOnce", "testDoubleTapNativeTextPreservesNativeGesture",
    "testLongPressDoesNotSend", "testDragDoesNotSend",
)


class ReplayTouchError(RuntimeError):
    def __init__(self, message: str, report_path: Path):
        super().__init__(f"{message}; evidence: {report_path}")
        self.report_path = report_path


class UnsupportedPlatform(ReplayTouchError):
    pass


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def tree_receipt(root: Path) -> dict:
    if not root.is_dir():
        raise ValueError(f"Missing bundle/source tree: {root}")
    files = {str(path.relative_to(root)): sha256(path)
             for path in sorted(root.rglob("*")) if path.is_file()}
    return {"sha256": files, "digest": hashlib.sha256(
        json.dumps(files, sort_keys=True, separators=(",", ":")).encode()).hexdigest()}


def source_receipt() -> dict:
    paths = [Path(__file__).resolve(), UI / f"{SUITE}.m", UI / "run_inline_ui_tests.py"]
    for directory in (ROOT / "Sources", ROOT / "Headers", UI):
        paths.extend(path for path in directory.rglob("*")
                     if path.is_file() and path.suffix in {".m", ".h", ".swift"})
    hashes = {str(path.relative_to(ROOT)): sha256(path) for path in sorted(set(paths))}
    return {"sha256": hashes, "digest": hashlib.sha256(
        json.dumps(hashes, sort_keys=True, separators=(",", ":")).encode()).hexdigest()}


def _openstep(value, indent: int = 0) -> str:
    """Serialize the small generated pbxproj without a project dependency."""
    pad = "\t" * indent
    if isinstance(value, dict):
        return "{\n" + "".join(pad + "\t" + json.dumps(str(key)) + " = " +
            _openstep(item, indent + 1) + ";\n" for key, item in value.items()) + pad + "}"
    if isinstance(value, list):
        return "(" + ", ".join(_openstep(item, indent) for item in value) + ")"
    return json.dumps(str(value))


def generate_project(work: Path) -> Path:
    """Separate dummy AUT keeps xcodebuild from replacing the supplied app."""
    work.mkdir(parents=True, exist_ok=True)
    shutil.copy2(UI / f"{SUITE}.m", work / f"{SUITE}.m")
    (work / "main.m").write_text(
        '#import <UIKit/UIKit.h>\n'
        '@interface ReplayTouchHostDelegate : UIResponder <UIApplicationDelegate>\n'
        '@property(nonatomic,strong) UIWindow *window;\n@end\n'
        '@implementation ReplayTouchHostDelegate\n'
        '- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {\n'
        '(void)app; (void)opts; self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];\n'
        'self.window.rootViewController=[UIViewController new]; [self.window makeKeyAndVisible]; return YES;\n}\n'
        '@end\nint main(int argc,char **argv) { @autoreleasepool {\n'
        'return UIApplicationMain(argc,argv,nil,NSStringFromClass(ReplayTouchHostDelegate.class)); }}\n')
    objects = {}

    def ident(name):
        return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

    def put(object_name, isa, **fields):
        key = ident(object_name)
        objects[key] = {"isa": isa, **fields}
        return key

    def configurations(name, settings):
        entries = [put(name + mode, "XCBuildConfiguration", name=mode,
                       buildSettings=settings.copy()) for mode in ("Debug", "Release")]
        return put(name + "Configs", "XCConfigurationList", buildConfigurations=entries,
                   defaultConfigurationIsVisible="0", defaultConfigurationName="Debug")

    source_files = []
    targets = []
    products = []
    for name, filename, product_type, extension in (
        ("ReplayTouchHost", "main.m", "application", "app"),
        ("ReplayTouchUITests", f"{SUITE}.m", "bundle.ui-testing", "xctest"),
    ):
        source = put(name + "File", "PBXFileReference", lastKnownFileType="sourcecode.c.objc",
                     path=filename, sourceTree="<group>")
        source_files.append(source)
        build_file = put(name + "BuildFile", "PBXBuildFile", fileRef=source)
        sources = put(name + "Sources", "PBXSourcesBuildPhase", buildActionMask="2147483647",
                      files=[build_file], runOnlyForDeploymentPostprocessing="0")
        frameworks = put(name + "Frameworks", "PBXFrameworksBuildPhase", buildActionMask="2147483647",
                         files=[], runOnlyForDeploymentPostprocessing="0")
        product = put(name + "Product", "PBXFileReference", explicitFileType=(
            "wrapper.application" if extension == "app" else "wrapper.cfbundle"),
            includeInIndex="0", path=name + "." + extension, sourceTree="BUILT_PRODUCTS_DIR")
        products.append(product)
        settings = {"PRODUCT_NAME": "$(TARGET_NAME)", "GENERATE_INFOPLIST_FILE": "YES",
                    "CURRENT_PROJECT_VERSION": "1", "MARKETING_VERSION": "1.0",
                    "PRODUCT_BUNDLE_IDENTIFIER": "com.minis.timantirecall." + name.lower(),
                    "TARGETED_DEVICE_FAMILY": "1,2", "CODE_SIGN_IDENTITY": "-",
                    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"]}
        dependencies = []
        if extension == "app":
            settings.update({"INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
                             "OTHER_LDFLAGS": ["$(inherited)", "-framework", "UIKit"]})
        else:
            settings.update({"TEST_TARGET_NAME": "ReplayTouchHost",
                             "FRAMEWORK_SEARCH_PATHS": ["$(inherited)", "$(PLATFORM_DIR)/Developer/Library/Frameworks"],
                             "OTHER_LDFLAGS": ["$(inherited)", "-framework", "XCTest"]})
            proxy = put("HostProxy", "PBXContainerItemProxy", containerPortal=ident("Project"),
                        proxyType="1", remoteGlobalIDString=ident("ReplayTouchHost"), remoteInfo="ReplayTouchHost")
            dependencies = [put("HostDependency", "PBXTargetDependency", target=ident("ReplayTouchHost"), targetProxy=proxy)]
        targets.append(put(name, "PBXNativeTarget", name=name, productName=name,
                           buildConfigurationList=configurations(name, settings),
                           buildPhases=[sources, frameworks], buildRules=[], dependencies=dependencies,
                           productReference=product, productType="com.apple.product-type." + product_type))
    products_group = put("Products", "PBXGroup", children=products, name="Products", sourceTree="<group>")
    main_group = put("MainGroup", "PBXGroup", children=source_files + [products_group], sourceTree="<group>")
    project_settings = {"SDKROOT": "iphonesimulator", "SUPPORTED_PLATFORMS": "iphonesimulator",
                        "IPHONEOS_DEPLOYMENT_TARGET": "16.5", "CLANG_ENABLE_MODULES": "YES",
                        "CLANG_ENABLE_OBJC_ARC": "YES", "GCC_C_LANGUAGE_STANDARD": "gnu11",
                        "GCC_TREAT_WARNINGS_AS_ERRORS": "YES", "GCC_OPTIMIZATION_LEVEL": "0",
                        "ONLY_ACTIVE_ARCH": "YES", "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym"}
    project_id = put("Project", "PBXProject", attributes={"LastUpgradeCheck": "1640",
                     "TargetAttributes": {ident("ReplayTouchUITests"): {"TestTargetID": ident("ReplayTouchHost")}}},
                     buildConfigurationList=configurations("Project", project_settings),
                     compatibilityVersion="Xcode 14.0", developmentRegion="en", hasScannedForEncodings="0",
                     knownRegions=["en", "Base"], mainGroup=main_group, productRefGroup=products_group,
                     projectDirPath="", projectRoot="", targets=targets)
    project = work / "ReplayTouch.xcodeproj"
    project.mkdir()
    (project / "project.pbxproj").write_text("// !$*UTF8*$!\n" + _openstep({
        "archiveVersion": "1", "classes": {}, "objectVersion": "56",
        "objects": objects, "rootObject": project_id}) + "\n")
    schemes = project / "xcshareddata" / "xcschemes"
    schemes.mkdir(parents=True)
    scheme = ET.Element("Scheme", LastUpgradeVersion="1640", version="1.3")

    def reference(parent, name, extension):
        ET.SubElement(parent, "BuildableReference", BuildableIdentifier="primary",
                      BlueprintIdentifier=ident(name), BuildableName=name + "." + extension,
                      BlueprintName=name, ReferencedContainer="container:ReplayTouch.xcodeproj")

    build = ET.SubElement(scheme, "BuildAction", parallelizeBuildables="NO", buildImplicitDependencies="YES")
    entries = ET.SubElement(build, "BuildActionEntries")
    for name, extension in (("ReplayTouchHost", "app"), ("ReplayTouchUITests", "xctest")):
        entry = ET.SubElement(entries, "BuildActionEntry", buildForTesting="YES", buildForRunning="NO",
                              buildForProfiling="NO", buildForArchiving="NO", buildForAnalyzing="YES")
        reference(entry, name, extension)
    test = ET.SubElement(scheme, "TestAction", buildConfiguration="Debug",
                         selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB",
                         selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", shouldUseLaunchSchemeArgsEnv="NO")
    testable = ET.SubElement(ET.SubElement(test, "Testables"), "TestableReference", skipped="NO", parallelizable="NO")
    reference(testable, "ReplayTouchUITests", "xctest")
    ET.ElementTree(scheme).write(schemes / "ReplayTouch.xcscheme", encoding="utf-8", xml_declaration=True)
    return project


def _value(node, default=None):
    return node.get("_value", default) if isinstance(node, dict) else default


def parse_test_records(document: dict) -> list[dict]:
    """Read real xcresult ActionTestMetadata, never infer PASS from console text."""
    records = []

    def visit(node):
        if isinstance(node, dict):
            if "testStatus" in node:
                identifier = _value(node.get("identifier")) or _value(node.get("name"), "")
                records.append({"identifier": identifier, "status": _value(node["testStatus"]),
                                "method": identifier.rsplit("/", 1)[-1].split("(", 1)[0]})
            for child in node.values():
                visit(child)
        elif isinstance(node, list):
            for child in node:
                visit(child)

    visit(document)
    return records


def run_touch_suite(device, app_path, report_dir) -> dict:
    """Owns only a UUID evidence directory; never deletes/recreates the device.

    Failure (including unsupported hosts) writes report.json and raises. Caller
    MUST propagate the exception/nonzero exit as a failing gate, not a warning.
    """
    app = Path(app_path).expanduser().resolve()
    report_root = Path(report_dir).expanduser().resolve()
    token = str(uuid.uuid4())
    evidence = report_root / ("replay-touch-" + token)
    evidence.mkdir(parents=True, exist_ok=False)
    report_path = evidence / "report.json"
    xcresult = evidence / "ReplayTouch.xcresult"
    logfile = evidence / "xcodebuild.log"
    command_log = evidence / "commands.log"
    receipt = {"schemaVersion": 1, "status": "RUNNING", "runToken": token,
               "deviceUDID": str(device), "appPath": str(app), "bundleIdentifier": BUNDLE,
               "reportPath": str(report_path), "evidenceDirectory": str(evidence),
               "xcresultPath": str(xcresult), "xcodebuildLog": str(logfile),
               "startedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
               "platform": platform.platform(), "expectedTests": list(TESTS), "commands": [],
               "githubRunID": os.environ.get("GITHUB_RUN_ID"),
               "githubRunAttempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
               "githubSHA": os.environ.get("GITHUB_SHA")}

    def save():
        temporary = report_path.with_suffix(".tmp")
        temporary.write_text(json.dumps(receipt, indent=2, ensure_ascii=False) + "\n")
        temporary.replace(report_path)

    def command(args, *, timeout=120, output=None, check=True):
        args = [str(arg) for arg in args]
        entry = {"argv": args}
        receipt["commands"].append(entry)
        print("RUN " + shlex.join(args), flush=True)
        with command_log.open("a") as stream:
            stream.write("RUN " + shlex.join(args) + "\n")
        save()
        start = time.monotonic()
        try:
            if output is not None:
                with Path(output).open("w") as stream:
                    result = subprocess.run(args, stdout=stream, stderr=subprocess.STDOUT,
                                            timeout=timeout, text=True)
                text = Path(output).read_text(errors="replace")
            else:
                result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                        timeout=timeout, text=True)
                text = result.stdout
            entry["returncode"] = result.returncode
            with command_log.open("a") as stream:
                stream.write(text + "\n")
            if output is not None and Path(output) == logfile:
                print(text, end="" if text.endswith("\n") else "\n", flush=True)
            if check and result.returncode:
                raise RuntimeError(f"Command exited {result.returncode}: {shlex.join(args)}")
            return text
        except subprocess.TimeoutExpired as error:
            entry["timedOutSeconds"] = timeout
            text = Path(output).read_text(errors="replace") if output and Path(output).exists() else error.stdout or ""
            if isinstance(text, bytes):
                text = text.decode(errors="replace")
            with command_log.open("a") as stream:
                stream.write(text + f"\nTIMEOUT after {timeout}s\n")
            if text:
                print(text, flush=True)
            raise
        finally:
            entry["elapsedSeconds"] = round(time.monotonic() - start, 3)
            save()

    save()
    try:
        if sys.platform != "darwin" or not shutil.which("xcodebuild") or not shutil.which("xcrun"):
            raise UnsupportedPlatform("Real XCUITest requires macOS and full Xcode; NOT a PASS", report_path)
        if not app.is_dir() or not (app / "Info.plist").is_file():
            raise ValueError(f"Missing built app: {app}")
        with (app / "Info.plist").open("rb") as stream:
            info = plistlib.load(stream)
        if info.get("CFBundleIdentifier") != BUNDLE:
            raise ValueError(f"Wrong host bundle identifier: {info.get('CFBundleIdentifier')}")
        executable = info.get("CFBundleExecutable", "")
        if not executable or Path(executable).name != executable or not (app / executable).is_file():
            raise ValueError("Host app has no valid executable")
        receipt["xcodeVersion"] = command(["xcodebuild", "-version"]).strip()
        receipt["macOSVersion"] = command(["sw_vers", "-productVersion"]).strip()
        receipt["developerDirectory"] = command(["xcode-select", "-p"]).strip()
        receipt["sdkVersion"] = command(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"]).strip()
        receipt["commit"] = command(["git", "-C", ROOT, "rev-parse", "HEAD"]).strip()
        receipt["branch"] = command(["git", "-C", ROOT, "branch", "--show-current"]).strip()
        receipt["dirty"] = command(["git", "-C", ROOT, "status", "--short"]).strip()
        receipt["sourcesBefore"] = source_receipt()
        receipt["hostBundleBefore"] = tree_receipt(app)
        build_receipt = app / "tim-inline-build.json"
        if build_receipt.is_file():
            receipt["hostBuildReceipt"] = json.loads(build_receipt.read_text())
        devices = json.loads(command(["xcrun", "simctl", "list", "devices", "-j"]))
        matches = [(runtime, item) for runtime, items in devices.get("devices", {}).items()
                   for item in items if item.get("udid") == str(device)]
        if len(matches) != 1 or matches[0][1].get("state") != "Booted":
            raise ValueError("device must be an exact UDID of one already booted simulator")
        receipt["runtime"], receipt["device"] = matches[0]
        command(["codesign", "--verify", "--strict", "--verbose=2", app])
        installed = Path(command(["xcrun", "simctl", "get_app_container", device, BUNDLE, "app"]).strip())
        receipt["installedAppPath"] = str(installed)
        installed_before = tree_receipt(installed)
        receipt["installedBundleBefore"] = installed_before
        if installed_before != receipt["hostBundleBefore"]:
            raise RuntimeError("Installed app bytes do not match app_path; refusing stale-host tests")
        command(["codesign", "--verify", "--strict", "--verbose=2", installed])
        project = generate_project(evidence / "project")
        receipt["generatedProject"] = tree_receipt(project.parent)
        command(["plutil", "-lint", project / "project.pbxproj"])
        derived = evidence / "DerivedData"
        # Use the normal Xcode test action so it generates its own xctestrun,
        # runner entitlements and signing. Never construct a guessed xctestrun.
        command(["xcodebuild", "test", "-project", project, "-scheme", "ReplayTouch",
                 "-configuration", "Debug", "-sdk", "iphonesimulator",
                 "-destination", f"platform=iOS Simulator,id={device}",
                 "-destination-timeout", "60", "-derivedDataPath", derived,
                 "-resultBundlePath", xcresult, "-parallel-testing-enabled", "NO",
                 "-maximum-concurrent-test-simulator-destinations", "1",
                 "-only-testing:ReplayTouchUITests/" + SUITE], timeout=900, output=logfile)
        if not xcresult.is_dir():
            raise RuntimeError("xcodebuild returned success without an xcresult bundle")
        # Xcode 16 supports its legacy object schema with an explicit --legacy.
        # Preserve raw documents so parser/API incompatibility is diagnosable.
        summary = json.loads(command(["xcrun", "xcresulttool", "get", "object", "--legacy",
                                      "--path", xcresult, "--format", "json"],
                                     output=evidence / "xcresult-root.json"))
        refs = [_value(action.get("actionResult", {}).get("testsRef", {}).get("id"))
                for action in summary.get("actions", {}).get("_values", [])]
        records = []
        for index, reference in enumerate(ref for ref in refs if ref):
            document = json.loads(command(["xcrun", "xcresulttool", "get", "object", "--legacy",
                                           "--path", xcresult, "--id", reference, "--format", "json"],
                                          output=evidence / f"xcresult-tests-{index}.json"))
            records.extend(parse_test_records(document))
        receipt["tests"] = records
        if len(records) != len(TESTS) or sorted(item["method"] for item in records) != sorted(TESTS):
            raise RuntimeError("xcresult does not contain exactly the six required test methods")
        if any(item["status"] != "Success" for item in records):
            raise RuntimeError("xcresult contains failed/skipped/non-successful tests")
        receipt["sourcesAfter"] = source_receipt()
        receipt["hostBundleAfter"] = tree_receipt(app)
        installed_after = Path(command(["xcrun", "simctl", "get_app_container", device, BUNDLE, "app"]).strip())
        receipt["installedBundleAfter"] = tree_receipt(installed_after)
        if receipt["sourcesAfter"] != receipt["sourcesBefore"]:
            raise RuntimeError("Sources changed during the touch suite")
        if receipt["hostBundleAfter"] != receipt["hostBundleBefore"] or receipt["installedBundleAfter"] != installed_before:
            raise RuntimeError("Host app bundle changed during the touch suite")
        receipt["status"] = "PASS"
        return receipt
    except BaseException as error:
        receipt["status"] = "UNSUPPORTED" if isinstance(error, UnsupportedPlatform) else "FAIL"
        receipt["error"] = f"{type(error).__name__}: {error}"
        (evidence / "failure.txt").write_text(receipt["error"] + "\n")
        print(receipt["error"], file=sys.stderr, flush=True)
        if isinstance(error, (UnsupportedPlatform, KeyboardInterrupt, SystemExit)):
            raise
        raise ReplayTouchError(str(error), report_path) from error
    finally:
        receipt["finishedAt"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        receipt["xcresultExists"] = xcresult.is_dir()
        for key, path in (("xcodebuildLogSHA256", logfile), ("commandsLogSHA256", command_log)):
            if path.is_file():
                receipt[key] = sha256(path)
        save()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True, help="Already booted simulator UDID")
    parser.add_argument("--app", required=True, type=Path, help="Already installed inline-test .app")
    parser.add_argument("--report-dir", required=True, type=Path)
    args = parser.parse_args()
    try:
        receipt = run_touch_suite(args.device, args.app, args.report_dir)
        print(f"PASS: {len(receipt['tests'])} real touch tests; {receipt['reportPath']}", flush=True)
        return 0
    except UnsupportedPlatform as error:
        print(error, file=sys.stderr)
        return 77
    except ReplayTouchError as error:
        print(error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
