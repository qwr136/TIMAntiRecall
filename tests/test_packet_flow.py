"""Focused gates; runtime behavior is exercised by the real UIKit fixture."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class PacketFlowTests(unittest.TestCase):
    def test_queue_preserves_more_than_first_record_without_unbounded_retry(self):
        source=(ROOT/'Sources/TIMAntiRecallPacket.m').read_text()
        self.assertNotIn('claim = NO;',source)
        for token in ('timantirecall_packetEnqueue','timantirecall_packetQueue.count>=32',
                      'now-item.timantirecall_enqueued>30','timantirecall_packetQueuedKeys',
                      'timantirecall_packetSchedule','cancelled-context','identity-changed',
                      'timantirecall_packetReturnPresenter','timantirecall_cancelQueuedPackets'):
            self.assertIn(token,source)
        self.assertNotIn('writeToFile:',source)
        self.assertIn('redpack-queue-full',source)
    def test_correlated_response_uses_verified_fields_and_one_original_forward(self):
        source=(ROOT/'Sources/TIMAntiRecallPacketReceipt.m').read_text()
        for token in ('handleHBGrapResult:','grapHBData','aioData','listId','timantirecall_bill',
                      'result[@"state"]','result[@"recv_object"]','received[@"amount"]',
                      'state!=0','amount>0','memcmp','LC_UUID','MH_DYLIB',
                      'TIMANTIRECALL_UI_TEST','timantirecall_activeReceipt'):
            self.assertIn(token,source)
        self.assertEqual(source.count('((void(*)(id,SEL,id))original)(controller,selector,result);'),1)
        for token in ('authkey','password','writeToFile:','performSelector:','setGrabbedAmount:'):
            self.assertNotIn(token,source)
    def test_return_uses_same_bill_native_arrow_and_observes_real_effect(self):
        result=(ROOT/'Sources/TIMAntiRecallPacketResult.m').read_text()
        for token in ('CFT_UIRedGiftDetailBaseViewController','CFT_UIRedGiftCustomNavigationView',
                      'listid','customNavigationView','leftButton','leftButtonClick:',
                      'count!=1','target!=navigation','hitTest:','timantirecall_before'):
            self.assertIn(token,result)
        for token in ('evaluateJavaScript:','innerText','popViewControllerAnimated:',
                      'dismissViewControllerAnimated:','valueForKey:'):
            self.assertNotIn(token,result)
        flow=(ROOT/'Sources/TIMAntiRecallPacketOpen.m').read_text()
        self.assertIn('native-back-dispatched',flow)
        self.assertIn('effect-observed',flow)
        self.assertIn('skipped-native-error',flow)
        self.assertIn('native-result-page-not-ready',flow)
        self.assertIn('BOOL native=[context.timantirecall_nativeReceipt timantirecall_confirmed]',flow)
    def test_route_error_without_page_releases_pending_lock(self):
        source=(ROOT/'Sources/TIMAntiRecallPacketOpen.m').read_text()
        for token in ('error-without-page','!timantirecall_openOwnsPage(context)',
                      '[context.timantirecall_result timantirecall_originRestored]','if(!newVisible)'):
            self.assertIn(token,source)
        cases=(ROOT/'tests/ui/TIMAntiRecallPacketFlowCases.h').read_text()
        self.assertIn('route error without UI releases lock and second packet still routes once',cases)
        self.assertIn('failed first packet is not retried',cases)
    def test_uikit_requires_real_result_and_burst_regressions(self):
        driver=(ROOT/'tests/ui/run_inline_ui_tests.py').read_text()
        for token in ('Sources/TIMAntiRecallPacketReceipt.m','Sources/TIMAntiRecallPacketResult.m',
                      'packet-result-return','packet-native-response','packet-queue-batch',
                      'packet-queue-busy','packet-queue-manual'):
            self.assertIn(token,driver)
        cases=(ROOT/'tests/ui/TIMAntiRecallPacketFlowCases.h').read_text()
        for token in ('without dropping second','duplicate excluded','unchanged source model',
                      'wrong-bill result is never returned','without positive received amount',
                      'actual close','manual takeover cancels queued packet'):
            self.assertIn(token,cases)
if __name__=='__main__':unittest.main()
