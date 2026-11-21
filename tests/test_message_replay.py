import unittest
from pathlib import Path
from source_checks import strip_comments
ROOT=Path(__file__).resolve().parents[1]
class MessageReplayContractTests(unittest.TestCase):
    def test_native_text_double_tap_is_not_interposed(self):
        s=strip_comments((ROOT/'Sources/TIMAntiRecallReplay.m').read_text())
        self.assertNotIn('method_setImplementation',s)
        self.assertNotIn('NTAIOContentDoubleTapService',s)
        self.assertNotIn('sendInputText:',s)
        for token in ('sendTextMsgByOCContact:richText:callBack:', 'const char *args[]={"@",":","@","@","@?"}', 'getInstance','replayContact(record,controller)'):
            self.assertIn(token,s)
    def test_pure_text_and_live_session_are_required(self):
        s=strip_comments((ROOT/'Sources/TIMAntiRecallReplay.m').read_text())
        for token in ('[elements count]!=1','content.length>4096','atType','atUid','atTinyId','faceElement','replyElement','picElement','walletElement','prologueMsgElement','replayChatContextForController','recordType!=currentType','[recordPeer isEqual:currentPeer]'):
            self.assertIn(token,s)
    def test_native_recognizer_and_bounded_outside_geometry(self):
        s=strip_comments((ROOT/'Sources/TIMAntiRecallReplay.m').read_text())
        for token in ('numberOfTapsRequired=2','numberOfTouchesRequired=1','cancelsTouchesInView=NO','delaysTouchesBegan=NO','delaysTouchesEnded=NO','requireGestureRecognizerToFail:scroll.panGestureRecognizer','CGRectContainsPoint(band,point)','CGRectContainsRect(host.bounds,bubble)','isKindOfClass:UIControl.class'):
            self.assertIn(token,s)
    def test_current_binding_and_transition_guards(self):
        s=strip_comments((ROOT/'Sources/TIMAntiRecallReplay.m').read_text())
        for token in ('timantirecall_firstModel','timantirecall_boundModel','timantirecall_firstIdentity','timantirecall_firstController','timantirecall_firstScroll','timantirecall_firstOffset','timantirecall_replayEpoch','timantirecall_replayHostUnique','timantirecall_samples=2','removeGestureRecognizer:'):
            self.assertIn(token,s)
        inline=(ROOT/'Sources/TIMAntiRecallInline.m').read_text()
        self.assertIn('timantirecall_updateReplayRow(view,context.timantirecall_owner)',inline)
        self.assertIn('timantirecall_updateReplayRow(receiver,context.timantirecall_owner)',inline)
        self.assertIn('timantirecall_clearReplayRow(view)',inline)
    def test_swift_bridge_reads_actual_stored_fields_not_offsets(self):
        s=(ROOT/'Sources/TIMAntiRecallRecordBridge.swift').read_text()
        for token in ('NTAIOCellView','"content", "avatar", "title", "status", "checkView", "tailContainerView"','NTAIOChatBaseViewController','NTAIOChatViewController','AIOChatContext','"chatContext"','Mirror(reflecting:'):
            self.assertIn(token,s)
        self.assertNotIn('UnsafePointer',s)
    def test_native_boxed_zero_metadata_is_narrowly_allowed(self):
        s=strip_comments((ROOT/'Sources/TIMAntiRecallReplay.m').read_text())
        self.assertIn('strcmp(metadata[i],"subElementType")==0||strcmp(metadata[i],"atChannelId")==0',s)
        self.assertIn('CFGetTypeID((__bridge CFTypeRef)value)!=CFBooleanGetTypeID()',s)
        self.assertIn('[value isEqualToNumber:@0]',s)
        self.assertIn('text.subElementType=@0;text.atChannelId=@0',
                      (ROOT/'tests/ui/TIMAntiRecallReplayCases.h').read_text())
    def test_replay_diagnostics_are_opt_in_and_redacted(self):
        settings=(ROOT/'Sources/TIMAntiRecallSettings.m').read_text()
        trace=(ROOT/'Sources/TIMAntiRecallReplayTrace.m').read_text()
        ui=(ROOT/'Sources/TIMAntiRecallPreferencesUI.m').read_text()
        self.assertIn('timantirecall_replayDiagnostics',settings)
        self.assertIn('if(![timantirecall_settings() timantirecall_replayDiagnostics])return',trace)
        self.assertIn('replayDiagnostics',ui)
        self.assertNotIn('record[',trace)
        self.assertNotIn('@"content"',trace)
        replay=(ROOT/'Sources/TIMAntiRecallReplay.m').read_text()
        self.assertIn('@"valueClass":valueClass',replay)
        self.assertIn('@"valueKind":valueKind',replay)
        self.assertIn('NSStringFromClass([value class])',replay)
        self.assertIn('@"number-zero"',replay)
        self.assertIn('@"number-nonzero"',replay)
        self.assertIn('@"number-boolean"',replay)
        self.assertIn('metadata[i]',replay)
    def test_default_off_and_ui_regressions_remain_mandatory(self):
        settings=(ROOT/'Sources/TIMAntiRecallSettings.m').read_text()
        self.assertIn('return [self.timantirecall_snapshot[@"messageReplay"] boolValue]',settings)
        driver=(ROOT/'tests/ui/run_inline_ui_tests.py').read_text()
        cases=(ROOT/'tests/ui/TIMAntiRecallReplayCases.h').read_text()
        for token in ('message-replay','message-replay-outside','message-replay-native-contact','message-replay-reuse-scroll'):
            self.assertIn('"'+token+'"',driver)
        for token in ('single outside tap never sends','pure text sends once','original TIM text double tap untouched','live chat must match record contact','Swift direct rebinding','group chat submits','row reuse removes gesture','scroll offset change','mention message never sends','mixed rich message never sends'):
            self.assertIn(token,cases)
    def test_native_boxed_zero_defaults_and_redacted_diagnostics(self):
        replay=(ROOT/'Sources/TIMAntiRecallReplay.m').read_text()
        trace=(ROOT/'Sources/TIMAntiRecallReplayTrace.m').read_text()
        settings=(ROOT/'Sources/TIMAntiRecallSettings.m').read_text()
        self.assertIn('strcmp(metadata[i],"subElementType")==0||strcmp(metadata[i],"atChannelId")==0',replay)
        self.assertIn('CFBooleanGetTypeID()',replay)
        self.assertIn('[value isEqualToNumber:@0]',replay)
        self.assertIn('replayDiagnostics',settings)
        self.assertIn('if(![timantirecall_settings() timantirecall_replayDiagnostics])return',trace)
        self.assertNotIn('messageText',trace)
        self.assertNotIn('peerUid',trace)
        self.assertIn('96*1024',trace)
