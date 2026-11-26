import unittest
from pathlib import Path
from source_checks import strip_comments, function_body
ROOT=Path(__file__).resolve().parents[1]

class ReceivedReplayTests(unittest.TestCase):
    def test_text_only_fallback_retains_native_elements_and_guards(self):
        source=strip_comments((ROOT/'Sources/TIMAntiRecallReplayPayload.m').read_text())
        body=function_body(source,'timantirecall_richReplaySnapshot')
        self.assertIn('if(!rich)',body)
        self.assertIn('timantirecall_receivedTextBody(entry[@"payload"][@"values"])',body)
        self.assertIn('!visibleTextBody',body)
        self.assertIn('[elements count]==1&&textSize>4096',body)
        self.assertIn('textSize==0',body)
        self.assertIn('replies&&[elements count]==1',body)
        helper=strip_comments((ROOT/'Sources/TIMAntiRecallReplayReceived.inc').read_text())
        for token in ('CFBooleanGetTypeID','isEqualToNumber:@0','kind!=0&&kind!=2','atNtUid','atTinyId','link-or-role','text-mention-identity-rejected','up-to-4096'):
            self.assertIn(token,helper)
        for token in ('setAtUid','setAtNtUid','sendTextMsg','NSURLSession','object_setIvar'):
            self.assertNotIn(token,helper)
    def test_received_photo_uses_native_message_reference_without_download(self):
        payload=strip_comments((ROOT/'Sources/TIMAntiRecallReplayPayload.m').read_text())
        body=function_body(payload,'timantirecall_richReplaySnapshot')
        photo=body.split('if(slot==4)',1)[1].split('BOOL faceType',1)[0]
        self.assertIn('timantirecall_photoForwardSnapshot(record,payload,subtype)',photo)
        for token in ('sourcePath','timantirecall_receivedPhotoFile','photo-download','fetchOriginalImgPathWithCreateFolder'):
            self.assertNotIn(token,photo)
        forward=strip_comments((ROOT/'Sources/TIMAntiRecallReplayForward.inc').read_text())
        photo_plan=function_body(forward,'timantirecall_photoForwardSnapshot')
        for token in ('"msgId"','"msgSeq"','"fileUuid"','"md5HexStr"','"originImageMd5"','positive-int64'):
            self.assertIn(token,photo_plan)
        sender=function_body(forward,'timantirecall_nativeReferenceForward')
        for token in ('getMsgSenderHandlerWithcontact:','_TtC10MsgManager16MsgSenderHandler','forwardMsgWithMsgIds:srcContact:dstContacts:msgAttributeInfos:cb:','methodTypes(method,"v",7,args)','@[messageID],contact,@[contact],nil,completion'):
            self.assertIn(token,sender)
        replay=strip_comments((ROOT/'Sources/TIMAntiRecallReplay.m').read_text())
        self.assertNotIn('timantirecall_replayStartPhotoDownload',replay)
        self.assertNotIn('photo-download',replay)
        fixture=(ROOT/'tests/ui/TIMAntiRecallReplayPhotoCases.h').read_text()
        for token in ('photo-forward','photo-native-reference-no-download','timantirecall_downloadCalls]==0','timantirecall_cacheCalls==0','changed photo resource','native photo-forward error callback never downloads'):
            self.assertIn(token,fixture)
        self.assertIn('photo double tap submits one same-chat native forward',fixture)

    def test_video_type_is_not_an_alternate_face(self):
        source=strip_comments((ROOT/'Sources/TIMAntiRecallReplayPayload.m').read_text())
        self.assertIn('case 5:return @"video"',function_body(source,'timantirecall_richElementKind'))
        self.assertNotIn('face-alt',source)
        self.assertIn('([type intValue]==6&&[payload isKindOfClass:objc_getClass(\"OCFaceElement\")]',source)
        self.assertIn('object_getClass(payload)==objc_getClass(\"OCFaceElement\")',source)
        cases=(ROOT/'tests/ui/TIMAntiRecallReplayRichCases.h').read_text()
        self.assertIn('wrongType,wrongClass,videoTypeFace',cases)
    def test_received_message_uikit_cases_are_required(self):
        driver=(ROOT/'tests/ui/run_inline_ui_tests.py').read_text()
        inline=(ROOT/'tests/ui/TIMAntiRecallInlineUIKitTests.m').read_text()
        self.assertIn('"received-text-mention-replay"',driver)
        self.assertIn('#import "TIMAntiRecallReplayReceivedCases.h"',inline)
        self.assertIn('timantirecall_testReceivedTextReplay(root)',inline)
        cases=(ROOT/'tests/ui/TIMAntiRecallReplayReceivedCases.h').read_text()
        for text in ('three-text-element','original_mention_target','without original recipient','between taps','boxed boolean','source recipient or input draft'):
            self.assertIn(text,cases)
    def test_received_helper_has_balanced_translation_unit(self):
        from source_checks import mask_literals
        source=mask_literals(strip_comments((ROOT/'Sources/TIMAntiRecallReplayReceived.inc').read_text()))
        depth=0
        for c in source:
            if c=='{':depth+=1
            elif c=='}':depth-=1
            self.assertGreaterEqual(depth,0)
        self.assertEqual(depth,0)

if __name__=='__main__':unittest.main()
