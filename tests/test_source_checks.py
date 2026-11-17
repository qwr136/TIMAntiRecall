"""Regression tests for the source gates, including the comment-only failure."""
import unittest
from source_checks import dependency_names, function_body, strip_comments


class SourceCheckerTests(unittest.TestCase):
    def test_comments_removed_but_literals_preserved(self):
        text = 'int active; // fake()\n/* another\n fake */ @"https://x/*y*/";'
        actual = strip_comments(text)
        self.assertIn('int active;', actual)
        self.assertNotIn('fake', actual)
        self.assertIn('@"https://x/*y*/"', actual)
        self.assertEqual(actual.count('\n'), text.count('\n'))

    def test_only_a_definition_yields_a_body(self):
        self.assertIsNone(function_body('// void named() {}\nvoid named();', 'named'))
        self.assertIsNone(function_body('void outer() { named(); }', 'named'))
        self.assertEqual(function_body('void named() { return @"}"; }', 'named').strip(), 'return @"}";')
        self.assertIsNone(function_body('void named() {', 'named'))

    def test_dependencies_match_package_names(self):
        names = dependency_names('mobilesubstrate (>= 0.9), roothide, preferenceloader')
        self.assertEqual(names, {'mobilesubstrate', 'roothide', 'preferenceloader'})
        self.assertNotIn('roothide', dependency_names('not-roothide, not-mobilesubstrate'))
        self.assertNotIn('mobilesubstrate', dependency_names('mobilesubstrate | unrelated'))
        self.assertIn('roothide', dependency_names('roothide (>= 1) | roothide (>= 2)'))
        with self.assertRaises(ValueError):
            dependency_names('roothide, ')

    def test_active_installer_and_constructor_required(self):
        import tempfile, shutil
        from pathlib import Path
        from source_checks import check_sources
        project = Path(__file__).resolve().parents[1]
        meta = {'class_prefix':'TIMAntiRecall','symbol_prefix':'timantirecall','package':'com.minis.timantirecall'}
        with tempfile.TemporaryDirectory() as work:
            root=Path(work)
            for folder in ('Sources','Headers','Hooks'): shutil.copytree(project/folder,root/folder)
            self.assertEqual(check_sources(root,meta),[])
            runtime=root/'Sources/TIMAntiRecallRuntime.m'
            good=runtime.read_text()
            runtime.write_text('// '+good.replace('\n','\n// '))
            self.assertTrue(check_sources(root,meta))
            runtime.write_text(good)
            main=root/'Hooks/TIMAntiRecallMain.m'
            main.write_text(main.read_text().replace('timantirecall_initialize','removed_initialize'))
            self.assertTrue(check_sources(root,meta))

    def legacy_path_and_hook_fixture(self):
        import tempfile
        from pathlib import Path
        from source_checks import check_sources
        meta = {'class_prefix': 'Probe', 'symbol_prefix': 'probe_one',
                'package': 'com.example.one', 'bundle': 'com.apple.springboard'}
        with tempfile.TemporaryDirectory() as work:
            project = Path(work)
            (project/'Sources').mkdir()
            (project/'Hooks').mkdir()
            paths = project/'Sources/ProbePaths.h'
            hook = project/'Hooks/ProbeMain.xm'
            paths.write_text('static NSString *probe_one_preferencesPath(void) {\n'
                             'return @"/var/mobile/Library/Preferences/com.example.one.plist"; }')
            valid_hook = ('#import "ProbePreferences.h"\n%hook SpringBoard\n'
                          '- (void)run { if ([self probe_one_isEnabled]) {} }\n%end\n'
                          'void observe() { [center addObserverForName:ProbePreferencesChanged object:nil]; }')
            hook.write_text(valid_hook)
            self.assertEqual(check_sources(project, meta), [])
            hook.write_text('// ' + valid_hook.replace('\n', '\n// '))
            self.assertTrue(check_sources(project, meta), 'Comment-only hooks must fail')
            hook.write_text('#import "ProbePreferences.h"\nconst char *fake = "%hook SpringBoard probe_one_isEnabled addObserverForName:ProbePreferencesChanged";')
            self.assertTrue(check_sources(project, meta), 'String literals must not impersonate hooks')
            hook.write_text(valid_hook)
            good_path = paths.read_text()
            paths.write_text(good_path.replace('return @"', 'return jbroot(@"').replace('.plist";', '.plist");'))
            self.assertTrue(check_sources(project, meta), 'A jbroot preference path must fail')
            paths.write_text(good_path.replace('com.example.one', 'com.example.other'))
            self.assertTrue(check_sources(project, meta), 'Another preference domain must fail')
            paths.write_text(good_path)
            self.assertTrue(check_sources(project, dict(meta, bundle='com.example.app')))

    def legacy_build_configuration_fixture(self):
        import tempfile
        from pathlib import Path
        from source_checks import check_sources
        meta = {'class_prefix': 'Probe', 'symbol_prefix': 'probe_one',
                'package': 'com.example.one', 'bundle': 'com.apple.springboard',
                'scheme': 'rootless', 'github_actions': True}
        with tempfile.TemporaryDirectory() as work:
            project = Path(work)
            (project/'Sources').mkdir()
            (project/'Hooks').mkdir()
            (project/'.github/workflows').mkdir(parents=True)
            (project/'Sources/ProbePaths.h').write_text(
                'NSString *probe_one_preferencesPath(void) { return @"/var/mobile/Library/Preferences/com.example.one.plist"; }')
            (project/'Hooks/ProbeMain.xm').write_text(
                '#import "ProbePreferences.h"\n%hook SpringBoard\n'
                '- (void)run { if ([self probe_one_isEnabled]) {} }\n%end\n'
                'void observe() { [center addObserverForName:ProbePreferencesChanged object:nil]; }')
            build = project/'build.sh'
            workflow = project/'.github/workflows/build.yml'
            build.write_text('DEFAULT_SCHEME=rootless\n')
            good_ci = ('matrix:\n  - build_variant: rootless\n'
                       'run: python3 tests/verify_deb.py --project . --scheme rootless --expected-version 0.10 a.deb\n')
            workflow.write_text(good_ci)
            self.assertEqual(check_sources(project, meta), [])
            build.write_text('DEFAULT_SCHEME=roothide\n')
            self.assertTrue(check_sources(project, meta))
            build.write_text('DEFAULT_SCHEME=rootless\n')
            workflow.write_text(good_ci.replace('build_variant: rootless', 'build_variant: roothide'))
            self.assertTrue(check_sources(project, meta))
            workflow.write_text(good_ci.replace('--expected-version', '--ignored-option'))
            self.assertTrue(check_sources(project, meta))


if __name__ == '__main__':
    unittest.main()
