import hashlib
import json
import unittest
from pathlib import Path
from source_checks import strip_comments,function_body
ROOT=Path(__file__).resolve().parents[1]

class RichRejectDiagnosticTests(unittest.TestCase):
    def test_observation_does_not_change_sending_or_original_photo_handling(self):
        frozen=json.loads((ROOT/'tests/fixtures/tim-rich-diag-frozen.json').read_text())
        for path,functions in frozen.items():
            source=strip_comments((ROOT/path).read_text())
            for name,digest in functions.items():
                body=function_body(source,name)
                self.assertEqual(hashlib.sha256(body.encode()).hexdigest(),digest,(path,name))

    def test_eligibility_reject_distinguishes_payload_and_identity(self):
        s=strip_comments((ROOT/'Sources/TIMAntiRecallReplay.m').read_text())
        body=function_body(s,'timantirecall_replayContextAtPoint')
        self.assertIn('if(!payload)',body)
        self.assertIn('@"field":@"payload"',body)
        self.assertIn('@"reason":@"message-identity-rejected"',body)
        self.assertLess(body.index('if(!payload)'),body.index('timantirecall_recordIdentity'))
        self.assertLess(body.index('message-identity-rejected'),body.index('timantirecall_replayContact'))

    def test_rich_reject_trace_is_opt_in_and_only_shape_not_original_values(self):
        s=strip_comments((ROOT/'Sources/TIMAntiRecallReplayPayload.m').read_text())
        helper=function_body(s,'timantirecall_richRejectTrace')
        self.assertIn('if(![timantirecall_settings() timantirecall_replayDiagnostics])return',helper)
        for token in ('@"valueClass"','@"valueKind"','@"number-zero"','@"string-empty"','@"data-empty"'):
            self.assertIn(token,helper)
        for token in ('@"path":','@"content":','@"value":','description','UTF8String'):
            self.assertNotIn(token,helper)
        for reason in ('getter-missing','getter-abi-mismatch','field-value-rejected','element-type-rejected','photo-path-shape','photo-source-unavailable','photo-invalid-flag','reply-target-zero','snapshot-ready'):
            self.assertIn(reason,s)
        trace=(ROOT/'Sources/TIMAntiRecallReplayTrace.m').read_text()
        for token in ('@"rich"','replay-rich-reject-v2','@"expectedABI"','@"actualABI"'):
            self.assertIn(token,trace)
        self.assertIn('timantirecall_replayTraceCount>=192',trace)
        self.assertIn('repetitions>=4',trace)

    def test_diagnostic_events_and_redaction_are_mandatory_uikit_coverage(self):
        cases=(ROOT/'tests/ui/TIMAntiRecallReplayDiagnosticCases.h').read_text()
        for token in ('class_addMethod','getter-abi-mismatch','field-value-rejected','photo-path-shape','message-identity-rejected','snapshot-ready','TIMANTIRECALL_SECRET_BODY','TIMANTIRECALL_SECRET_PATH','diagnostics disabled adds no rejection events'):
            self.assertIn(token,cases)
        driver=(ROOT/'tests/ui/run_inline_ui_tests.py').read_text()
        inline=(ROOT/'tests/ui/TIMAntiRecallInlineUIKitTests.m').read_text()
        self.assertIn('"rich-rejection-diagnostics"',driver)
        self.assertIn('#import "TIMAntiRecallReplayDiagnosticCases.h"',inline)
        self.assertIn('timantirecall_testRichDiagnostics(root)',inline)

if __name__=='__main__':unittest.main()
