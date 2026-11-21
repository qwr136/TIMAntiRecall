"""工具链锁回归：调用临时生成工程副本中的生产脚本，只依赖标准库。

Git 用例使用本地仓库/子模块，不访问网络。macOS/Xcode 和 receipt 外部
命令使用 mock；mock 通过不代表实际工具链可编译、Actions 成功或真机可用。
"""
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock

PROJECT = Path(__file__).resolve().parent.parent


class ProjectFixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="toolchain-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / "project"
        shutil.copytree(PROJECT, self.project, ignore=shutil.ignore_patterns(
            ".git", ".theos", "packages", "reports", "tests", "__pycache__"))
        spec = importlib.util.spec_from_file_location(
            "toolchain_under_test", self.project / "scripts/toolchain.py")
        self.gate = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.gate)
        self.lock_path = self.project / "toolchain-lock.json"
        self.lock = json.loads(self.lock_path.read_text(encoding="utf-8"))
        self.meta = json.loads((self.project / "tweak.json").read_text(encoding="utf-8"))

    def write_json(self, path, value):
        path.write_text(json.dumps(value), encoding="utf-8")

    def static_ok(self):
        self.assertEqual(self.gate.static_errors(self.project), [])

    def static_bad(self, reason):
        errors = self.gate.static_errors(self.project)
        self.assertTrue(errors, "篡改后的工程必须被生产 static_errors 拒绝")
        self.assertRegex("\n".join(errors), reason)

    def replace(self, path, old, new):
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text, "夹具没有待变更的活动配置: " + old)
        path.write_text(text.replace(old, new), encoding="utf-8")


class LockTests(ProjectFixture):
    def test_generated_lock_loads_and_manifest_names_it(self):
        self.assertEqual(self.meta["toolchain_lock"], "toolchain-lock.json")
        self.assertEqual(self.gate.load_lock(self.project), self.lock)

    def test_missing_lock_is_rejected(self):
        self.lock_path.unlink()
        with self.assertRaises(FileNotFoundError):
            self.gate.load_lock(self.project)
        self.static_bad("toolchain-lock.json")

    def test_invalid_json_is_rejected(self):
        self.lock_path.write_text("{", encoding="utf-8")
        with self.assertRaises(json.JSONDecodeError):
            self.gate.load_lock(self.project)
        self.static_bad("Toolchain lock")

    def test_bad_schema_is_rejected(self):
        for schema in (0, 2, True, "1", None):
            with self.subTest(schema=schema):
                bad = copy.deepcopy(self.lock)
                bad["schema"] = schema
                self.write_json(self.lock_path, bad)
                with self.assertRaisesRegex(ValueError, "schema"):
                    self.gate.load_lock(self.project)
                self.static_bad("schema")

    def test_floating_source_hashes_are_rejected(self):
        for section, field in (("theos", "commit"), ("sdk", "commit"), ("sdk", "tree")):
            with self.subTest(section=section, field=field):
                bad = copy.deepcopy(self.lock)
                bad[section][field] = "main"
                self.write_json(self.lock_path, bad)
                with self.assertRaisesRegex(ValueError, "commit|tree"):
                    self.gate.load_lock(self.project)

    def test_action_tags_are_rejected_in_lock(self):
        bad = copy.deepcopy(self.lock)
        bad["actions"]["checkout"] = "actions/checkout@v5"
        self.write_json(self.lock_path, bad)
        with self.assertRaisesRegex(ValueError, "action"):
            self.gate.load_lock(self.project)


