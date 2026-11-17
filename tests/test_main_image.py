"""Regression for main-executable selection and genuinely executed image0 test wiring."""
import importlib.util
import tempfile
import shutil
import unittest
from pathlib import Path
from source_checks import check_sources,function_body,mask_literals
ROOT=Path(__file__).resolve().parents[1]

class MainImageTests(unittest.TestCase):
    def test_main_uuid_uses_executable_api_not_image_zero(self):
        main=(ROOT/'Hooks/TIMAntiRecallMain.m').read_text()
        body=mask_literals(function_body(main,'timantirecall_mainUUID'))
        self.assertIn('_NSGetMachExecuteHeader()',body)
        self.assertNotIn('_dyld_get_image_header',body)

    def test_reverting_to_image_zero_is_rejected(self):
        with tempfile.TemporaryDirectory() as work:
            root=Path(work)
            for folder in ('Sources','Headers','Hooks'):shutil.copytree(ROOT/folder,root/folder)
            main=root/'Hooks/TIMAntiRecallMain.m'
            main.write_text(main.read_text().replace('_NSGetMachExecuteHeader()','_dyld_get_image_header(0)'))
            errors=check_sources(root,{})
            self.assertTrue(any('main UUID' in error for error in errors),errors)

    def test_runtime_tests_reject_dylib_even_with_correct_uuid(self):
        text=(ROOT/'tests/native/TIMAntiRecallRuntimeTests.m').read_text()
        self.assertIn('timantirecall_imageHeader(MH_DYLIB',text)
        self.assertIn('image0Dylib.bytes)==nil',text)
        self.assertIn('duplicate.bytes)==nil',text)
        self.assertIn('malformed.bytes)==nil',text)

    def test_real_inserted_dylib_case_is_wired_to_native_runner(self):
        text=(ROOT/'scripts/run_native_tests.py').read_text()
        self.assertIn('for inserted in (False,True):',text)
        self.assertIn("environment['DYLD_INSERT_LIBRARIES']=str(preload)",text)
        self.assertIn("environment['TIMANTIRECALL_REQUIRE_INSERTED_FIRST']='1'",text)
        self.assertIn("'-dynamiclib'",text)
        self.assertTrue((ROOT/'tests/native/TIMAntiRecallPreloadFixture.c').is_file())

if __name__=='__main__':unittest.main()
