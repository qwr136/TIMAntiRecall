from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class SilentPacketTests(unittest.TestCase):
    def test_original_route_and_native_qualifications_are_preserved(self):
        source=(ROOT/'Sources/TIMAntiRecallPacketSilent.m').read_text()
        for token in ('timantirecall_walletCanAcceptPacket(service)','isGotoNewGrapProcess:', 'isNeedGotoPreGrapProcess:',
                      'original(wallet,selector,root,params,completion)', 'onOpenButtonClick:', 'ivar_getOffset(low)!=0x30', 'isPaying'):
            self.assertIn(token,source)
        for token in ('requestData:', 'authkey', 'setGrabbedAmount:', 'isNeedShowAlertView:', 'gotoRealNameVerify:', 'qpay_hb_na_grap'):
            self.assertNotIn(token,source)
    def test_the_owned_controller_is_not_presented_then_closed(self):
        source=(ROOT/'Sources/TIMAntiRecallPacketSilent.m').read_text()
        view=source.split('static void timantirecall_silentView(',1)[1].split('static void timantirecall_silentDismiss',1)[0]
        self.assertIn('if(!timantirecall_silentOwns(request,data)) {original(manager,selector,controller);return;}',view)
        self.assertIn('loadViewIfNeeded',view)
        self.assertIn('request.timantirecall_submitted=YES',view)
        for token in ('setHidden:', '.alpha=', 'presentViewController:', 'dismissViewControllerAnimated:', 'sendActionsForControlEvents:'):
            self.assertNotIn(token,view)
    def test_original_callback_slots_and_native_data_prove_ownership(self):
        source=(ROOT/'Sources/TIMAntiRecallPacketSilent.m').read_text()
        for token in ('data==request.timantirecall_data', 'preGrapHBCallback', 'grapHBCallback', 'timantirecall_silentDataMatches',
                      'object_getIvar(wallet,timantirecall_silentLowSlot)', 'dispatch_async(dispatch_get_main_queue()'):
            self.assertIn(token,source)
        self.assertNotIn('setGrapHBCallback:',source)
    def test_late_native_receipt_is_not_closed_by_timeout(self):
        source=(ROOT/'Sources/TIMAntiRecallPacketSilent.m').read_text()
        expiry=source.split('static void timantirecall_silentWaitExpired(',1)[1].split('#ifdef TIMANTIRECALL_UI_TEST',1)[0]
        self.assertIn('if(!request.timantirecall_submitted && request.timantirecall_preResolved)',expiry)
        self.assertNotIn('setGrapHBCallback:',expiry)
        self.assertIn('timantirecall_silentWaitExpired(weakRequest)',source)
    def test_background_ingress_does_not_require_foreground_epoch_or_popup(self):
        source=(ROOT/'Sources/TIMAntiRecallPacket.m').read_text()
        receive=source.split('static void timantirecall_packetReceive(',1)[1].split('BOOL timantirecall_installPacketMonitor',1)[0]
        for token in ('packetEpoch','epoch & 1','UIApplicationStateActive','timantirecall_beginPacketOpenForBill'):
            self.assertNotIn(token,receive)
        self.assertIn('timantirecall_packetAccountValid(owner)',receive)
        for token in ('beginBackgroundTask','setKeepAliveTimeout','AVAudioSession','setMinimumBackgroundFetchInterval'):
            self.assertNotIn(token,source)
    def test_true_uikit_background_before_resume_and_no_popup_are_required(self):
        script=(ROOT/'tests/ui/run_inline_ui_tests.py').read_text()
        self.assertIn('Sources/TIMAntiRecallPacketSilent.m',script)
        for token in ('packet-no-popup-before-present','packet-native-preopen-token','packet-native-risk-preserved',
                      'packet-background-before-resume','packet-late-receipt','packet-manual-window-preserved'):
            self.assertIn(token,script)
        cases=(ROOT/'tests/ui/TIMAntiRecallPacketSilentCases.h').read_text()
        self.assertIn('UIApplicationStateBackground',cases)
        self.assertIn('timantirecall_silentPresents==presents',cases)
        self.assertIn('manual success retains original details completion',cases)
if __name__=='__main__':unittest.main()
