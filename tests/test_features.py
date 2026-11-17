"""Targeted static source gates; behavior is exercised by native/real C tests."""
import json
import unittest
from pathlib import Path
from source_checks import check_sources
ROOT=Path(__file__).resolve().parents[1]
class CoreFeatureTests(unittest.TestCase):
    def test_runtime_hook_source_contract(self):
        self.assertEqual(check_sources(ROOT,json.loads((ROOT/'tweak.json').read_text())),[])
    def test_wire_native_and_runtime_tests_exist(self):
        self.assertTrue((ROOT/'tests/test_wire.py').is_file())
        self.assertTrue((ROOT/'tests/native/TIMAntiRecallRuntimeTests.m').is_file())
if __name__=='__main__': unittest.main()
