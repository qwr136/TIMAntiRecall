"""Exercise the production POSIX bootstrap writer, not a reimplemented mock."""
import ctypes
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]

class BootstrapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp=tempfile.TemporaryDirectory()
        compiler=shutil.which('cc') or shutil.which('clang')
        if not compiler: raise RuntimeError('C compiler required')
        output=Path(cls.temp.name)/'bootstrap.so'
        subprocess.run([compiler,'-x','c','-std=c11','-D_POSIX_C_SOURCE=200809L',
            '-DTIMANTIRECALL_NATIVE_TEST=1','-O2','-Wall','-Wextra','-Werror','-shared','-fPIC',
            '-I'+str(ROOT/'Headers'),str(ROOT/'Sources/TIMAntiRecallBootstrap.m'),'-o',str(output)],check=True)
        cls.lib=ctypes.CDLL(str(output))
        cls.write=cls.lib.timantirecall_bootstrapWrite
        cls.write.argtypes=[ctypes.c_char_p,ctypes.c_char_p,ctypes.c_char_p]
        cls.write.restype=ctypes.c_bool
        cls.safe=cls.lib.timantirecall_bootstrapSafeValue
        cls.safe.argtypes=[ctypes.c_char_p,ctypes.c_void_p,ctypes.c_size_t]
    @classmethod
    def tearDownClass(cls): cls.temp.cleanup()
    def setUp(self):
        self.folder=tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.home=Path(self.folder.name)/'home'; self.home.mkdir()
        self.tmp=Path(self.folder.name)/'tmp'; self.tmp.mkdir()
        self.log=self.home/'Documents/TIMAntiRecall/TIMAntiRecall-bootstrap.log'
    def emit(self,event=b'constructor-enter'):
        return self.write(os.fsencode(self.home),os.fsencode(self.tmp),event)
    def test_first_event_is_synchronous_before_identity(self):
        self.assertTrue(self.emit())
        self.assertIn('constructor-enter',self.log.read_text())
        self.assertNotIn(str(self.home),self.log.read_text())
        self.assertEqual(self.log.stat().st_mode&0o777,0o600)
    def test_append_preserves_prior_evidence(self):
        self.assertTrue(self.emit(b'first')); self.assertTrue(self.emit(b'second'))
        text=self.log.read_text(); self.assertLess(text.index('first'),text.index('second'))
    def test_missing_home_falls_back_only_to_provided_tmp(self):
        self.assertTrue(self.write(None,os.fsencode(self.tmp),b'constructor-enter'))
        self.assertIn('constructor-enter',(self.tmp/'TIMAntiRecall-bootstrap.log').read_text())
        self.assertFalse(self.write(None,None,b'no-global-tmp'))
    def test_file_at_documents_triggers_tmp_fallback(self):
        (self.home/'Documents').write_bytes(b'keep')
        self.assertTrue(self.emit())
        self.assertEqual((self.home/'Documents').read_bytes(),b'keep')
        self.assertTrue((self.tmp/'TIMAntiRecall-bootstrap.log').is_file())
    def test_symlink_log_does_not_overwrite_target(self):
        self.log.parent.mkdir(parents=True)
        target=self.home/'keep'; target.write_bytes(b'unchanged')
        self.log.symlink_to(target)
        self.assertTrue(self.emit())
        self.assertEqual(target.read_bytes(),b'unchanged')
        self.assertTrue((self.tmp/'TIMAntiRecall-bootstrap.log').is_file())
    def test_symlink_documents_is_not_followed(self):
        target=self.home/'elsewhere';target.mkdir()
        (self.home/'Documents').symlink_to(target)
        self.assertTrue(self.emit())
        self.assertFalse((target/'TIMAntiRecall').exists())
    def test_limit_keeps_existing_log_and_falls_back(self):
        self.log.parent.mkdir(parents=True); self.log.write_bytes(b'x'*(128*1024+1))
        old=self.log.read_bytes()
        self.assertTrue(self.emit())
        self.assertEqual(self.log.read_bytes(),old)
        self.assertTrue((self.tmp/'TIMAntiRecall-bootstrap.log').exists())
    def test_unsafe_characters_and_line_injection_are_removed(self):
        self.assertTrue(self.emit(b'field=one\nforged/secret\\tail'))
        lines=self.log.read_text().splitlines()
        self.assertEqual(len(lines),1)
        self.assertIn('field=one_forged_secret_tail',lines[0])
    def test_sanitizer_is_bounded_and_null_safe(self):
        output=ctypes.create_string_buffer(8)
        self.safe(b'123456789',output,len(output)); self.assertEqual(output.value,b'1234567')
        self.safe(None,output,len(output)); self.assertEqual(output.value,b'missing')
        self.safe(b'x',None,0)
if __name__=='__main__': unittest.main()
