import unittest
from pathlib import Path
from source_checks import strip_comments

ROOT=Path(__file__).resolve().parents[1]

class MessageReplayContractTests(unittest.TestCase):
    def test_feature_uses_verified_native_double_tap_and_send_signatures(self):
        source=strip_comments((ROOT/'Sources/TIMAntiRecallReplay.m').read_text())
        self.assertIn('doubleTapGestureActionWithGesture:record:viewController:tappedCellView:',source)
        self.assertIn('const char *args[]={"@",":","@","@","@","@"}',source)
        self.assertIn('class_getClassMethod(service,selector)',source)
        self.assertIn('sendTextMsg:showText:',source)
        self.assertIn('Class controllerClass=objc_getClass("QQChatViewController")',source)
        self.assertIn('Method base=class_getInstanceMethod(sendClass,selector)',source)
        self.assertIn('method_getImplementation(method)==method_getImplementation(base)',source)
        self.assertIn('QQBaseChatViewController',source)
        self.assertIn('QQChatViewController',source)

    def test_only_bounded_pure_text_records_can_be_replayed(self):
        source=strip_comments((ROOT/'Sources/TIMAntiRecallReplay.m').read_text())
        for field in ('elements','textElement','content','atType','atUid','atTinyId',
                      'faceElement','replyElement','picElement','walletElement','prologueMsgElement'):
            self.assertIn(field,source)
        self.assertIn('[elements count]!=1',source)
        self.assertIn('content.length>4096',source)
        self.assertIn('stringByTrimmingCharactersInSet:',source)

    def test_replay_is_default_off_and_preserves_original_when_ineligible(self):
        settings=(ROOT/'Sources/TIMAntiRecallSettings.m').read_text()
        ui=(ROOT/'Sources/TIMAntiRecallPreferencesUI.m').read_text()
        hook=strip_comments((ROOT/'Sources/TIMAntiRecallReplay.m').read_text())
        self.assertIn('return [self.timantirecall_snapshot[@"messageReplay"] boolValue]',settings)
        self.assertIn('@"messageReplay"',settings)
        self.assertIn('@"消息双击复读"',ui)
        self.assertIn('timantirecall_replayTextForContext(record,viewController,tappedCellView,&text)',hook)
        self.assertIn('original)(receiver,selector,gesture,record,viewController,tappedCellView)',hook)
        self.assertIn('QQBaseChatViewController',hook)

    def test_ui_regression_and_native_state_coverage_are_required(self):
        driver=(ROOT/'tests/ui/run_inline_ui_tests.py').read_text()
        suite=(ROOT/'tests/ui/TIMAntiRecallInlineUIKitTests.m').read_text()
        cases=(ROOT/'tests/ui/TIMAntiRecallReplayCases.h').read_text()
        state=(ROOT/'tests/native/TIMAntiRecallStateTests.m').read_text()
        main=(ROOT/'Hooks/TIMAntiRecallMain.m').read_text()
        for token in ('Sources/TIMAntiRecallReplay.m','"message-replay"'):
            self.assertIn(token,driver)
        self.assertIn('timantirecall_testMessageReplay(root)',suite)
        for token in ('disabled replay preserves original TIM reader','pure text sends once','mention message never sends','mixed rich message never sends'):
            self.assertIn(token,cases)
        self.assertIn('timantirecall_messageReplay',state)
        self.assertIn('timantirecall_installMessageReplay()',main)

if __name__=='__main__':unittest.main()