class StaticTests(ProjectFixture):
    def workflow(self):
        if not self.meta.get("github_actions"):
            self.skipTest("生成工程未启用 GitHub Actions")
        return self.project / ".github/workflows/build.yml"

    def test_generated_project_is_consistent(self):
        self.static_ok()

    def test_manifest_sdk_drift_is_rejected(self):
        self.static_ok()
        self.meta["sdk_version"] = "0.0"
        self.write_json(self.project / "tweak.json", self.meta)
        self.static_bad("SDK")

    def test_build_sdk_drift_is_rejected(self):
        self.static_ok()
        build = self.project / (self.meta["name"] + "Build.mk")
        self.replace(build, "iphone:clang:" + self.lock["sdk"]["target_version"] + ":",
                     "iphone:clang:0.0:")
        self.static_bad("SDK")

    def test_workflow_action_tag_is_rejected(self):
        workflow = self.workflow()
        self.static_ok()
        self.replace(workflow, self.lock["actions"]["checkout"], "actions/checkout@v5")
        self.static_bad("action")

    def test_feature_branch_builds_cancel_stale_runs_but_releases_are_protected(self):
        self.static_ok()
        workflow = self.workflow().read_text(encoding="utf-8")
        self.assertIn("cancel-in-progress: ${{ github.ref != 'refs/heads/main' && github.ref != 'refs/heads/master' }}", workflow)

    def test_workflow_developer_dir_drift_is_rejected(self):
        workflow = self.workflow()
        self.static_ok()
        self.replace(workflow, "DEVELOPER_DIR: " + self.lock["platform"]["developer_dir"],
                     "DEVELOPER_DIR: /Applications/Xcode_wrong.app/Contents/Developer")
        self.static_bad("DEVELOPER_DIR")

    def test_workflow_lock_cache_hash_is_required(self):
        workflow = self.workflow()
        self.static_ok()
        self.replace(workflow, "hashFiles('toolchain-lock.json')", "hashFiles('Makefile')")
        self.static_bad("hashFiles|cache")

    def test_commented_cache_hash_does_not_count(self):
        workflow = self.workflow()
        self.static_ok()
        needle = "hashFiles('toolchain-lock.json')"
        self.replace(workflow, needle, "hashFiles('Makefile')")
        with workflow.open("a", encoding="utf-8") as stream:
            stream.write("\n# " + needle + "\n")
        self.static_bad("hashFiles|cache")

    def verification_lines(self):
        path = self.project / "build.sh"
        lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
        indexes = [i for i, line in enumerate(lines)
                   if not line.lstrip().startswith("#") and "scripts/toolchain.py verify" in line]
        self.assertTrue(indexes, "本地 wrapper 必须有活动 verify 命令")
        return path, lines, indexes

    def test_local_wrapper_requires_verify(self):
        self.static_ok()
        path, lines, indexes = self.verification_lines()
        path.write_text("".join(line for i, line in enumerate(lines) if i not in indexes),
                        encoding="utf-8")
        self.static_bad("verif|lock")

    def test_commented_local_verify_does_not_count(self):
        self.static_ok()
        path, lines, indexes = self.verification_lines()
        path.write_text("".join("# " + line if i in indexes else line
                                for i, line in enumerate(lines)), encoding="utf-8")
        self.static_bad("verif|lock")

    def test_verify_after_make_is_rejected(self):
        self.static_ok()
        path, lines, indexes = self.verification_lines()
        verify = "".join(lines[i] for i in indexes)
        path.write_text("".join(line for i, line in enumerate(lines) if i not in indexes)
                        + "\n" + verify, encoding="utf-8")
        self.static_bad("late|before|order|make")

    def test_make_package_before_verify_is_rejected(self):
        self.static_ok()
        path, lines, indexes = self.verification_lines()
        lines.insert(indexes[0], "make package\n")
        path.write_text("".join(lines), encoding="utf-8")
        self.static_bad("late|before|order|make")

    def test_local_only_project_also_requires_verify(self):
        self.meta["github_actions"] = False
        self.write_json(self.project / "tweak.json", self.meta)
        self.static_ok()
        path, lines, indexes = self.verification_lines()
        path.write_text("".join(line for i, line in enumerate(lines) if i not in indexes),
                        encoding="utf-8")
        self.static_bad("verif|lock")


