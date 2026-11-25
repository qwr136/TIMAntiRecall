import re
import sys
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
from source_checks import strip_comments

class BottomBarGlassTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source=strip_comments((ROOT/'Sources/TIMAntiRecallBottomBarGlass.m').read_text())
        cls.main=strip_comments((ROOT/'Hooks/TIMAntiRecallMain.m').read_text())
        cls.driver=strip_comments((ROOT/'tests/ui/run_inline_ui_tests.py').read_text())
        cls.ui=strip_comments((ROOT/'tests/ui/TIMAntiRecallInlineUIKitTests.m').read_text())

    def test_production_and_real_uikit_fixture_are_compiled(self):
        self.assertIn('Sources/TIMAntiRecallBottomBarGlass.m',self.driver)
        self.assertIn('TIMAntiRecallBottomBarGlassFixture.m',self.driver)
        self.assertIn('bottom-bar-liquid-glass',self.driver)
        self.assertIn('timantirecall_testBottomBarGlassCases(root)',self.ui)

    def test_hook_targets_only_the_verified_main_bar(self):
        self.assertIn('objc_getClass("QQSkinTabBar")',self.source)
        self.assertIn('object_getClass(bar)!=barClass',self.source)
        self.assertIn('timantirecall_bottomBarRootView(controller)!=bar',self.source)
        self.assertIn('class_getClassMethod(cls,selector)',self.source)
        self.assertIn('timantirecall_methodTypes(layout,"v",2,layoutArgs)',self.source)
        self.assertIn('timantirecall_methodTypes(select,"v",3,selectArgs)',self.source)

    def test_private_item_index_has_exact_integer_abi_guard(self):
        self.assertIn('"iShowingIndex","q"',self.source)
        self.assertIn('timantirecall_methodTypes(method,encoding,2,args)',self.source)
        self.assertIn('timantirecall_methodTypes(method,"Q",2,args)',self.source)

    def test_original_layout_and_selection_are_forwarded_once(self):
        layout=re.search(r'static void timantirecall_bottomBarLayout\([^)]*\) \{(.*?)\n\}',self.source,re.S).group(1)
        selected=re.search(r'static void timantirecall_bottomBarSelected\([^)]*\) \{(.*?)\n\}',self.source,re.S).group(1)
        self.assertLess(layout.index('timantirecall_bottomBarOriginalLayout'),layout.index('timantirecall_bottomBarApply'))
        self.assertLess(selected.index('timantirecall_bottomBarOriginalSelect'),selected.index('timantirecall_bottomBarApply'))
        self.assertIn('userInteractionEnabled=NO',self.source)

    def test_material_and_selected_lens_are_independent(self):
        self.assertIn('UIVisualEffectView',self.source)
        self.assertIn('UIBlurEffectStyleSystemUltraThinMaterialDark',self.source)
        self.assertIn('UIBlurEffectStyleSystemUltraThinMaterialLight',self.source)
        self.assertIn('timantirecall_layoutGlass:pill selectedLens:lens animate:animate',self.source)
        self.assertIn('UIAccessibility isReduceMotionEnabled',self.source)
        self.assertIn('UIAccessibilityReduceMotionStatusDidChangeNotification',self.source)
        self.assertIn('removeAnimationForKey:@"timantirecall_sweep"',self.source)
        self.assertNotIn('bar.backgroundColor=',self.source)
        self.assertIn('timantirecall_testBottomBarGlassLensFrame',self.source)

    def test_native_foundation_target_excludes_uikit_translation_unit(self):
        self.assertLess(self.source.index('#if defined(TIMANTIRECALL_NATIVE_TEST)'),self.source.index('#import <UIKit/UIKit.h>'))
        self.assertIn('TIMAntiRecallBottomBarGlassNativeTestTranslationUnit',self.source)

    def test_hook_retries_without_blocking_existing_installations(self):
        self.assertIn('BOOL glass=timantirecall_installBottomBarGlass()',self.main)
        self.assertIn('dispatch_after',self.main)
        self.assertIn('timantirecall_attemptUIInstall(attempt+1)',self.main)

if __name__=='__main__': unittest.main()
