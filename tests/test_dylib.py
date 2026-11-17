"""Verifier negatives and synthetic CodeDirectory tests, not a compiled library."""
import hashlib
import struct
import sys
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from verify_dylib import parse_fat, signature, ValidationError
from build_contract import version_for_run, version_tuple

def signed_fixture():
    code=b'fixture code bytes, not executable instructions'
    identifier=b'fixture\0'
    offset=44+len(identifier)
    cd=struct.pack('>9I4BI',0xfade0c02,offset+32,0x20000,2,offset,44,0,1,len(code),32,2,0,12,0)+identifier+hashlib.sha256(code).digest()
    superblob=struct.pack('>5I',0xfade0cc0,20+len(cd),1,0,20)+cd
    return code+superblob,len(code),len(superblob)

class DylibTests(unittest.TestCase):
    def test_real_page_hash_implementation(self):
        data,off,size=signed_fixture()
        result=signature(data,off,size)
        self.assertEqual(result['code_directories'][0]['pages_verified'],1)
        self.assertFalse(result['cms_trust_verified'])

    def test_changed_code_page_rejected(self):
        data,off,size=signed_fixture()
        with self.assertRaisesRegex(ValidationError,'hash mismatch'):
            signature(b'X'+data[1:],off,size)

    def test_signature_bounds_and_truncation(self):
        data,off,size=signed_fixture()
        for candidate,offset,length in ((data[:-1],off,size),(data,0,size),(data,off,5)):
            with self.assertRaises(ValidationError): signature(candidate,offset,length)

    def test_missing_or_nonfat_architecture_rejected(self):
        for data in (b'',b'\xcf\xfa\xed\xfe'+b'\0'*64,b'\xca\xfe\xba\xbe'+struct.pack('>I',0),
                     b'\xca\xfe\xba\xbe'+struct.pack('>I',1)+b'\0'*20):
            with self.assertRaises(ValidationError): parse_fat(data)

    def test_out_of_range_fat_slice_rejected(self):
        header=struct.pack('>II',0xcafebabe,2)
        rows=struct.pack('>5I',0x100000c,0,4096,100,12)+struct.pack('>5I',0x100000c,2,8192,100,12)
        with self.assertRaisesRegex(ValidationError,'bounds'): parse_fat(header+rows)

    def test_version_sequence_and_bad_versions(self):
        for number,version in ((1,'0.10'),(9,'0.90'),(10,'1.00'),(11,'1.10')):
            self.assertEqual(version_for_run(number),version)
            version_tuple(version)
        for version in ('0.1','0.11','latest','1.001'):
            with self.assertRaises(ValueError): version_tuple(version)

if __name__=='__main__': unittest.main()
