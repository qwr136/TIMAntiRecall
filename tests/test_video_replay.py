import unittest
from pathlib import Path
from source_checks import strip_comments,function_body,mask_literals
ROOT=Path(__file__).resolve().parents[1]

class VideoReplayTests(unittest.TestCase):
    def test_only_single_type_five_gets_native_reference_plan(self):
        source=strip_comments((ROOT/'Sources/TIMAntiRecallReplayPayload.m').read_text())
        body=function_body(source,'timantirecall_richReplaySnapshot')
        self.assertIn('if(payload||(i>=5&&i!=6))',body)
        self.assertIn('[elements count]!=1||[type intValue]!=5',body)
        self.assertIn('return timantirecall_videoSnapshot(record,payload)',body)
        self.assertLess(body.index('if(slot==6)'),body.index('classes[(NSUInteger)slot]'))
        helper=strip_comments((ROOT/'Sources/TIMAntiRecallReplayVideo.inc').read_text())
        for token in ('"OCVideoElement"','"fileSize","Q"','"fileTime","i"','"invalidState","@"','"msgId","msgSeq"','values.copy'):
            self.assertIn(token,helper)
        for forbidden in ('writeToFile:','removeItem','AVAsset','NSURLSession','fetchFilePath','sendShortVideoMsg:'):
            self.assertNotIn(forbidden,helper)
    def test_forward_abi_and_nonnull_three_argument_callback(self):
        source=strip_comments((ROOT/'Sources/TIMAntiRecallReplayVideo.inc').read_text())
        send=function_body(source,'timantirecall_videoSend')
        for token in ('getMsgSenderHandlerWithcontact:','_TtC10MsgManager16MsgSenderHandler','forwardMsgWithMsgIds:srcContact:dstContacts:msgAttributeInfos:cb:','"@",":","@","@","@","@","@?"','methodTypes(method,"v",7,args)','void(^completion)(int32_t,NSString *,NSDictionary *)','@[video[@"msgId"]],contact,@[contact],nil,completion'):
            self.assertIn(token,send)
        self.assertNotIn('dispatch_after',send)
        self.assertNotIn('retry',send)
        self.assertIn('if([snapshot[@"mode"] isEqual:@"video"])return timantirecall_videoSend', (ROOT/'Sources/TIMAntiRecallReplayPayload.m').read_text())
    def test_video_tests_are_compiled_run_and_required(self):
        driver=(ROOT/'tests/ui/run_inline_ui_tests.py').read_text()
        self.assertIn('"TIMAntiRecallReplayVideoFixture.m"',driver)
        for name in ('video-native-forward-replay','video-native-forward-guards'):
            self.assertIn('"'+name+'"',driver)
        main=(ROOT/'tests/ui/TIMAntiRecallInlineUIKitTests.m').read_text()
        self.assertIn('timantirecall_testVideoReplay(root);',main)
        cases=(ROOT/'tests/ui/TIMAntiRecallReplayVideoCases.h').read_text()
        for token in ('4294967851','same sole current conversation','nonnil three-argument','never retries','switch OFF','wrong-signature','mixed video','native resource changing','TIMANTIRECALL_SECRET_NATIVE_MESSAGE'):
            self.assertIn(token,cases)
    def test_video_helper_structure_and_opt_in_fixed_logs(self):
        source=strip_comments((ROOT/'Sources/TIMAntiRecallReplayVideo.inc').read_text())
        depth=0
        for char in mask_literals(source):
            if char=='{':depth+=1
            elif char=='}':depth-=1
            self.assertGreaterEqual(depth,0)
        self.assertEqual(depth,0)
        helper=function_body(source,'timantirecall_videoReject')
        self.assertIn('timantirecall_replayDiagnostics',helper)
        self.assertIn('@"shape":@"video"',helper)
        self.assertNotIn('description',helper)

if __name__=='__main__':unittest.main()
