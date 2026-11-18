"""Static contract for the user-visible toast; runtime UI is covered on macOS/iOS build separately."""
import re
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class ToastTests(unittest.TestCase):
    def setUp(self): self.source=(ROOT/'Sources/TIMAntiRecallToast.m').read_text()
    def test_fixed_text_and_main_queue(self):
        self.assertIn('已拦截撤回',self.source)
        self.assertIn('dispatch_get_main_queue()',self.source)
        self.assertIn('dispatch_async(dispatch_get_main_queue()',self.source)
    def test_noninteractive_foreground_window(self):
        self.assertIn('connectedScenes',self.source)
        self.assertRegex(self.source,r'scene\.activationState\s*!=\s*UISceneActivationStateForegroundActive')
        self.assertIn('sceneScore = 2',self.source)
        self.assertIn('window.isKeyWindow',self.source)
        self.assertIn('userInteractionEnabled = NO',self.source)
    def test_deduplicated_lifetime_and_limit(self):
        self.assertIn('timantirecall_toastGeneration',self.source)
        self.assertIn('timantirecall_toastVisible',self.source)
        self.assertIn('atomic_flag_test_and_set_explicit',self.source)
        self.assertIn('dispatch_after',self.source)
        self.assertIn('request >= 64',self.source)
        self.assertIn('removeFromSuperview',self.source)
        self.assertIn('UISceneWillDeactivateNotification',self.source)
        self.assertIn('UIApplicationDidEnterBackgroundNotification',self.source)

    def test_macos_native_runner_excludes_real_uikit(self):
        runner=(ROOT/'scripts/run_native_tests.py').read_text()
        self.assertIn("p != 'Sources/TIMAntiRecallToast.m'",runner)
        self.assertIn('TIMAntiRecallToastNativeStub.m',runner)
        self.assertTrue((ROOT/'tests/native/TIMAntiRecallToastNativeStub.m').is_file())
    def test_no_message_or_account_data(self):
        for banned in ('msgBuffer','NSData','UID','peerUid','senderUid','command'):
            self.assertNotIn(banned,self.source)
    def test_runtime_only_calls_toast_on_block(self):
        runtime=(ROOT/'Sources/TIMAntiRecallRuntime.m').read_text()
        start=runtime.index('if (decision != TIMAntiRecallPass)')
        end=runtime.index('TIMAntiRecallPushIMP original',start)
        self.assertIn('timantirecall_showToast()',runtime[start:end])
        self.assertEqual(runtime.count('timantirecall_showToast()'),1)
        block=runtime[start:end]
        toast=block.index('timantirecall_showToast()')
        self.assertLess(block.index('if (count < 32)'),toast)
        self.assertEqual(block.count('if (count < 32)'),1)
        self.assertIn('decision != TIMAntiRecallPass',block)
if __name__=='__main__':unittest.main()
