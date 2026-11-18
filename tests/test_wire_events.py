import ctypes
import unittest
import test_wire as wire
from test_wire import ROOT, blob, integer, envelope, private, group

class WireEvent(ctypes.Structure):
    _fields_=[('sequence',ctypes.c_uint64),('group',ctypes.c_uint64),('random',ctypes.c_uint64),('time',ctypes.c_uint64),
              ('kind',ctypes.c_uint),('hasRandom',ctypes.c_uint),('hasTime',ctypes.c_uint),
              ('from_uid',ctypes.c_char*129),('to_uid',ctypes.c_char*129),('author',ctypes.c_char*129)]

def group_events(messages):
    notify=integer(1,7)+integer(4,6789)+blob(11,b''.join(blob(3,m) for m in messages))
    return envelope(732,17,b'\0\0\x1a\x85\0'+len(notify).to_bytes(2,'big')+notify)

def message(seq=123,author=b'author_uid'):
    return integer(1,seq)+integer(2,1784001234)+integer(3,0xf0010011)+blob(6,author)

class EventTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        wire.WireTests.setUpClass()
        cls.library=wire.WireTests.library
        cls.extract=cls.library.timantirecall_extractRecallEvents
        cls.extract.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.POINTER(WireEvent),ctypes.c_size_t]
        cls.extract.restype=ctypes.c_size_t
    @classmethod
    def tearDownClass(cls): wire.WireTests.tearDownClass()
    def events(self,data,capacity=64):
        buffer=ctypes.create_string_buffer(data);out=(WireEvent*64)()
        n=self.extract(buffer,len(data),out,capacity)
        return list(out[:n])
    def test_private_identity_preserves_large_sequence_and_exact_participants(self):
        for seq in (1,0xffffffff,0x123456789):
            packet=envelope(528,138,blob(1,blob(1,b'from_uid')+blob(2,b'to_uid')+integer(20,seq)))
            rows=self.events(packet);self.assertEqual(len(rows),1)
            e=rows[0];self.assertEqual((e.sequence,e.kind,e.from_uid,e.to_uid),(seq,1,b'from_uid',b'to_uid'))
    def test_group_batch_keeps_each_author_time_random(self):
        rows=self.events(group_events([message(123),message(124,b'other_author')]))
        self.assertEqual([e.sequence for e in rows],[123,124])
        self.assertEqual([e.author for e in rows],[b'author_uid',b'other_author'])
        self.assertTrue(all(e.kind==2 and e.group==6789 and e.time==1784001234 and e.random==0xf0010011 for e in rows))
    def test_private_invalid_uid_does_not_change_block_decision(self):
        for value in (b'a\0b',b'a\nb',b'abc/def',b'a'*129):
            data=envelope(528,138,blob(1,blob(1,value)+blob(2,b'peer')+integer(20,1)))
            self.assertEqual(self.events(data),[])
    def test_group_missing_author_is_unmarked_but_still_intercepted(self):
        self.assertEqual(wire.WireTests.result(wire.WireTests(),group()),2)
        self.assertEqual(self.events(group()),[])
    def test_ambiguous_author_or_optional_field_rejected(self):
        for suffix in (blob(6,b'other'),integer(3,55),blob(2,b'wrong'),b'\x80'):
            self.assertEqual(self.events(group_events([message()+suffix])),[])
        self.assertEqual(self.events(group_events([message(),integer(1,124)])),[])
    def test_capacity_never_yields_partial_mark_batch(self):
        self.assertEqual(self.events(group_events([message(),message(124)]),capacity=1),[])
        self.assertEqual(self.events(private(),capacity=0),[])
        self.assertEqual(self.extract(None,0,None,64),0)
    def test_all_truncation_prefixes_are_unmarked(self):
        for data in (private(),group_events([message(),message(124)])):
            for n in range(len(data)): self.assertEqual(self.events(data[:n]),[])
    def test_classifier_baseline_is_byte_frozen(self):
        import hashlib
        source=(ROOT/'Sources/TIMAntiRecallWire.m').read_bytes()
        original=source.split(b'\nstatic bool timantirecall_copyUID')[0]
        self.assertEqual(hashlib.sha256(original).hexdigest(),'8d04160c7071b59c38764dd9bccf9f107cbe03005b1e5fabd65b87c4837abea7')

if __name__=='__main__':unittest.main()