class FetchTests(ProjectFixture):
    def test_bad_cached_checksum_is_rejected_without_network(self):
        destination = self.root / "archive.tar.gz"
        destination.write_bytes(b"corrupt cache")
        expected = hashlib.sha256(b"locked download").hexdigest()
        with mock.patch.object(self.gate.urllib.request, "urlopen") as download:
            with self.assertRaisesRegex(ValueError, "cached.*checksum"):
                self.gate.fetch_verified("https://example.invalid/tool.tar.gz", expected, destination)
            download.assert_not_called()
        self.assertEqual(destination.read_bytes(), b"corrupt cache")

    def test_good_cached_checksum_is_accepted_without_network(self):
        destination = self.root / "archive.tar.gz"
        content = b"locked download"
        destination.write_bytes(content)
        with mock.patch.object(self.gate.urllib.request, "urlopen") as download:
            result = self.gate.fetch_verified("https://example.invalid/tool.tar.gz",
                                              hashlib.sha256(content).hexdigest(), destination)
            download.assert_not_called()
        self.assertEqual(result, destination)
        self.assertEqual(destination.read_bytes(), content)

    def test_bad_new_download_is_not_promoted_or_left_partial(self):
        destination = self.root / "downloads/archive.tar.gz"
        with mock.patch.object(self.gate.urllib.request, "urlopen",
                               return_value=io.BytesIO(b"corrupt response")) as download:
            with self.assertRaisesRegex(ValueError, "checksum"):
                self.gate.fetch_verified("https://example.invalid/tool.tar.gz",
                                        hashlib.sha256(b"locked download").hexdigest(), destination)
            download.assert_called_once()
        self.assertFalse(destination.exists())
        self.assertFalse(destination.with_suffix(destination.suffix + ".partial").exists())

    def test_good_new_download_is_verified_and_promoted(self):
        destination = self.root / "downloads/archive.tar.gz"
        content = b"locked download"
        with mock.patch.object(self.gate.urllib.request, "urlopen",
                               return_value=io.BytesIO(content)) as download:
            result = self.gate.fetch_verified("https://example.invalid/tool.tar.gz",
                                              hashlib.sha256(content).hexdigest(), destination)
            download.assert_called_once()
        self.assertEqual(result, destination)
        self.assertEqual(destination.read_bytes(), content)
        self.assertFalse(destination.with_suffix(destination.suffix + ".partial").exists())

    def test_plain_http_is_rejected_before_download(self):
        destination = self.root / "archive.tar.gz"
        with mock.patch.object(self.gate.urllib.request, "urlopen") as download:
            with self.assertRaisesRegex(ValueError, "HTTPS"):
                self.gate.fetch_verified("http://example.invalid/tool.tar.gz", "0" * 64, destination)
            download.assert_not_called()
        self.assertFalse(destination.exists())


@contextlib.contextmanager
def locked_host(gate, lock, system=None, machine=None, python=None, commands=None, environment=None):
    """只模拟系统查询，不模拟 verify_platform；不证明真实 macOS/Xcode 可用。"""
    p = lock["platform"]
    responses = {
        ("sw_vers", "-productVersion"): p["macos_major"] + ".9.1",
        ("sw_vers", "-buildVersion"): "mock-os-build",
        ("xcodebuild", "-version"): "Xcode " + p["xcode_version"] + "\nBuild version " + p["xcode_build"],
        ("xcrun", "--sdk", "iphoneos", "clang", "--version"):
            "Apple clang version 17.0.0 (clang-" + p["clang_build"] + ")",
    }
    responses.update(commands or {})
    env = {"DEVELOPER_DIR": p["developer_dir"], "ImageVersion": "mock-image",
           "RUNNER_OS": "macOS", "RUNNER_ARCH": p["architecture"]}
    env.update(environment or {})

    def command(argv, cwd=None):
        key = tuple(str(value) for value in argv)
        if key not in responses:
            raise AssertionError("未模拟的系统查询: " + repr(key))
        return responses[key]

    with contextlib.ExitStack() as stack:
        stack.enter_context(mock.patch.dict(gate.os.environ, env, clear=True))
        stack.enter_context(mock.patch.object(gate.platform, "system", return_value=system or p["os"]))
        stack.enter_context(mock.patch.object(gate.platform, "machine", return_value=machine or p["architecture"]))
        stack.enter_context(mock.patch.object(gate.platform, "python_version", return_value=python or lock["python_version"]))
        query = stack.enter_context(mock.patch.object(gate, "run", side_effect=command))
        yield query


