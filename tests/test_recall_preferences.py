import ctypes
import unittest
from pathlib import Path
import test_wire as wire
from test_wire import blob, integer, envelope, private, group
from test_wire_events import WireEvent
from source_checks import strip_comments, function_body
ROOT=Path(__file__).resolve().parents[1]
class RecallScopeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        wire.WireTests.setUpClass();cls.scope=wire.WireTests.library.timantirecall_extractRecallScope
        cls.scope.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.POINTER(WireEvent)]
        cls.scope.restype=ctypes.c_int
    @classmethod
    def tearDownClass(cls):wire.WireTests.tearDownClass()
    def extract(self,data):
        value=WireEvent();buffer=ctypes.create_string_buffer(data)
        return self.scope(buffer,len(data),ctypes.byref(value)),value
    def test_group_scope_independent_of_optional_author(self):
        ok,value=self.extract(group())
        self.assertEqual(ok,1);self.assertEqual((value.kind,value.group),(2,9))
    def test_private_scope_retains_exact_participants(self):
        ok,value=self.extract(private())
        self.assertEqual(ok,1);self.assertEqual(value.kind,1)
        self.assertEqual((value.from_uid,value.to_uid),(b'u_sender',b'u_peer'))
    def test_unknown_truncated_and_ambiguous_never_yield_scope(self):
        for packet in (private(),group()):
            for n in range(len(packet)):self.assertEqual(self.extract(packet[:n])[0],0)
        info=blob(1,b'a')+blob(1,b'b')+blob(2,b'c')+integer(20,1)
        self.assertEqual(self.extract(envelope(528,138,blob(1,info)))[0],0)
        self.assertEqual(self.scope(None,0,None),0)
    def test_uid_validation_applies_to_scope_without_weakening_classifier(self):
        for uid in (b'bad\0uid',b'bad/uid',b'a'*129):
            packet=envelope(528,138,blob(1,blob(1,uid)+blob(2,b'peer')+integer(20,1)))
            self.assertEqual(self.extract(packet)[0],0)
class PreferencesContractTests(unittest.TestCase):
    def test_runtime_gate_precedes_block_and_original_forward_is_single(self):
        body=function_body((ROOT/'Sources/TIMAntiRecallRuntime.m').read_text(),'timantirecall_receivePush')
        self.assertLess(body.index('timantirecall_shouldBlockRecall'),body.index('timantirecall_markIntercepted'))
        self.assertEqual(body.count('original(receiver, selector, command, buffer, extra)'),1)
        self.assertNotIn('writeTo',body);self.assertNotIn('dataWithContents',body)
    def test_restart_suite_is_non_optional_and_sealed(self):
        runner=strip_comments((ROOT/'scripts/run_native_tests.py').read_text())
        seal=strip_comments((ROOT/'scripts/build_evidence.py').read_text())
        self.assertIn("('seed','restore','negative')",runner)
        self.assertIn('state_output),phase',runner)
        self.assertIn("state_tests.get('source')==current",seal)
        self.assertIn('state_tests=state_tests',seal)
    def test_ui_sources_are_real_and_new_coverage_mandatory(self):
        driver=(ROOT/'tests/ui/run_inline_ui_tests.py').read_text()
        for path in ('TIMAntiRecallPreferencesUI.m','TIMAntiRecallPreferencesEntry.m','TIMAntiRecallMarkStore.m'):
            self.assertIn(path,driver)
        for tag in ('chat-forwarding','captured-time','persist-ui','preferences-entry','preferences-controls'):
            self.assertIn(tag,driver)
        self.assertIn('tim-inline-settings-preview.png',driver)
    def test_existing_binding_paths_and_uuid_guard_remain(self):
        inline=strip_comments((ROOT/'Sources/TIMAntiRecallInline.m').read_text())
        for token in ('timantirecall_installNTRows','timantirecall_installLegacyRows','timantirecall_legacyRowIdentity','timantirecall_currentModelForView','2048'):
            self.assertIn(token,inline)
        source=(ROOT/'Sources/TIMAntiRecallRuntime.m').read_text()
        self.assertIn('3C237FA0-5985-3376-BF98-EF1698563247',source)
if __name__=='__main__':unittest.main()
