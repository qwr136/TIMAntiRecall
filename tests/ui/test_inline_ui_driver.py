"""Portable tests of the simulator gate, never a substitute for the UIKit suite."""
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location("inline_ui_driver", Path(__file__).with_name("run_inline_ui_tests.py"))
DRIVER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DRIVER)


def valid_result():
    return {"runToken": "token", "sourceDigest": "source", "status": "PASS", "failures": [],
            "checks": 120, "mode": "real-uikit-scene", "sceneBackgroundObserved": True,
            "sceneResumeObserved": True, "previewWritten": True,
            "coverage": sorted(DRIVER.REQUIRED_COVERAGE)}


class ResultGateTests(unittest.TestCase):
    def test_accepts_complete_result(self):
        DRIVER.validate_result(valid_result(), "token", "source")

    def test_rejects_incomplete_and_stale_results(self):
        changes = [{"status": "FAIL"}, {"status": "COMPILED"}, {"failures": ["broken"]},
                   {"failures": None}, {"checks": 0}, {"checks": -1}, {"checks": True},
                   {"checks": "100"}, {"runToken": "old"}, {"sourceDigest": "wrong"},
                   {"mode": "compile-only"}, {"sceneBackgroundObserved": False},
                   {"sceneResumeObserved": False}, {"previewWritten": False}, {"coverage": []}]
        for change in changes:
            with self.subTest(change=change), self.assertRaises(RuntimeError):
                DRIVER.validate_result({**valid_result(), **change}, "token", "source")

    def test_non_macos_is_nonzero_skip(self):
        with mock.patch.object(DRIVER.sys, "platform", "linux"):
            self.assertEqual(DRIVER.main(), 77)

    def test_existing_pass_without_lifecycle_cannot_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "tim-inline-result.json").write_text(json.dumps(valid_result()))
            with mock.patch.object(DRIVER, "REPORT", root), self.assertRaisesRegex(RuntimeError, "before actual settings"):
                DRIVER.wait_for_result("device", root, "token", {"sourceDigest": "source"})

    def test_real_lifecycle_command_order_and_no_termination_on_resume(self):
        stages = iter(["settings-ready", "ready-for-background", "background-observed"])
        polls = 0
        def read(path):
            nonlocal polls
            if path.name == "tim-inline-result.json":
                polls += 1
                return valid_result() if polls >= 4 else None
            return {"runToken": "token", "stage": next(stages)}
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(DRIVER, "REPORT", Path(directory)), \
                mock.patch.object(DRIVER, "read_json", side_effect=read), \
                mock.patch.object(DRIVER, "run") as run, mock.patch.object(DRIVER.time, "sleep"):
            DRIVER.wait_for_result("device", Path(directory), "token", {"sourceDigest": "source"})
            commands = [call.args[0] for call in run.call_args_list]
            self.assertEqual(commands[0][:5], ["xcrun", "simctl", "io", "device", "screenshot"])
            self.assertTrue(str(commands[0][-1]).endswith('tim-inline-settings-simulator.png'))
            self.assertTrue(str(commands[1][-1]).endswith('tim-inline-simulator.png'))
            self.assertEqual(commands[2], ["xcrun", "simctl", "launch", "device", "com.apple.mobilesafari"])
            self.assertEqual(commands[3], ["xcrun", "simctl", "launch", "device", DRIVER.BUNDLE])
            self.assertEqual(json.loads((Path(directory)/'tim-inline-settings-captured.json').read_text())['runToken'],'token')
            self.assertTrue(all("--terminate-running-process" not in command for command in commands))

    def test_background_test_lease_is_released_only_after_receipts_on_foreground_transition(self):
        source=(Path(__file__).with_name("TIMAntiRecallInlineUIKitTests.m")).read_text()
        packet=(Path(__file__).with_name("TIMAntiRecallPacketSilentCases.h")).read_text()
        background=source.split('- (void)sceneDidEnterBackground:(UIScene *)scene',1)[1].split('\n}\n@end',1)[0]
        self.assertIn('timantirecall_stage(@"background-observed")',background)
        self.assertIn('timantirecall_backgroundReceiptsObserved',background)
        self.assertIn('endBackgroundTask:timantirecall_backgroundTask',background)
        self.assertLess(background.index('timantirecall_stage(@"background-observed")'),background.index('endBackgroundTask:timantirecall_backgroundTask'))
        self.assertIn('@"packet-background-before-resume"',packet)
        self.assertIn('timantirecall_backgroundReceiptsObserved=YES',packet)
        active=source.split('- (void)sceneDidBecomeActive:(UIScene *)scene',1)[1].split('- (void)sceneWillResignActive:',1)[0]
        self.assertIn('scene cannot resume before both background native receipts',active)
        self.assertIn('if(!timantirecall_backgroundReceiptsObserved){timantirecall_finish();return;}',active)
        self.assertIn('scene truly returned foreground active',source)

    def test_screenshot_retries_only_three_times(self):
        with mock.patch.object(DRIVER, "run", side_effect=[RuntimeError("busy"), RuntimeError("busy"), "captured"]) as run:
            DRIVER.run_screenshot("device", Path("screen.png"))
            self.assertEqual(run.call_count, 3)
        with mock.patch.object(DRIVER, "run", side_effect=RuntimeError("busy")) as run:
            with self.assertRaisesRegex(RuntimeError, "after 3 bounded attempts"):
                DRIVER.run_screenshot("device", Path("screen.png"))
            self.assertEqual(run.call_count, 3)

    def test_stalled_app_has_deadline(self):
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(DRIVER.time, "monotonic", side_effect=[0, 241]):
            with self.assertRaises(TimeoutError):
                DRIVER.wait_for_result("device", Path(directory), "token", {"sourceDigest": "source"})

    def test_corrupt_json_is_not_a_result(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "result.json"
            for content in ("{bad", "[]", "null"):
                path.write_text(content)
                self.assertIsNone(DRIVER.read_json(path))


class RestartGateTests(unittest.TestCase):
    def test_accepts_actual_different_process_result(self):
        result={'runToken':'token','sourceDigest':'source','status':'PASS','failures':[],
                'restoredBeforePush':True,'checks':8,'oldPID':123,'newPID':456}
        DRIVER.validate_restart_result(result,'token','source')
        for change in ({'newPID':123},{'newPID':0},{'oldPID':False},{'checks':0},
                       {'status':'FAIL'},{'restoredBeforePush':False},{'sourceDigest':'old'},
                       {'failures':['not restored']}):
            with self.subTest(change=change), self.assertRaises(RuntimeError):
                DRIVER.validate_restart_result({**result,**change},'token','source')

    def test_settings_screenshot_is_mandatory(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            for name in ('tim-inline-preview.png','tim-inline-simulator.png'):
                (root/name).write_bytes(b'\x89PNG\r\n\x1a\n'+b'0'*128)
            with self.assertRaisesRegex(RuntimeError,'settings'):
                DRIVER.validate_previews(root)
            (root/'tim-inline-settings-preview.png').write_bytes(b'\x89PNG\r\n\x1a\n'+b'0'*128)
            with self.assertRaisesRegex(RuntimeError,'settings-simulator'):
                DRIVER.validate_previews(root)
            (root/'tim-inline-settings-simulator.png').write_bytes(b'\x89PNG\r\n\x1a\n'+b'0'*128)
            DRIVER.validate_previews(root)


class RuntimeSelectionTests(unittest.TestCase):
    def setUp(self):
        self.runtimes = {"runtimes": []}
        self.devices = {"devices": {}}
        for item in ("16.4", "16.5", "18.5", "99.0"):
            identifier = "com.apple.CoreSimulator.SimRuntime.iOS-" + item.replace(".", "-")
            self.runtimes["runtimes"].append({"version": item, "identifier": identifier, "isAvailable": True})
            self.devices["devices"][identifier] = [{"name": "iPhone 16", "isAvailable": True, "deviceTypeIdentifier": "phone"}]

    def test_prefers_actual_target_runtime(self):
        self.assertEqual(DRIVER.choose_runtime("18.5", self.runtimes, self.devices)[2], "16.5")

    def test_fallback_is_available_compatible_runtime(self):
        data = copy.deepcopy(self.runtimes)
        data["runtimes"][1]["isAvailable"] = False
        self.assertEqual(DRIVER.choose_runtime("18.5", data, self.devices)[2], "18.5")

    def test_no_available_compatible_device_fails(self):
        with self.assertRaises(RuntimeError):
            DRIVER.choose_runtime("16.4", self.runtimes, self.devices)
        with self.assertRaises(RuntimeError):
            DRIVER.choose_runtime("18.5", self.runtimes, {"devices": {}})


if __name__ == "__main__":
    unittest.main()
