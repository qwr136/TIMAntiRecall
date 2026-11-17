import ctypes
import importlib.util
import random
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def varint(value):
    output=bytearray()
    while value>127:
        output.append((value&127)|128); value >>= 7
    output.append(value)
    return bytes(output)

def integer(field,value): return varint(field<<3)+varint(value)
def blob(field,value): return varint((field<<3)|2)+varint(len(value))+value

def envelope(kind,subtype,content):
    return blob(1,blob(2,integer(1,kind)+integer(2,subtype))+blob(3,blob(2,content)))

def private(subtype=138):
    return envelope(528,subtype,blob(1,blob(1,b'u_sender')+blob(2,b'u_peer')+integer(20,123456)))

def group(subtype=17,notify_type=7,sequence=42,length_delta=0):
    notify=integer(1,notify_type)+integer(4,9)+blob(11,blob(3,integer(1,sequence)))
    prefix=b'\x00\x00\x00\x09\x00'+(len(notify)+length_delta).to_bytes(2,'big')
    return envelope(732,subtype,prefix+notify)

class WireTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        compiler=shutil.which('cc') or shutil.which('clang')
        if not compiler: raise RuntimeError('native C compiler required for production wire regression')
        cls.temp=tempfile.TemporaryDirectory()
        output=Path(cls.temp.name)/'wire.so'
        subprocess.run([compiler,'-x','c','-std=c11','-O2','-Wall','-Wextra','-Werror','-shared','-fPIC',
            '-I'+str(ROOT/'Headers'),str(ROOT/'Sources/TIMAntiRecallWire.m'),'-o',str(output)],check=True)
        cls.library=ctypes.CDLL(str(output))
        cls.classify=cls.library.timantirecall_classifyPush
        cls.classify.argtypes=[ctypes.c_void_p,ctypes.c_size_t]
        cls.classify.restype=ctypes.c_int

    @classmethod
    def tearDownClass(cls): cls.temp.cleanup()

    def result(self,data):
        buffer=ctypes.create_string_buffer(data)
        return self.classify(buffer,len(data))

    def test_private_both_exact_subtypes(self):
        self.assertEqual(self.result(private(138)),1)
        self.assertEqual(self.result(private(139)),1)

    def test_group_both_exact_subtypes(self):
        self.assertEqual(self.result(group(16)),2)
        self.assertEqual(self.result(group(17)),2)

    def test_unrelated_system_messages_forward(self):
        for subtype in (0,15,18,21,321,343): self.assertEqual(self.result(group(subtype)),0)
        for kind in (0,82,166,529,731,733):
            self.assertEqual(self.result(envelope(kind,138,blob(1,integer(20,42)))),0)
        for notify in (0,1,6,8): self.assertEqual(self.result(group(notify_type=notify)),0)

    def test_require_structured_nonzero_target(self):
        self.assertEqual(self.result(group(sequence=0)),0)
        self.assertEqual(self.result(envelope(528,138,b'not protobuf')),0)
        self.assertEqual(self.result(envelope(528,138,blob(1,integer(20,42)))),0)
        self.assertEqual(self.result(envelope(732,17,b'\0'*7)),0)

    def test_group_declared_length_must_match(self):
        self.assertEqual(self.result(group(length_delta=1)),0)
        self.assertEqual(self.result(group(length_delta=-1)),0)

    def test_invalid_group_identity_always_forwards(self):
        for identity in (b'',integer(4,0),blob(4,b'9'),integer(4,9)+integer(4,9)):
            notify=integer(1,7)+identity+blob(11,blob(3,integer(1,42)))
            content=b'\x00\x00\x00\x09\x00'+len(notify).to_bytes(2,'big')+notify
            self.assertEqual(self.result(envelope(732,17,content)),0)

    def test_every_truncated_prefix_forwards(self):
        for data in (private(),private(139),group(),group(16)):
            for length in range(len(data)):
                self.assertEqual(self.result(data[:length]),0,(len(data),length))

    def test_bad_suffix_and_duplicate_fields_forward(self):
        for data in (private(),group()):
            self.assertEqual(self.result(data+b'\x80'),0)
            self.assertEqual(self.result(data+data),0)
            self.assertEqual(self.result(data+b'\0'),0)
        badhead=integer(1,528)+integer(1,528)+integer(2,138)
        msg=blob(2,badhead)+blob(3,blob(2,blob(1,integer(20,42))))
        self.assertEqual(self.result(blob(1,msg)),0)

    def test_unknown_well_formed_field_is_retained(self):
        self.assertEqual(self.result(private()+integer(97,200)),1)
        self.assertEqual(self.result(group()+blob(98,b'unrelated')),2)

    def test_bounds_and_overflow(self):
        self.assertEqual(self.classify(None,0),0)
        self.assertEqual(self.classify(None,2**30),0)
        self.assertEqual(self.result(b'\x0a'+b'\xff'*10),0)
        self.assertEqual(self.result(b'\x0a'+b'\x80'*9+b'\x02'),0)
        self.assertEqual(self.result(private()+integer(99,0)*4096),0)
        self.assertEqual(self.result(b'x'*(2*1024*1024+1)),0)

    def test_deterministic_malformed_fuzz(self):
        generator=random.Random(41081)
        for _ in range(3000):
            data=bytes(generator.getrandbits(8) for _ in range(generator.randrange(0,160)))
            self.assertEqual(self.result(data),0)

if __name__=='__main__': unittest.main()