class PlatformTests(ProjectFixture):
    def test_matching_platform_returns_observed_evidence(self):
        with locked_host(self.gate, self.lock):
            result = self.gate.verify_platform(self.lock)
        self.assertEqual(result["architecture"], self.lock["platform"]["architecture"])
        self.assertEqual(result["python"], self.lock["python_version"])
        self.assertEqual(result["developer_dir"], self.lock["platform"]["developer_dir"])
        self.assertEqual(result["os_build"], "mock-os-build")

    def test_non_darwin_is_rejected_before_system_queries(self):
        with locked_host(self.gate, self.lock, system="Linux") as query:
            with self.assertRaisesRegex(ValueError, "require|Darwin"):
                self.gate.verify_platform(self.lock)
            query.assert_not_called()

    def test_actual_platform_version_drift_is_rejected(self):
        p = self.lock["platform"]
        cases = (
            ({"machine": "x86_64"}, "architecture"),
            ({"commands": {("sw_vers", "-productVersion"): "0.0.0"}}, "macOS"),
            ({"environment": {"DEVELOPER_DIR": "/wrong/Xcode.app"}}, "DEVELOPER_DIR"),
            ({"commands": {("xcodebuild", "-version"): "Xcode 0.0\nBuild version " + p["xcode_build"]}}, "Xcode"),
            ({"commands": {("xcodebuild", "-version"): "Xcode " + p["xcode_version"] + "\nBuild version wrong"}}, "Xcode"),
            ({"commands": {("xcrun", "--sdk", "iphoneos", "clang", "--version"): "Apple clang (clang-0.0)"}}, "clang"),
            ({"python": "0.0.0"}, "Python"),
        )
        for overrides, reason in cases:
            with self.subTest(reason=reason, overrides=overrides):
                with locked_host(self.gate, self.lock, **overrides):
                    with self.assertRaisesRegex(ValueError, reason):
                        self.gate.verify_platform(self.lock)


