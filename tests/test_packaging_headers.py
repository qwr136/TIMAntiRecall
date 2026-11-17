import importlib.util
from pathlib import Path
import struct
import unittest

PROJECT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('locked_packaging',PROJECT/'scripts/locked_packaging.py')
gate=importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

class PackagingHeaderTests(unittest.TestCase):
    def test_java_class_is_not_macho(self):
        self.assertFalse(gate.is_macho_header(bytes.fromhex('cafebabe00000034'),1024))
    def test_real_fat_header_is_macho(self):
        self.assertTrue(gate.is_macho_header(bytes.fromhex('cafebabe')+struct.pack('>I',2),4096))
    def test_thin_arm64_is_macho(self):
        self.assertTrue(gate.is_macho_header(bytes.fromhex('cffaedfe0c000001'),256))
    def test_truncated_or_empty_fat_is_not_macho(self):
        self.assertFalse(gate.is_macho_header(bytes.fromhex('cafebabe00000002'),16))
        self.assertFalse(gate.is_macho_header(bytes.fromhex('cafebabe00000000'),4096))

if __name__=='__main__': unittest.main()
