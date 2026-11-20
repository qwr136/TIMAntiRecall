from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]

class PacketAmountToastTests(unittest.TestCase):
    def test_receipt_uses_correlated_native_received_amount_after_original(self):
        source=(ROOT/'Sources/TIMAntiRecallPacketWallet.m').read_text()
        hook=source.split('static void timantirecall_popupDismiss(',1)[1].split('BOOL timantirecall_installPacketFinish',1)[0]
        self.assertIn('timantirecall_walletSameSuccessfulPopup(controller)',hook)
        self.assertIn('timantirecall_packetAmountText(result[@"recv_object"][@"amount"])',hook)
        self.assertNotIn('send_object',hook)
        self.assertLess(hook.index('original(controller,selector,animated,notify?:completion);'),hook.index('timantirecall_showPacketAmountText('))
        self.assertIn('dispatch_async(dispatch_get_main_queue()',hook)
    def test_fen_format_is_integer_only_and_not_locale_or_float_based(self):
        source=(ROOT/'Sources/TIMAntiRecallPacketToast.m').read_text().split('#ifdef TIMANTIRECALL_NATIVE_TEST')[0]
        for token in ('CFBooleanGetTypeID()',"c<'0' || c>'9'",'digits.length>18','if(!fen)return nil','fen/100,fen%100'):
            self.assertIn(token,source)
        for token in ('doubleValue','floatValue','writeToFile','NSUserDefaults','NSLog'):
            self.assertNotIn(token,source)
    def test_ui_is_centered_nonblocking_and_three_seconds(self):
        source=(ROOT/'Sources/TIMAntiRecallPacketToast.m').read_text()
        for token in ('centerXAnchor','centerYAnchor','label.userInteractionEnabled=NO','3*NSEC_PER_SEC',
                      'generation==timantirecall_packetToastGeneration','UIApplicationStateActive','UISceneWillDeactivateNotification',
                      'UISceneDidDisconnectNotification','UIApplicationDidEnterBackgroundNotification'):
            self.assertIn(token,source)
        for token in ('makeKeyAndVisible','presentViewController','grapHBCallback','dispatch_semaphore','sleep(', 'NSLog', 'writeToFile'):
            self.assertNotIn(token,source)
    def test_real_ui_and_amount_guards_are_required_by_ci(self):
        driver=(ROOT/'tests/ui/run_inline_ui_tests.py').read_text()
        self.assertIn('Sources/TIMAntiRecallPacketToast.m',driver)
        for token in ('packet-amount-native-success','packet-amount-validation','packet-amount-center-touch',
                      'packet-amount-three-seconds','packet-amount-refresh','packet-amount-lifecycle'):
            self.assertIn(token,driver)
        self.assertIn('tim-inline-packet-amount-simulator.png',driver)

if __name__=='__main__':unittest.main()
