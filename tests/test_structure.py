"""Standalone artifact/build identity checks; no Debian or Preferences assumptions."""
import importlib.util
import json
import plistlib
import re
import sys
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from build_contract import validate

class StructureTests(unittest.TestCase):
    def test_standalone_build_contract(self):
        self.assertEqual(validate(ROOT)['package'],'com.minis.timantirecall')

    def test_required_product_inputs(self):
        required=['Headers/TIMAntiRecallRuntime.h','Headers/TIMAntiRecallWire.h',
            'Sources/TIMAntiRecallRuntime.m','Sources/TIMAntiRecallWire.m',
            'Sources/TIMAntiRecallDiagnostics.m','Hooks/TIMAntiRecallMain.m',
            'tests/native/TIMAntiRecallRuntimeTests.m']
        for name in required: self.assertTrue((ROOT/name).is_file(),name)

    def test_namespaced_product_sources(self):
        for folder in ('Sources','Headers','Hooks'):
            for path in (ROOT/folder).iterdir():
                self.assertTrue(path.stem.startswith('TIMAntiRecall'),path.name)

    def test_target_filter_metadata(self):
        data=plistlib.loads((ROOT/'TIMAntiRecall.plist').read_bytes())
        self.assertEqual(data['Filter']['Bundles'],['com.tencent.tim'])

    def test_no_original_app_or_secret_in_project(self):
        for path in ROOT.rglob('*'):
            if any(p in {'.git','.theos','__pycache__','dist','reports'} for p in path.parts): continue
            self.assertNotIn(path.suffix.lower(),{'.ipa','.p12','.mobileprovision','.key'},str(path))
            self.assertNotEqual(path.name,'TIMAutoRevoke31.dylib')

if __name__=='__main__': unittest.main()
