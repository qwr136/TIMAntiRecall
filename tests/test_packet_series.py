from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class ForegroundPacketSeriesTests(unittest.TestCase):
    def test_next_checks_wallet_slots_not_previous_credit(self):
        source=(ROOT/'Sources/TIMAntiRecallPacket.m').read_text()
        pump=source.split('static void timantirecall_packetPump(void) {',1)[1].split('static BOOL timantirecall_packetEnqueue',1)[0]
        for token in ('timantirecall_silentPacketReady(service)', 'timantirecall_packetAttempt(item,presenter)','deadline'):
            self.assertIn(token,pump)
        for token in ('BusyUntil','ReturnPresenter','grabbedAmount','claim = NO;'):
            self.assertNotIn(token,pump)
        self.assertIn('timantirecall_loaded',source)
        self.assertIn('queued.timantirecall_loaded',source)
        source=(ROOT/'Sources/TIMAntiRecallPacket.m').read_text()
        enqueue=source.split('static BOOL timantirecall_packetEnqueue(',1)[1].split('static BOOL timantirecall_packetObserve(',1)[0]
        self.assertLess(enqueue.index('sameBill=queued;break;'),enqueue.index('removeObjectIdenticalTo:sameBill'))
        self.assertIn('removeObjectIdenticalTo:sameBill',enqueue)
        self.assertIn('insertObject:sameBill atIndex:0',enqueue)
        self.assertIn('packetQueue.count>=32',enqueue)
        self.assertNotIn('claim = NO;',source)
    def test_success_intercepts_only_verified_detail_completion(self):
        source=(ROOT/'Sources/TIMAntiRecallPacketWallet.m').read_text()
        for token in ('LC_UUID','CPU_SUBTYPE_ARM64_ALL','0xc00158u','grapHBView','listId','state==0', 'amount>0','class_addMethod(cls,selector','timantirecall_walletSameSuccessfulPopup(controller)'):
            self.assertIn(token,source)
        self.assertEqual(source.count('original(controller,selector,animated,notify?:completion);'),1)
        self.assertNotIn('setGrapHBCallback:',source)
        self.assertNotIn('setPreGrapHBCallback:',source)
    def test_ordinary_foreground_presenters_not_chat_rows(self):
        source=(ROOT/'Sources/TIMAntiRecallPacket.m').read_text()
        self.assertIn('controller=controller.presentedViewController;continue;',source)
        self.assertIn('recvMsgsWithRecords:',source)
        self.assertIn('UIApplicationStateActive',source)
        self.assertNotIn('visibleCells',source)
        script=(ROOT/'tests/ui/run_inline_ui_tests.py').read_text()
        for coverage in ('packet-offscreen-on-settings','packet-native-slot-series','packet-no-detail'):
            self.assertIn(coverage,script)
if __name__=='__main__':unittest.main()
