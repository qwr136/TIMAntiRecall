"""Delivery policy: reject e/FAT, retain dual-build proof and exact arm64 bytes."""
import hashlib
import json
from pathlib import Path
import shutil
import struct
import sys
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from verify_dylib import validate_bytes,ValidationError
from prepare_delivery import prepare,verify_selection
from macho_fixtures import thin,fat

class Arm64DeliveryTests(unittest.TestCase):
    def test_signed_thin_arm64_is_valid(self):
        result=validate_bytes(thin(),'0.40')
        self.assertEqual(set(result['slices']),{'arm64'})
        self.assertEqual(result['slices']['arm64']['cpu_subtype'],'0x0')
        self.assertEqual(result['slices']['arm64']['initializers'][0]['function_offsets'],[2048])

    def test_universal_is_only_for_internal_verification(self):
        self.assertEqual(set(validate_bytes(fat(),'0.40','universal')['slices']),{'arm64','arm64e'})
        with self.assertRaisesRegex(ValidationError,'thin arm64'):validate_bytes(fat(),'0.40')

    def test_arm64e_delivery_and_relabelled_e_rejected(self):
        with self.assertRaisesRegex(ValidationError,'subtype 0'):validate_bytes(thin(0x80000002),'0.40')
        relabelled=bytearray(thin(0x80000002));struct.pack_into('<I',relabelled,8,0)
        with self.assertRaisesRegex(ValidationError,'hash mismatch'):validate_bytes(bytes(relabelled),'0.40')

    def test_old_version_and_missing_initializer_rejected(self):
        with self.assertRaisesRegex(ValidationError,'current_version'):validate_bytes(thin(version='0.30'),'0.40')
        for data in (thin(init=False),thin(init_value=0xffffffff)):
            with self.assertRaisesRegex(ValidationError,'constructor'):validate_bytes(data,'0.40')

    def test_delivery_is_exact_arm64_bytes_and_seal_rejects_swaps(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)/'project'
            shutil.copytree(ROOT,root,ignore=shutil.ignore_patterns('.git','.theos','tests','reports','dist','__pycache__'))
            internal=root/'reports/universal/TIMAntiRecall.dylib';internal.parent.mkdir(parents=True)
            internal.write_bytes(fat())
            record=prepare(root,'0.40')
            final=root/'dist/TIMAntiRecall.dylib'
            self.assertEqual(final.read_bytes(),thin())
            self.assertEqual(verify_selection(root,'0.40'),record)
            self.assertEqual(record['artifact']['sha256'],record['internal']['slices']['arm64']['sha256'])
            self.assertEqual(record['artifact']['slices']['arm64']['uuid'],record['internal']['slices']['arm64']['uuid'])
            final.write_bytes(thin(identity='12345678-0000-4000-8000-000000000099'))
            with self.assertRaisesRegex(ValueError,'exact compiled arm64'):verify_selection(root,'0.40')
            final.write_bytes(thin())
            report=root/'reports/delivery-selection.json'
            bad=json.loads(report.read_text());bad['artifact']=bad['internal']
            report.write_text(json.dumps(bad))
            with self.assertRaisesRegex(ValueError,'report differs'):verify_selection(root,'0.40')

    def test_internal_cpu_table_spoofing_rejected(self):
        data=bytearray(fat());struct.pack_into('>I',data,12,2)
        with self.assertRaises(ValidationError):validate_bytes(bytes(data),'0.40','universal')
if __name__=='__main__':unittest.main()
