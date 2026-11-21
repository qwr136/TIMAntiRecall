import unittest
from pathlib import Path
from source_checks import function_body, strip_comments
ROOT=Path(__file__).resolve().parents[1]
class InlineContractTests(unittest.TestCase):
    def test_push_uses_session_owner_only_after_actual_block(self):
        source=(ROOT/'Sources/TIMAntiRecallRuntime.m').read_text()
        body=function_body(source,'timantirecall_receivePush')
        self.assertIn('timantirecall_markIntercepted(buffer,timantirecall_sessionOwner(receiver))',body)
        self.assertNotIn('timantirecall_markIntercepted(buffer,nil)',body)
        self.assertLess(body.index('if (decision != TIMAntiRecallPass)'),body.index('timantirecall_markIntercepted'))
        self.assertLess(body.index('timantirecall_markIntercepted'),body.index('TIMAntiRecallPushIMP original'))
    def test_installer_signature_and_native_stub_match(self):
        header=(ROOT/'Headers/TIMAntiRecallMarks.h').read_text()
        source=(ROOT/'Sources/TIMAntiRecallInline.m').read_text()
        stub=(ROOT/'tests/native/TIMAntiRecallInlineNativeStub.m').read_text()
        for text in (header,source,stub):self.assertIn('BOOL timantirecall_installInlineIndicator(void)',text)
        body=function_body(source,'timantirecall_installInlineIndicator')
        self.assertIn('return nt && legacy;',body);self.assertIn('return NO;',body)
        self.assertIn('timantirecall_installNTRows()',body)
        self.assertIn('timantirecall_installLegacyRows()',body)
        self.assertNotIn('return;',body)
    def test_swift_is_real_input_and_generated_header(self):
        make=(ROOT/'Makefile').read_text();snapshot=(ROOT/'scripts/build_evidence.py').read_text()
        self.assertIn('$(wildcard Sources/*.swift)',make)
        self.assertIn("'*.swift'",snapshot)
        self.assertFalse((ROOT/'Headers/TIMAntiRecall-Swift.h').exists())
        self.assertIn('Mirror(reflecting:',(ROOT/'Sources/TIMAntiRecallRecordBridge.swift').read_text())
    def test_ui_execution_is_mandatory_before_receipt(self):
        flow=(ROOT/'.github/workflows/build.yml').read_text()
        self.assertLess(flow.index('run_inline_ui_tests.py'),flow.index('toolchain.py receipt'))
        evidence=(ROOT/'scripts/build_evidence.py').read_text()
        for text in ('ui_build','validate_result','validate_previews','sourceDigest','githubRunAttempt'):
            self.assertIn(text,evidence)
    def test_session_owner_is_captured_without_auth_fields(self):
        source=strip_comments((ROOT/'Sources/TIMAntiRecallSession.m').read_text())
        self.assertIn('OCInitSessionConfig',source);self.assertIn('selfUid',source)
        self.assertIn('OBJC_ASSOCIATION_COPY',source)
        for token in ('d2Key','password','a2','deviceInfo'):self.assertNotIn(token,source)
    def test_macos_keeps_real_marks_session_but_excludes_uikit(self):
        source=(ROOT/'scripts/run_native_tests.py').read_text()
        self.assertIn("p.endswith('.m')",source)
        for token in ('Sources/TIMAntiRecallInline.m','Sources/TIMAntiRecallIndicatorView.m','TIMAntiRecallMarksTests.m'):
            self.assertIn(token,source)
        self.assertNotIn("'Sources/TIMAntiRecallMarks.m'",source)
    def test_private_sequence_cross_author_collision_is_display_ambiguous(self):
        inline=strip_comments((ROOT/'Sources/TIMAntiRecallInline.m').read_text())
        helper=function_body(inline,'timantirecall_eventSharesDisplaySlot')
        self.assertIn('@"owner"',helper);self.assertIn('@"seq"',helper);self.assertIn('@"peer"',helper)
        self.assertIn('BOOL group=',helper)
        self.assertIn('if(group&&![event[@"author"] isEqual:identity[@"author"]])return NO;',helper)
        self.assertIn('timantirecall_eventSharesDisplaySlot(event,candidate)',inline)
        self.assertIn('![identity[@"author"] isEqual:candidate[@"author"]]',inline)
        ui=(ROOT/'tests/ui/TIMAntiRecallInlineUIKitTests.m').read_text()
        block=function_body(ui,'timantirecall_testAmbiguousSequence')
        self.assertIn('target.senderUid=@"self_uid"',block)
        self.assertIn('collision.msgId++;',block)
        self.assertIn('collision=timantirecall_record(1,779,@"peer_a",0)',block)
        self.assertIn('timantirecall_private(@"self_uid",@"peer_a",779)',block)
        self.assertIn('cross-author recall ambiguity',block)

    def test_cold_recall_protection_is_exact_setter_only(self):
        source=strip_comments((ROOT/'Sources/TIMAntiRecallColdSync.m').read_text())
        self.assertIn('setRecallTime:',source);self.assertIn('timantirecall_recordIdentity',source)
        self.assertIn('timantirecall_sharedMarks()',source)
        self.assertIn('timantirecall_containsRecallEventForIdentity',source)
        self.assertIn('void(*)(id,SEL,int64_t)',source)
        self.assertNotIn('removeDBMsg',source);self.assertNotIn('deleteMsg',source)
    def test_cold_hook_is_installed_before_session_push(self):
        source=(ROOT/'Hooks/TIMAntiRecallMain.m').read_text()
        self.assertLess(source.index('timantirecall_installColdRecallProtection()'),source.index('timantirecall_installSessionTracking'))
