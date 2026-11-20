from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]

class NativePacketEnvelopeTests(unittest.TestCase):
    def test_start_uses_native_nested_data_and_never_falls_back_to_outer_bill(self):
        source=(ROOT/'Sources/TIMAntiRecallPacketSilent.m').read_text()
        start=source.split('static void timantirecall_silentStart(',1)[1].split('static void timantirecall_silentLoading',1)[0]
        self.assertIn('params[@"extra_data"]',start)
        self.assertIn('[extra isKindOfClass:NSDictionary.class]?extra[@"listid"]:nil',start)
        self.assertNotIn('params[@"listid"]',start)
        self.assertIn('[bill isEqualToString:request.timantirecall_bill]',start)
        self.assertIn('original(wallet,selector,root,params,completion)',start)
        for token in ('setObject:', 'setValue:', 'mutableCopy', 'generateGrapHBParam'):
            self.assertNotIn(token,start)
    def test_each_local_rejection_is_distinct_from_a_wallet_error(self):
        source=(ROOT/'Sources/TIMAntiRecallPacketSilent.m').read_text()
        for name in ('context','envelope','bill-type','bill-mismatch','native-abi','legacy-route','no-preopen'):
            self.assertIn('@"redpack-silent-reject-'+name+'"',source)
        self.assertIn('request.timantirecall_phase=rejection',source)
        self.assertIn('live.timantirecall_phase?:@"redpack-silent-native-error"',source)
        self.assertIn('@"redpack-silent-native-start-forwarded"',source)
    def test_error_diagnostics_are_numeric_not_private_error_descriptions(self):
        source=(ROOT/'Sources/TIMAntiRecallPacketSilent.m').read_text()
        self.assertIn('redpack-silent-wallet-error-code-%lld',source)
        for token in ('error.localizedDescription','error.userInfo','error.description','params.description','NSLog('):
            self.assertNotIn(token,source)
    def test_runtime_doubles_no_longer_use_a_flat_native_entry(self):
        fixture=(ROOT/'tests/ui/TIMAntiRecallPacketSilentFixture.h').read_text()
        self.assertIn('return @{@"extra_data":@{@"listid":bill',fixture)
        self.assertIn('data.aioData.listId=params[@"extra_data"][@"listid"]',fixture)
        self.assertIn('timantirecall_silentForwardedEnvelope=params',fixture)
        route=(ROOT/'tests/ui/TIMAntiRecallPacketCases.h').read_text()
        self.assertIn('params:timantirecall_silentNativeEnvelope(bill)',route)
        self.assertNotIn('params:@{@"listid":bill}',route)
    def test_real_nested_success_and_bad_shape_guards_are_required(self):
        driver=(ROOT/'tests/ui/run_inline_ui_tests.py').read_text()
        for item in ('packet-native-parameter-envelope','packet-native-local-rejection'):
            self.assertIn(item,driver)
        cases=(ROOT/'tests/ui/TIMAntiRecallPacketSilentCases.h').read_text()
        self.assertIn('timantirecall_silentForwardedEnvelope==envelope',cases)
        for shape in ('flat','bad-extra','missing-bill','numeric-bill','mismatched-bill','no-preopen','native-error'):
            self.assertIn('@"'+shape+'"',cases)
        suite=(ROOT/'tests/ui/TIMAntiRecallInlineUIKitTests.m').read_text()
        self.assertIn('timantirecall_testSilentNativeEnvelope();',suite)

if __name__=='__main__':unittest.main()
