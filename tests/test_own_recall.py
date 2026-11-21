import ctypes
import unittest
from pathlib import Path
import test_wire as wire
from test_wire import blob, integer, envelope
from source_checks import function_body, strip_comments
ROOT=Path(__file__).resolve().parents[1]

def group_actor(actor=b'owner', author=b'peer', subtype=17, suffix=b'', outer_actor=None):
    recall=(blob(1,actor) if actor is not None else b'')+suffix
    recall+=blob(3,integer(1,42)+(blob(6,author) if author is not None else b''))
    notify=integer(1,7)+integer(4,99)+blob(11,recall)
    if outer_actor is not None:notify+=blob(21,outer_actor)
    return envelope(732,subtype,b'\0\0\0\x63\0'+len(notify).to_bytes(2,'big')+notify)

class RecallActorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        wire.WireTests.setUpClass()
        cls.actor=wire.WireTests.library.timantirecall_extractRecallActor
        cls.actor.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.c_void_p]
        cls.actor.restype=ctypes.c_int
    @classmethod
    def tearDownClass(cls):wire.WireTests.tearDownClass()
    def extract(self,data):
        buf=ctypes.create_string_buffer(data)
        result=ctypes.create_string_buffer(b'x'*128,129)
        ok=self.actor(buf,len(data),result)
        return ok,result.value
    def test_private_actor_is_from_not_to(self):
        for subtype in (138,139):
            p=envelope(528,subtype,blob(1,blob(1,b'owner')+blob(2,b'peer')+integer(20,42)))
            self.assertEqual(self.extract(p),(1,b'owner'))
    def test_group_actor_is_independent_of_target_author(self):
        for subtype in (16,17):
            for actor,author in ((b'owner',b'peer'),(b'admin',b'owner'),(b'owner',None)):
                self.assertEqual(self.extract(group_actor(actor,author,subtype)),(1,actor))
    def test_never_substitute_author_or_outer_notify_operator(self):
        for packet in (group_actor(None,b'owner'),group_actor(None,b'peer',outer_actor=b'owner')):
            self.assertEqual(self.extract(packet),(0,b''))
        self.assertEqual(self.extract(group_actor(b'admin',b'owner',outer_actor=b'owner')),(1,b'admin'))
    def test_actor_malformed_duplicate_or_invalid_type_is_unknown(self):
        for value in (b'',b'bad/uid',b'a\0b',b'a\nb',b'x'*129):
            self.assertEqual(self.extract(group_actor(value)),(0,b''))
        for suffix in (blob(1,b'owner'),blob(1,b'peer'),integer(1,10),b'\x80'):
            self.assertEqual(self.extract(group_actor(suffix=suffix)),(0,b''))
        self.assertEqual(self.extract(group_actor(None,suffix=integer(1,1))),(0,b''))
    def test_all_truncations_and_unknown_commands_are_unidentified(self):
        p=group_actor()
        for n in range(len(p)):self.assertEqual(self.extract(p[:n]),(0,b''))
        self.assertEqual(self.extract(envelope(82,0,b'ordinary')),(0,b''))
        self.assertEqual(self.actor(None,0,None),0)
    def test_cleanup_without_author_does_not_relax_display_events(self):
        from test_wire_events import WireEvent
        cleanup=wire.WireTests.library.timantirecall_extractRecallCleanupTargets
        strict=wire.WireTests.library.timantirecall_extractRecallEvents
        for fn in (cleanup,strict):
            fn.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.POINTER(WireEvent),ctypes.c_size_t]
            fn.restype=ctypes.c_size_t
        packet=group_actor(b'owner',None)
        buf=ctypes.create_string_buffer(packet);out=(WireEvent*64)()
        self.assertEqual(cleanup(buf,len(packet),out,64),1)
        self.assertEqual((out[0].kind,out[0].group,out[0].sequence,out[0].author),(2,99,42,b''))
        self.assertEqual(strict(buf,len(packet),out,64),0)
        for actor in (b'',b'bad/uid'):
            packet=group_actor(b'owner',actor);buf=ctypes.create_string_buffer(packet)
            self.assertEqual(cleanup(buf,len(packet),out,64),0)

    def test_runtime_filters_before_interception_and_keeps_one_original(self):
        source=strip_comments((ROOT/'Sources/TIMAntiRecallRuntime.m').read_text())
        body=function_body(source,'timantirecall_receivePush')
        self.assertLess(body.index('timantirecall_forgetOwnRecall'),body.index('timantirecall_markIntercepted'))
        self.assertLess(body.index('timantirecall_shouldBlockRecall'),body.index('timantirecall_markIntercepted'))
        self.assertEqual(body.count('original(receiver, selector, command, buffer, extra)'),1)
        self.assertNotIn('timantirecall_currentAccount()',body)
        settings=strip_comments((ROOT/'Sources/TIMAntiRecallSettings.m').read_text())
        body=settings.split('- (BOOL)timantirecall_shouldBlockData:',1)[1].split('- (BOOL)timantirecall_commit:',1)[0]
        self.assertIn('timantirecall_extractRecallActor',body)
        self.assertIn('[@(actor) isEqual:owner])return NO',body)
        self.assertNotIn('if(!self.timantirecall_overrides.count)return YES',body)
        self.assertNotIn('return YES',body)

if __name__=='__main__':unittest.main()
