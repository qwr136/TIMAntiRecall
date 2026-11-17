"""A skipped test must not be reported as passed; a failure must fail CI."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class RunnerReportTests(unittest.TestCase):
    def test_distinguishes_pass_failure_and_skip(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copyfile(Path(__file__).with_name('run_tests.py'), root/'run_tests.py')
            (root/'test_sample.py').write_text(
                'import unittest\nclass Sample(unittest.TestCase):\n'
                '    def test_pass(self): self.assertTrue(True)\n'
                '    @unittest.skip("optional")\n'
                '    def test_skip(self): pass\n'
                '    def test_fail(self): self.fail("expected fixture failure")\n')
            result = subprocess.run([sys.executable, str(root/'run_tests.py')],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('总计 3, 通过 1, 失败 1, 跳过 1', result.stdout)
            report = (root/'report.txt').read_text()
            self.assertIn('只代表源码层', report)
            self.assertIn('expected fixture failure', report)


if __name__ == '__main__':
    unittest.main()
