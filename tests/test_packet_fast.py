from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]

class FastPacketRecognitionTests(unittest.TestCase):
    def test_live_delivery_window_is_five_minutes_without_import_override(self):
        source=(ROOT/'Sources/TIMAntiRecallPacket.m').read_text()
        self.assertIn('age >= -4 && age <= 300',source)
        self.assertIn('isOnlineMsg"), YES',source)
        self.assertIn('isImportMsg"), NO',source)
        self.assertIn('item.timantirecall_deadline=now+30;',source)
        self.assertIn('20*NSEC_PER_MSEC',source)
        self.assertIn('MIN(records.count, (NSUInteger)256)',source)
        self.assertNotIn('deadline=now+30-MAX(0,age)',source)
        self.assertNotIn('timantirecall_observeLoadedPacket',source)
    def test_original_forwarding_unwinds_before_main_queue_consumption(self):
        source=(ROOT/'Sources/TIMAntiRecallPacket.m').read_text()
        receive=source.split('static void timantirecall_packetReceive(',1)[1].split('BOOL timantirecall_installPacketMonitor',1)[0]
        self.assertEqual(receive.count('original(target, selector, records);'),1)
        self.assertLess(receive.index('original(target, selector, records);'),receive.index('dispatch_async(dispatch_get_main_queue(), ^{'))
        self.assertIn('if(timantirecall_packetObserve(record,owner,claim,allowOwn,log))timantirecall_packetPump();',receive)
        self.assertNotIn('if(NSThread.isMainThread)consume()',receive)
    def test_recognition_budgets_are_bounded_and_do_not_cut_at_item_64(self):
        source=(ROOT/'Sources/TIMAntiRecallPacket.m').read_text()
        self.assertIn('MIN(records.count, (NSUInteger)256)',source)
        self.assertIn('packetPending, 1) >= 16',source)
        self.assertIn('timantirecall_packetQueue.count>=32',source)
        self.assertIn('timantirecall_packetReserve(item.timantirecall_owner,item.timantirecall_bill,NSProcessInfo.processInfo.systemUptime)',source)
        self.assertIn('NSNumber *previous=timantirecall_packetAttempts',source)
        self.assertIn('if(previous && now-previous.doubleValue<=120)return NO;',source)
        self.assertNotIn('loadedSeen',source)
    def test_shorter_poll_is_only_the_busy_fallback_not_an_idle_delay(self):
        source=(ROOT/'Sources/TIMAntiRecallPacket.m').read_text()
        retry=source.split('static void timantirecall_packetRetryPump(void) {',1)[1].split('static void timantirecall_packetPump(void) {',1)[0]
        self.assertIn('20*NSEC_PER_MSEC',retry)
        attempt=source.split('static BOOL timantirecall_packetAttempt(',1)[1].split('static void timantirecall_packetQueueEvent',1)[0]
        for token in ('dispatch_after','sleep(', 'usleep(', 'setGrabbedAmount:', 'pre_grap_token'):
            self.assertNotIn(token,attempt)
        self.assertIn('timantirecall_silentPacketReady(service)',source)
    def test_live_dispatch_coverage_and_no_old_packet_submitter(self):
        driver=(ROOT/'tests/ui/run_inline_ui_tests.py').read_text()
        for token in ('packet-fast-main-ingress','packet-delayed-live-window','packet-wide-message-batch'):
            self.assertIn(token,driver)
        cases=(ROOT/'tests/ui/TIMAntiRecallPacketFastCases.h').read_text()
        self.assertIn('recvMsgsWithRecords:batch',cases)
        self.assertIn('native claim waits until the original receive callback has returned',cases)
        source=(ROOT/'Sources/TIMAntiRecallPacket.m').read_text()
        self.assertNotIn('observeLoadedPacket',source)
        self.assertNotIn('loadedSeen',source)

if __name__=='__main__':unittest.main()
