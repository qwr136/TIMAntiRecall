import hashlib,json,re,unittest
from pathlib import Path
from source_checks import function_body,strip_comments
ROOT=Path(__file__).resolve().parents[1]

class MediaContactTests(unittest.TestCase):
    def test_no_guild_equivalence_only_after_ordinary_chat_and_exact_peer(self):
        source=strip_comments((ROOT/'Sources/TIMAntiRecallReplayPayload.m').read_text())
        body=function_body(source,'timantirecall_richPhotoContact')
        self.assertIn('kind.intValue!=1&&kind.intValue!=2',body)
        self.assertIn('uin.longLongValue<=0',body)
        self.assertIn('strcmp(*field,"guildId")==0',body)
        self.assertIn('[original isKindOfClass:NSString.class]&&[original length]==0',body)
        self.assertIn('[converted isKindOfClass:NSString.class]&&[converted length]==0',body)
        self.assertIn('if(!originalAbsent||!convertedAbsent)',body)
        self.assertIn('original!=converted&&![original isEqual:converted]',body)
        self.assertLess(body.index('kind.intValue!=1'),body.index('originalAbsent'))
        for bad in ('stringByTrimming','description','setGuildId','[original length]==[converted length]'):
            self.assertNotIn(bad,body)
    def test_sender_local_failures_are_fixed_and_opt_in(self):
        source=strip_comments((ROOT/'Sources/TIMAntiRecallReplayPayload.m').read_text())
        helper=function_body(source,'timantirecall_photoSendRejected')
        self.assertIn('timantirecall_replayDiagnostics',helper)
        self.assertIn('@"shape":@"photo"',helper)
        for bad in ('description','@"path"','@"value"','@"code"','@"uid"'):
            self.assertNotIn(bad,helper)
        send=function_body(source,'timantirecall_richReplaySend')
        for reason in ('photo-send-api-rejected','photo-source-read-rejected','photo-temp-directory-rejected','photo-temp-write-rejected','photo-native-exception'):
            self.assertIn(reason,send)
        self.assertIn('nativeContact,path,nil,[snapshot[@"subtype"] intValue],photoCompletion',send)
        self.assertIn('timantirecall_richReplayElements(snapshot)',send)
        self.assertIn('contact,elements,nil,completion',send)
    def test_real_converter_fixture_and_required_device_regressions(self):
        fixture=(ROOT/'tests/ui/TIMAntiRecallReplayPhotoFixture.m').read_text()
        self.assertIn('contact.guildId=TIMAntiRecallReplayPhotoProbe.timantirecall_shared.timantirecall_conversionGuild',fixture)
        cases=(ROOT/'tests/ui/TIMAntiRecallReplayMediaContactCases.h').read_text()
        for token in ('oldEqual','roundtrip.guildId==nil','@[@1,@2]','@0,@NO,NSNull.null','photo-contact-uin-unavailable','photo-source-read-rejected','TIMANTIRECALL_SECRET_GUILD','TIMANTIRECALL_SECRET_MEDIA_PEER','photo send diagnostic OFF'):
            self.assertIn(token,cases)
        driver=(ROOT/'tests/ui/run_inline_ui_tests.py').read_text()
        main=(ROOT/'tests/ui/TIMAntiRecallInlineUIKitTests.m').read_text()
        self.assertIn('timantirecall_testPhotoContactContract();',main)
        for coverage in ('photo-contact-absence-contract','photo-send-rejection-diagnostics'):
            self.assertIn('"'+coverage+'"',driver)
            self.assertIn('@"'+coverage+'"',cases)
    def test_legacy_freeze_exemption_is_explicit_and_narrow(self):
        frozen=json.loads((ROOT/'tests/fixtures/tim-rich-diag-frozen.json').read_text())
        self.assertEqual(sum(map(len,frozen.values())),8)
        for file,functions in frozen.items():
            source=strip_comments((ROOT/file).read_text())
            for name,digest in functions.items():
                self.assertEqual(hashlib.sha256(function_body(source,name).encode()).hexdigest(),digest)
        for name in ('timantirecall_richReadPhoto','timantirecall_richReplayElements','timantirecall_richBuild'):
            self.assertIn(name,frozen['Sources/TIMAntiRecallReplayPayload.m'])

if __name__=='__main__':unittest.main()