def local_git(repo, *arguments):
    """测试仓库只允许本地 file 协议，不读取用户 Git 配置或访问远端。"""
    env = os.environ.copy()
    env.update(GIT_CONFIG_NOSYSTEM="1",
               GIT_CONFIG_GLOBAL=str(Path(repo).parent / "toolchain-test-absent-gitconfig"),
               GIT_TERMINAL_PROMPT="0", GIT_ALLOW_PROTOCOL="file")
    result = subprocess.run(
        ["git", "-C", str(repo), "-c", "user.name=Toolchain Test",
         "-c", "user.email=toolchain-test@example.invalid", "-c", "commit.gpgsign=false",
         "-c", "core.autocrlf=false", "-c", "protocol.file.allow=always", *arguments],
        env=env, capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise AssertionError("本地 Git 夹具失败: " + result.stderr)
    return result.stdout.strip()


@unittest.skipUnless(shutil.which("git"), "源码完整性回归需要本地 git；未执行不计为通过")
class SourceTests(ProjectFixture):
    @classmethod
    def setUpClass(cls):
        cls.source_temp = tempfile.TemporaryDirectory(prefix="toolchain-git-")
        cls.addClassCleanup(cls.source_temp.cleanup)
        cls.fixture_root = Path(cls.source_temp.name)
        cls.source_lock = json.loads((PROJECT / "toolchain-lock.json").read_text(encoding="utf-8"))
        theos = cls.fixture_root / "theos"
        sdk = cls.fixture_root / "sdk"
        headers = cls.fixture_root / "headers"
        for repo in (headers, theos, sdk):
            repo.mkdir()
            local_git(repo, "init", "-q")
        (headers / "Preferences").mkdir()
        (headers / "roothide.h").write_text("/* fixture, not a real toolchain */\n", encoding="utf-8")
        (headers / "Preferences/PSListController.h").write_text("/* fixture */\n", encoding="utf-8")
        local_git(headers, "add", ".")
        local_git(headers, "commit", "-qm", "headers fixture")
        local_git(theos, "submodule", "add", "-q", str(headers), "vendor/include")
        local_git(theos, "commit", "-qm", "Theos fixture with local submodule")
        directory = cls.source_lock["sdk"]["directory"]
        source = sdk / directory
        source.mkdir()
        value = {"Version": cls.source_lock["sdk"]["internal_version"]}
        (source / "SDKSettings.plist").write_bytes(plistlib.dumps(value))
        (source / "SDKSettings.json").write_text(json.dumps(value), encoding="utf-8")
        local_git(sdk, "add", ".")
        local_git(sdk, "commit", "-qm", "SDK fixture")
        cls.source_lock["theos"]["commit"] = local_git(theos, "rev-parse", "HEAD")
        cls.source_lock["theos"]["submodules"] = {
            "vendor/include": local_git(headers, "rev-parse", "HEAD")}
        cls.source_lock["sdk"]["commit"] = local_git(sdk, "rev-parse", "HEAD")
        cls.source_lock["sdk"]["tree"] = local_git(sdk, "rev-parse", "HEAD:" + directory)
        cls.source_lock["sdk"]["metadata_blobs"] = {
            name: local_git(sdk, "rev-parse", "HEAD:" + directory + "/" + name)
            for name in ("SDKSettings.plist", "SDKSettings.json")}

    def setUp(self):
        super().setUp()
        self.source_lock = copy.deepcopy(type(self).source_lock)
        self.theos = self.root / "theos"
        self.sdk = self.root / "sdk"
        shutil.copytree(self.fixture_root / "theos", self.theos)
        shutil.copytree(self.fixture_root / "sdk", self.sdk)
        self.source = self.sdk / self.source_lock["sdk"]["directory"]
        self.installed = self.theos / "sdks" / self.source.name
        self.installed.parent.mkdir()
        self.installed.symlink_to(self.source, target_is_directory=True)
        # 这里不 mock run/clean_repo/hash：所有 Git 状态与文件 hash 都由生产代码实查。
        self.gate.verify_sources(self.source_lock, self.theos, self.sdk)

    def verify(self):
        return self.gate.verify_sources(self.source_lock, self.theos, self.sdk)

    def test_matching_local_sources_return_git_evidence(self):
        evidence = self.verify()
        self.assertEqual(evidence["theos_commit"], local_git(self.theos, "rev-parse", "HEAD"))
        self.assertEqual(evidence["submodules"], self.source_lock["theos"]["submodules"])
        self.assertEqual(evidence["sdk_tree"], local_git(self.sdk, "rev-parse", "HEAD:" + self.source.name))
        for name, blob in self.source_lock["sdk"]["metadata_blobs"].items():
            self.assertEqual(evidence["sdk_metadata"][name],
                             {"blob": blob, "version": self.source_lock["sdk"]["internal_version"]})

    def test_theos_commit_drift_is_rejected(self):
        self.source_lock["theos"]["commit"] = "0" * 40
        with self.assertRaisesRegex(ValueError, "commit mismatch"):
            self.verify()

    def test_tracked_source_modification_is_rejected(self):
        with (self.theos / ".gitmodules").open("a", encoding="utf-8") as stream:
            stream.write("\n# tracked modification\n")
        with self.assertRaisesRegex(ValueError, "tracked modifications"):
            self.verify()

    def test_locked_submodule_hash_drift_is_rejected(self):
        self.source_lock["theos"]["submodules"]["vendor/include"] = "0" * 40
        with self.assertRaisesRegex(ValueError, "submodule mismatch"):
            self.verify()

    def test_actual_submodule_checkout_drift_is_rejected(self):
        headers = self.theos / "vendor/include"
        (headers / "extra.h").write_text("/* changed checkout */\n", encoding="utf-8")
        local_git(headers, "add", ".")
        local_git(headers, "commit", "-qm", "unexpected submodule revision")
        with self.assertRaisesRegex(ValueError, "tracked modifications|submodules"):
            self.verify()

    def test_sdk_commit_drift_is_rejected(self):
        self.source_lock["sdk"]["commit"] = "0" * 40
        with self.assertRaisesRegex(ValueError, "commit mismatch"):
            self.verify()

    def test_sdk_tree_drift_is_rejected(self):
        self.source_lock["sdk"]["tree"] = "0" * 40
        with self.assertRaisesRegex(ValueError, "SDK tree mismatch"):
            self.verify()

    def test_extra_sdk_file_is_rejected(self):
        (self.source / "unexpected.h").write_text("/* injected file */\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "modified or extra files"):
            self.verify()

    def test_sdk_metadata_blob_drift_is_rejected(self):
        for name in self.source_lock["sdk"]["metadata_blobs"]:
            with self.subTest(metadata=name):
                bad = copy.deepcopy(self.source_lock)
                bad["sdk"]["metadata_blobs"][name] = "0" * 40
                with self.assertRaisesRegex(ValueError, "metadata hash mismatch"):
                    self.gate.verify_sources(bad, self.theos, self.sdk)

    def test_sdk_internal_version_drift_is_rejected(self):
        self.source_lock["sdk"]["internal_version"] = "0.0"
        with self.assertRaisesRegex(ValueError, "internal version mismatch"):
            self.verify()

    def test_copied_sdk_without_verified_link_is_rejected(self):
        self.installed.unlink()
        shutil.copytree(self.source, self.installed)
        with self.assertRaisesRegex(ValueError, "verified checkout"):
            self.verify()


class ReceiptTests(ProjectFixture):
    def test_source_evidence_only_serializes_allowlisted_environment(self):
        import build_evidence
        for command in (['git','init','-b','main'], ['git','config','user.name','Fixture'],
                        ['git','config','user.email','fixture@example.invalid'], ['git','add','.'],
                        ['git','commit','-m','Fixture source']):
            subprocess.run(command,cwd=self.project,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=self.project,text=True).strip()
        observed={'GITHUB_ACTIONS':'true','GITHUB_SHA':commit,'GITHUB_RUN_NUMBER':'1',
            'GITHUB_REF':'refs/heads/main','GITHUB_REPOSITORY':'fixture/locked',
            'GITHUB_RUN_ID':'42','GITHUB_RUN_ATTEMPT':'2'}
        secrets={'UNRELATED_ENV_SENTINEL':'secret-probe-arbitrary-value',
            'GITHUB_TOKEN':'secret-probe-github-token','AWS_SECRET_ACCESS_KEY':'secret-probe-aws-key'}
        with mock.patch.dict(os.environ,dict(observed,**secrets),clear=True):
            result=build_evidence.source_snapshot(self.project,'0.10')
        raw=json.dumps(result)
        for key,value in secrets.items():
            self.assertNotIn(key,raw); self.assertNotIn(value,raw)
        self.assertEqual(result['source_sha'],commit)
        self.assertEqual(result['run_id'],'42')
        self.assertEqual(result['repository'],'fixture/locked')
        self.assertTrue(result['tracked_blobs'])

    def legacy_deb_receipt_fixture(self):
        # receipt 本身与 verify_platform 的字段选择都运行真实实现。
        # 只隔离尚未可在 Alpine 执行的整体 verify、git/dpkg 命令与真实 deb。
        packages = self.project / "packages"
        packages.mkdir()
        deb = packages / "fixture.deb"
        deb.write_bytes(b"receipt fixture; not an installable deb")
        fields = {}
        for line in (self.project / "control").read_text(encoding="utf-8").splitlines():
            if line and not line[0].isspace() and ":" in line:
                key, value = line.split(":", 1)
                fields[key] = value.strip()
        observed = {
            "GITHUB_REF": "refs/heads/main", "GITHUB_REPOSITORY": "fixture/locked",
            "GITHUB_RUN_ID": "42", "GITHUB_RUN_ATTEMPT": "2",
            "GITHUB_WORKFLOW_REF": "fixture/locked/.github/workflows/build.yml@refs/heads/main",
        }
        secrets = {
            "UNRELATED_ENV_SENTINEL": "secret-probe-arbitrary-value",
            "GITHUB_TOKEN": "secret-probe-github-token",
            "AWS_SECRET_ACCESS_KEY": "secret-probe-aws-key",
        }
        output = self.root / "reports/receipt.json"
        source_sha = "1" * 40

        def command(argv, cwd=None):
            if list(argv) == ["git", "rev-parse", "HEAD"] and Path(cwd) == self.project:
                return source_sha
            if list(argv[:3]) == ["dpkg-deb", "-f", str(deb)] and len(argv) == 4:
                return fields[argv[3]]
            raise AssertionError("未模拟的 receipt 命令: " + repr(argv))

        with locked_host(self.gate, self.lock, environment=dict(observed, **secrets)):
            host = self.gate.verify_platform(self.lock)
            evidence = {"status": "verified", "host": host,
                        "lock_sha256": hashlib.sha256(self.lock_path.read_bytes()).hexdigest()}
            with mock.patch.object(self.gate, "verify", return_value=evidence) as verify:
                with mock.patch.object(self.gate, "run", side_effect=command):
                    with contextlib.redirect_stdout(io.StringIO()):
                        self.gate.receipt(self.project, self.lock, output)
                verify.assert_called_once_with(self.project, self.lock)
        raw = output.read_text(encoding="utf-8")
        result = json.loads(raw)
        for key, value in secrets.items():
            self.assertNotIn(key, raw)
            self.assertNotIn(value, raw)
        self.assertEqual(result["repository"], observed["GITHUB_REPOSITORY"])
        self.assertEqual(result["source_ref"], observed["GITHUB_REF"])
        self.assertEqual(result["run_id"], "42")
        self.assertEqual(result["source_sha"], source_sha)
        self.assertEqual(result["packages"][0]["sha256"], hashlib.sha256(deb.read_bytes()).hexdigest())
        self.assertEqual(result["packages"][0]["control"]["Package"], self.meta["package"])


if __name__ == "__main__":
    unittest.main()
