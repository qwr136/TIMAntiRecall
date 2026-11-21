import json
import re
import unittest
from pathlib import Path
from source_checks import strip_comments, function_body
ROOT = Path(__file__).resolve().parents[1]

class RichReplayTests(unittest.TestCase):
    def test_verified_schema_fields_and_encodings(self):
        schema=json.loads((ROOT/'tests/fixtures/tim-rich-schema.json').read_text())
        table=(ROOT/'Sources/TIMAntiRecallReplaySchema.inc').read_text()
        for cls,fields in schema.items():
            block=table.split('timantirecall_'+cls+'Fields[] = {',1)[1].split('};',1)[0]
            rows=re.findall(r'\{"([^"]+)","([^"]+)","([^"]*)"\}',block)
            expected=[]
            for field in fields:
                t=field['type'];enc='@' if t.startswith('@') else t
                expected.append((field['name'],enc,t[2:-1] if t.startswith('@"') else ''))
                self.assertTrue(field['getter'].startswith(enc))
                self.assertIn(enc+'16',field['setter'])
            self.assertEqual(rows,expected,cls)
    def test_original_record_is_never_a_send_payload(self):
        s=strip_comments((ROOT/'Sources/TIMAntiRecallReplayPayload.m').read_text())
        for token in ('timantirecall_richDescribe','timantirecall_richBuild','[[cls alloc] init]','"elementId","q",@0','sourceMsgTextElems','ReplyPreview'):
            self.assertIn(token,s)
        self.assertNotIn('setValue:',s);self.assertNotIn('object_setIvar',s)
        self.assertNotIn('resendMsg',s);self.assertNotIn('msgAttrs',s)
        send=function_body(s,'timantirecall_richReplaySend')
        self.assertIn('timantirecall_richReplayElements(snapshot)',send)
        self.assertIn('contact,elements,nil,completion',send)
    def test_photo_native_api_and_file_isolation(self):
        s=strip_comments((ROOT/'Sources/TIMAntiRecallReplayPayload.m').read_text())
        for token in ('sendPicMsg:sourcePath:additionalMsg:picSubType:callBack:','"@",":","@","@","@","i","@?"','O_NOFOLLOW','S_ISREG','24*1024*1024','convertToOCContact','"peerUin","q"','"chatType","q"','NSUUID.UUID.UUIDString','NSFilePosixPermissions:@0600','photoCompletion'):
            self.assertIn(token,s)
        self.assertNotIn('NSURLSession',s);self.assertNotIn('removeItemAtPath:file',s)
        fixture=(ROOT/'tests/ui/TIMAntiRecallReplayPhotoCases.h').read_text()
        for token in ('missing local original','flash photo','photo contact conversion','replaced photo file','groupCode roundtrip','original file'):
            self.assertIn(token,fixture)
    def test_rich_content_frozen_across_two_taps(self):
        s=strip_comments((ROOT/'Sources/TIMAntiRecallReplay.m').read_text())
        self.assertGreaterEqual(s.count('[payload isEqual:self.timantirecall_firstPayload]'),2)
        self.assertIn('self.timantirecall_firstPayload=nil',s)
        self.assertIn('timantirecall_richReplaySend(service,contact,record,payload)',s)
        self.assertIn('sendTextMsgByOCContact:richText:callBack:',s)
    def test_real_uikit_coverage_is_wired_and_receipted(self):
        runner=(ROOT/'tests/ui/run_inline_ui_tests.py').read_text()
        inline=(ROOT/'tests/ui/TIMAntiRecallInlineUIKitTests.m').read_text()
        for token in ('rich-message-replay','rich-message-replay-quote','rich-message-replay-deep-copy','rich-message-replay-guards','rich-message-replay-photo'):
            self.assertIn('"'+token+'"',runner)
        for file in ('TIMAntiRecallReplayRichFixture.m','TIMAntiRecallReplayPhotoFixture.m'):
            self.assertIn(file,runner)
        for call in ('timantirecall_testRichReplay(root)','timantirecall_testPhotoReplay(root)'):
            self.assertIn(call,inline)
        self.assertIn('glob("*.inc")',runner)
    def test_no_changes_to_own_recall_or_wallet(self):
        import subprocess
        paths=['Sources/TIMAntiRecallRuntime.m','Sources/TIMAntiRecallSettings.m','Sources/TIMAntiRecallWire.m','Sources/TIMAntiRecallMarks.m','Sources/TIMAntiRecallMarkStore.m','Sources/TIMAntiRecallPacket.m','Sources/TIMAntiRecallPacketOpen.m','Sources/TIMAntiRecallPacketWallet.m','Sources/TIMAntiRecallPacketSilent.m','Sources/TIMAntiRecallPacketToast.m']
        # Test fixture pins the frozen production hashes, no full-history checkout requirement.
        import hashlib
        frozen=json.loads((ROOT/'tests/fixtures/tim-rich-frozen.json').read_text())
        for path in paths:self.assertEqual(hashlib.sha256((ROOT/path).read_bytes()).hexdigest(),frozen[path])

if __name__=='__main__':unittest.main()
