#!/usr/bin/env python3
"""Compile production Swift/ObjC, then require an actual scene-app simulator PASS.

No device binaries, network, test replacements for matcher/UI/Swift, or remote CI
operations. Exit 77 on non-macOS; this is intentionally not a successful gate.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
UI = Path(__file__).resolve().parent
REPORT = ROOT / "reports" / "inline-ui"
BUNDLE = "com.minis.timantirecall.inlinetests"
EXECUTABLE = "TIMAntiRecallInlineTests"
DEPLOY = "16.5"
TIMEOUT = 180
RESULT_TIMEOUT = 240
PRODUCTION = (
    "Sources/TIMAntiRecallMarks.m", "Sources/TIMAntiRecallWire.m",
    "Sources/TIMAntiRecallInline.m", "Sources/TIMAntiRecallIndicatorView.m",
    "Sources/TIMAntiRecallSession.m", "Sources/TIMAntiRecallLegacy.m",
    "Sources/TIMAntiRecallRuntime.m", "Sources/TIMAntiRecallColdSync.m", "Sources/TIMAntiRecallSettings.m",
    "Sources/TIMAntiRecallStorage.m", "Sources/TIMAntiRecallMarkStore.m",
    "Sources/TIMAntiRecallPreferencesUI.m", "Sources/TIMAntiRecallPreferencesEntry.m",
)
SWIFT = ("Sources/TIMAntiRecallRecordBridge.swift",
         "tests/ui/TIMAntiRecallSwiftFixture.swift")
FIXTURES = ("TIMAntiRecallFixture.m", "TIMAntiRecallInlineUIKitTests.m")
FRAMEWORKS = ("Foundation", "UIKit", "QuartzCore")
REQUIRED_COVERAGE = {
    "swift-reflection", "session-owner", "bind-abi", "private-identity",
    "group-identity", "account-isolation", "reuse-lifecycle", "row-geometry",
    "touch-routing", "weak-release", "real-scene-background", "real-scene-resume",
    "swift-direct-binding", "legacy-conversion-binding", "push-to-row", "startup-owner",
    "chat-forwarding", "captured-time", "persist-ui", "preferences-entry", "preferences-controls", "preferences-visible",
}
COMMANDS: list[list[str]] = []
TRANSCRIPT: list[str] = []


def run(args: list, *, timeout: int = TIMEOUT, check: bool = True) -> str:
    command = [str(arg) for arg in args]
    COMMANDS.append(command)
    print("RUN " + shlex.join(command), flush=True)
    TRANSCRIPT.append("RUN " + shlex.join(command))
    try:
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        partial = error.stdout or ""
        TRANSCRIPT.append(partial.decode(errors="replace") if isinstance(partial, bytes) else partial)
        TRANSCRIPT.append(f"TIMEOUT after {timeout}s")
        raise
    if result.stdout:
        print(result.stdout.rstrip(), flush=True)
        TRANSCRIPT.append(result.stdout)
    if check and result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}): {shlex.join(command)}")
    return result.stdout.strip()


def version(value: str) -> tuple[int, ...]:
    match = re.fullmatch(r"(\d+(?:\.\d+)*)", value)
    if not match:
        raise ValueError(f"Invalid SDK/runtime version: {value!r}")
    parts = tuple(int(piece) for piece in value.split("."))
    return (parts + (0, 0, 0))[:3]


def choose_runtime(sdk: str, runtimes: dict, devices: dict) -> tuple[str, str, str]:
    candidates = []
    for item in runtimes.get("runtimes", []):
        if not item.get("isAvailable") or ".iOS-" not in item.get("identifier", ""):
            continue
        current = version(item["version"])
        if version(DEPLOY) <= current <= version(sdk):
            candidates.append((current, item))
    # Prefer the user's 16.5 if installed; otherwise record the actual runtime.
    candidates.sort(key=lambda pair: (pair[0] == version(DEPLOY), pair[0]), reverse=True)
    for _, item in candidates:
        phones = [phone for phone in devices.get("devices", {}).get(item["identifier"], [])
                  if phone.get("isAvailable") and "iphone" in phone.get("name", "").lower()
                  and phone.get("deviceTypeIdentifier")]
        if phones:
            phones.sort(key=lambda phone: phone["name"])
            return item["identifier"], phones[0]["deviceTypeIdentifier"], item["version"]
    raise RuntimeError(f"No available iPhone simulator >= {DEPLOY} and <= SDK {sdk}")


def source_receipt() -> dict:
    paths = [ROOT / item for item in (*PRODUCTION, *SWIFT)]
    paths += sorted((ROOT / "Headers").glob("*.h"))
    paths += sorted(path for path in UI.iterdir() if path.is_file() and path.suffix in {".m", ".h", ".swift", ".py"})
    hashes = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
              for path in sorted(set(paths))}
    digest = hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest()
    return {"sourceDigest": digest, "sha256": hashes,
            "commit": run(["git", "-C", ROOT, "rev-parse", "HEAD"]),
            "branch": run(["git", "-C", ROOT, "branch", "--show-current"]),
            "dirty": run(["git", "-C", ROOT, "status", "--short"]),
            "githubRunID": os.environ.get("GITHUB_RUN_ID"),
            "githubRunAttempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
            "githubSHA": os.environ.get("GITHUB_SHA")}


def build_app(work: Path, sdk: str, receipt: dict) -> Path:
    app = work / f"{EXECUTABLE}.app"
    app.mkdir()
    architecture = "arm64" if platform.machine() in ("arm64", "aarch64") else "x86_64"
    target = f"{architecture}-apple-ios{DEPLOY}-simulator"
    receipt.update({"target": target, "deployment": DEPLOY, "sdkPath": sdk})
    clang = run(["xcrun", "--sdk", "iphonesimulator", "--find", "clang"])
    swiftc = run(["xcrun", "--sdk", "iphonesimulator", "--find", "swiftc"])
    receipt["swiftVersion"] = run([swiftc, "--version"])
    receipt["clangVersion"] = run([clang, "--version"])
    swift_object = work / "TIMAntiRecallSwift.o"
    swift_header = work / "TIMAntiRecall-Swift.h"
    # WMO gives one object for both real Swift inputs. Header is emitted by Swift,
    # never a handwritten declaration or an Objective-C reflection substitute.
    run([swiftc, "-sdk", sdk, "-target", target, "-swift-version", "5",
         "-parse-as-library", "-whole-module-optimization", "-Onone", "-g",
         "-D", "TIMANTIRECALL_UI_TEST", "-module-name", "TIMAntiRecall",
         "-import-objc-header", UI / "TIMAntiRecallFixture.h",
         "-emit-object", "-emit-module", "-emit-module-path", work / "TIMAntiRecall.swiftmodule",
         "-emit-objc-header", "-emit-objc-header-path", swift_header,
         *[ROOT / path for path in SWIFT], "-o", swift_object])
    if not swift_header.is_file() or "timantirecall_recordForViewModel:" not in swift_header.read_text():
        raise RuntimeError("Swift did not emit the actual bridge Objective-C header")
    shutil.copy2(swift_header, REPORT / swift_header.name)
    receipt["swiftHeaderSHA256"] = hashlib.sha256(swift_header.read_bytes()).hexdigest()
    receipt["swiftModuleEmitted"] = (work / "TIMAntiRecall.swiftmodule").is_file()
    if not receipt["swiftModuleEmitted"]:
        raise RuntimeError("Swift did not emit the actual module")
    objects = [swift_object]
    sources = [ROOT / path for path in PRODUCTION] + [UI / name for name in FIXTURES]
    for index, source in enumerate(sources):
        obj = work / f"{index}_{source.stem}.o"
        run([clang, "-fobjc-arc", "-fblocks", "-fmodules", "-g", "-O0",
             "-target", target, "-isysroot", sdk, "-Wall", "-Wextra", "-Werror",
             "-DTIMANTIRECALL_UI_TEST=1", "-I", ROOT / "Headers", "-I", ROOT / "Sources",
             "-I", UI, "-I", work, "-c", source, "-o", obj])
        objects.append(obj)
    # Swift's driver supplies autolink extraction and toolchain Swift libraries.
    # iOS >= 16.5 supplies the stable runtime at /usr/lib/swift in the simulator.
    link = [swiftc, "-sdk", sdk, "-target", target, "-emit-executable", *objects,
            "-Xlinker", "-rpath", "-Xlinker", "/usr/lib/swift"]
    for framework in FRAMEWORKS:
        link.extend(["-framework", framework])
    run([*link, "-o", app / EXECUTABLE])
    (app / "Info.plist").write_bytes(plistlib.dumps({
        "CFBundleIdentifier": BUNDLE, "CFBundleExecutable": EXECUTABLE,
        "CFBundleName": EXECUTABLE, "CFBundlePackageType": "APPL",
        "CFBundleVersion": "1", "CFBundleShortVersionString": "1.0",
        "MinimumOSVersion": DEPLOY, "LSRequiresIPhoneOS": True,
        "UIDeviceFamily": [1], "UILaunchScreen": {},
        "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
        "UIApplicationSceneManifest": {
            "UIApplicationSupportsMultipleScenes": False,
            "UISceneConfigurations": {"UIWindowSceneSessionRoleApplication": [{
                "UISceneConfigurationName": "Inline tests", "UISceneClassName": "UIWindowScene",
                "UISceneDelegateClassName": "TIMAntiRecallTestSceneDelegate"}]}}}))
    (app / "tim-inline-build.json").write_text(json.dumps(receipt, indent=2))
    run(["codesign", "--force", "--sign", "-", "--timestamp=none", app])
    run(["codesign", "--verify", "--strict", "--verbose=2", app])
    receipt["macho"] = run(["xcrun", "otool", "-l", app / EXECUTABLE])
    receipt["dylibs"] = run(["xcrun", "otool", "-L", app / EXECUTABLE])
    return app


def read_json(path: Path) -> dict | None:
    if not path.is_file():
        return None
    try:
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else None
    except (OSError, json.JSONDecodeError):
        return None


def validate_result(result: dict, token: str, digest: str) -> None:
    if result.get("runToken") != token or result.get("sourceDigest") != digest:
        raise RuntimeError("Stale or wrong-source simulator result")
    if result.get("status") != "PASS" or result.get("failures") != []:
        raise RuntimeError(f"UIKit assertions failed: {result.get('failures')}")
    if type(result.get("checks")) is not int or result["checks"] <= 0:
        raise RuntimeError("UIKit result has no positive checks count")
    if result.get("mode") != "real-uikit-scene" or not result.get("sceneBackgroundObserved"):
        raise RuntimeError("Missing actual scene background evidence")
    if not result.get("sceneResumeObserved"):
        raise RuntimeError("Missing actual scene resume evidence")
    missing = REQUIRED_COVERAGE - set(result.get("coverage", []))
    if missing:
        raise RuntimeError(f"Missing required UIKit coverage: {sorted(missing)}")
    if not result.get("previewWritten"):
        raise RuntimeError("App did not write a UIKit preview")


def run_screenshot(device: str, destination: Path) -> None:
    errors = []
    for attempt in range(1, 4):
        try:
            run(["xcrun", "simctl", "io", device, "screenshot", destination], timeout=30)
            return
        except (subprocess.SubprocessError, RuntimeError) as error:
            errors.append(str(error))
            print(f"Simulator screenshot attempt {attempt}/3 failed: {error}", flush=True)
    raise RuntimeError("Simulator screenshot failed after 3 bounded attempts: " + " | ".join(errors[-2:]))


def wait_for_result(device: str, documents: Path, token: str, receipt: dict) -> dict:
    deadline = time.monotonic() + RESULT_TIMEOUT
    stage = ""
    background_sent = False
    foreground_sent = False
    settings_sent = False
    while time.monotonic() < deadline:
        # A result is terminal even when FAIL; never wait for a later PASS.
        result = read_json(documents / "tim-inline-result.json")
        if result is not None:
            (REPORT / "tim-inline-result.json").write_text(json.dumps(result, indent=2, ensure_ascii=False))
            validate_result(result, token, receipt["sourceDigest"])
            if not settings_sent:
                raise RuntimeError("App reported success before actual settings compositor screenshot")
            if not (background_sent and foreground_sent):
                raise RuntimeError("App reported success before real simulator lifecycle actions")
            return result
        checkpoint = read_json(documents / "tim-inline-stage.json")
        if checkpoint and checkpoint.get("runToken") == token:
            current = checkpoint.get("stage", "")
            if current != stage:
                print(f"APP STAGE {current}", flush=True)
                stage = current
            if current == "settings-ready" and not settings_sent:
                run_screenshot(device, REPORT / "tim-inline-settings-simulator.png")
                (documents / "tim-inline-settings-captured.json").write_text(json.dumps({'runToken': token}))
                settings_sent = True
            elif current == "ready-for-background" and not background_sent:
                run_screenshot(device, REPORT / "tim-inline-simulator.png")
                # Safari is local on every iPhone runtime. No external page needed.
                run(["xcrun", "simctl", "launch", device, "com.apple.mobilesafari"], timeout=30)
                background_sent = True
            elif current == "background-observed" and background_sent and not foreground_sent:
                # Do not terminate: the same scene, observers and rows must resume.
                run(["xcrun", "simctl", "launch", device, BUNDLE], timeout=30)
                foreground_sent = True
        time.sleep(0.25)
    raise TimeoutError(f"No final Documents/tim-inline-result.json after {RESULT_TIMEOUT}s; last stage={stage}")


def validate_restart_result(result: dict, token: str, digest: str) -> None:
    if result.get('runToken') != token or result.get('sourceDigest') != digest:
        raise RuntimeError('Stale or wrong-source restart result')
    if result.get('status') != 'PASS' or result.get('failures') != [] or not result.get('restoredBeforePush'):
        raise RuntimeError(f"Cold process restoration failed: {result.get('failures')}")
    if type(result.get('checks')) is not int or result['checks'] < 8:
        raise RuntimeError('Restart result lacks executed checks')
    if type(result.get('newPID')) is not int or type(result.get('oldPID')) is not int or result['newPID'] <= 0 or result['oldPID'] <= 0 or result['newPID'] == result['oldPID']:
        raise RuntimeError('Restart did not create a different app process')


def run_restart(device: str, documents: Path, receipt: dict) -> None:
    path = documents / 'tim-inline-restart-result.json'
    if path.exists():
        path.unlink()
    run(['xcrun', 'simctl', 'terminate', device, BUNDLE], timeout=30)
    run(['xcrun', 'simctl', 'launch', device, BUNDLE, '--timantirecall-restore-only'], timeout=40)
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        result = read_json(path)
        if result is not None:
            (REPORT / path.name).write_text(json.dumps(result, indent=2, ensure_ascii=False))
            validate_restart_result(result, receipt['runToken'], receipt['sourceDigest'])
            receipt['restartVerified'] = True
            print(f"PASS cold app restart: {result['oldPID']} -> {result['newPID']}; {result['checks']} checks", flush=True)
            return
        time.sleep(0.25)
    raise TimeoutError('No cold restart result within 45 seconds')


def validate_previews(report: Path) -> None:
    for name in ("tim-inline-preview.png", "tim-inline-simulator.png", "tim-inline-settings-preview.png", "tim-inline-settings-simulator.png"):
        path = report / name
        if not path.is_file() or path.stat().st_size < 128 or path.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n":
            raise RuntimeError(f"Missing real UIKit/simulator screenshot: {name}")


def collect(device: str, data: Path | None) -> None:
    if data:
        for path in (data / "Documents").glob("tim-inline-*"):
            if path.is_file():
                shutil.copy2(path, REPORT / path.name)
    if device:
        try:
            run(["xcrun", "simctl", "io", device, "screenshot", REPORT / "tim-inline-final-screen.png"], timeout=20)
        except (RuntimeError, subprocess.SubprocessError) as error:
            print(f"Diagnostic screenshot unavailable: {error}", flush=True)
        try:
            text = run(["xcrun", "simctl", "spawn", device, "log", "show", "--last", "3m",
                        "--style", "compact", "--predicate", f'process == "{EXECUTABLE}"'], timeout=20, check=False)
            (REPORT / "app-system.log").write_text(text)
        except subprocess.SubprocessError as error:
            (REPORT / "app-system.log").write_text(f"Diagnostic log timeout: {error}")
        roots = [Path.home() / "Library/Logs/DiagnosticReports",
                 Path.home() / "Library/Developer/CoreSimulator/Devices" / device / "data/Library/Logs/CrashReporter"]
        for root in roots:
            if root.is_dir():
                for path in root.glob(f"{EXECUTABLE}*"):
                    if path.is_file():
                        shutil.copy2(path, REPORT / path.name)


def main() -> int:
    if sys.platform != "darwin" or not shutil.which("xcrun"):
        print("SKIP: real UIKit simulator needs macOS/Xcode; not a PASS (exit 77).", file=sys.stderr)
        return 77
    REPORT.mkdir(parents=True, exist_ok=True)
    # Fixed report location is safe only after removing earlier run evidence.
    for path in REPORT.glob("*"):
        if path.is_file():
            path.unlink()
    work = Path(tempfile.mkdtemp(prefix="tim-inline-simulator-"))
    token = str(uuid.uuid4())
    receipt: dict = {"runToken": token}
    device = ""
    data = None
    status = 1
    try:
        receipt.update(source_receipt())
        receipt["xcodeVersion"] = run(["xcodebuild", "-version"])
        sdk = run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"])
        sdk_version = run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"])
        runtimes = json.loads(run(["xcrun", "simctl", "list", "runtimes", "-j"]))
        devices = json.loads(run(["xcrun", "simctl", "list", "devices", "-j"]))
        runtime, device_type, runtime_version = choose_runtime(sdk_version, runtimes, devices)
        receipt.update({"sdkVersion": sdk_version, "runtime": runtime, "runtimeVersion": runtime_version,
                        "deviceType": device_type, "hostArchitecture": platform.machine()})
        app = build_app(work, sdk, receipt)
        # Detect concurrent source edits instead of claiming a mixed build is exact.
        if source_receipt()["sourceDigest"] != receipt["sourceDigest"]:
            raise RuntimeError("Sources changed during compilation; rebuild from one stable worktree")
        device = run(["xcrun", "simctl", "create", "TIMInline-" + token[:8], device_type, runtime])
        receipt["deviceUDID"] = device
        run(["xcrun", "simctl", "boot", device], timeout=60)
        run(["xcrun", "simctl", "bootstatus", device, "-b"], timeout=300)
        run(["xcrun", "simctl", "install", device, app])
        data = Path(run(["xcrun", "simctl", "get_app_container", device, BUNDLE, "data"]))
        documents = data / "Documents"
        documents.mkdir(exist_ok=True)
        run(["xcrun", "simctl", "launch", "--terminate-running-process", device, BUNDLE], timeout=60)
        result = wait_for_result(device, documents, token, receipt)
        run_restart(device, documents, receipt)
        collect(device, data)
        validate_previews(REPORT)
        print(f"PASS: real UIKit scene app; {result['checks']} checks; runtime iOS {runtime_version}, target {DEPLOY}", flush=True)
        status = 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"FAIL: {error}", file=sys.stderr, flush=True)
        (REPORT / "driver-failure.txt").write_text(str(error))
        try:
            collect(device, data)
        except (OSError, RuntimeError, subprocess.SubprocessError) as diagnostic_error:
            print(f"Diagnostic collection failed: {diagnostic_error}", file=sys.stderr)
    finally:
        receipt["driverExitCode"] = status
        (REPORT / "build-receipt.json").write_text(json.dumps(receipt, indent=2, ensure_ascii=False))
        (REPORT / "commands.json").write_text(json.dumps(COMMANDS, indent=2))
        (REPORT / "build-and-run.log").write_text("\n".join(TRANSCRIPT))
        if device:
            for action in ("shutdown", "delete"):
                try:
                    run(["xcrun", "simctl", action, device], timeout=30, check=False)
                except (OSError, subprocess.SubprocessError):
                    pass
        shutil.rmtree(work, ignore_errors=True)
    return status


if __name__ == "__main__":
    sys.exit(main())
