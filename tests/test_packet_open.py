"""Delivery log policy and native-open safety contracts (UIKit runs in CI)."""
import ctypes
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]

class PacketOpenTests(unittest.TestCase):
    def test_default_bootstrap_binary_never_writes_legacy_logs(self):
        compiler=shutil.which('cc') or shutil.which('clang')
        self.assertIsNotNone(compiler)
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);output=root/'silent.so'
            macro='-D_DARWIN_C_SOURCE' if sys.platform=='darwin' else '-D_POSIX_C_SOURCE=200809L'
            subprocess.run([compiler,'-x','c','-std=c11',macro,'-O2','-Wall','-Wextra','-Werror',
                '-shared','-fPIC','-I'+str(ROOT/'Headers'),str(ROOT/'Sources/TIMAntiRecallBootstrap.m'),'-o',str(output)],check=True)
            lib=ctypes.CDLL(str(output))
            write=lib.timantirecall_bootstrapWrite;write.argtypes=[ctypes.c_char_p]*3;write.restype=ctypes.c_bool
            emit=lib.timantirecall_bootstrapEvent;emit.argtypes=[ctypes.c_char_p];emit.restype=ctypes.c_bool
            before=set(root.iterdir())
            self.assertFalse(write(str(root).encode(),str(root).encode(),b'no-legacy-write'))
            self.assertFalse(emit(b'constructor-enter'))
            self.assertEqual(set(root.iterdir()),before)
            self.assertNotIn(b'TIMAntiRecall-bootstrap.log',output.read_bytes())

    def test_general_runtime_sink_has_no_file_writer(self):
        code=(ROOT/'Sources/TIMAntiRecallDiagnostics.m').read_text()
        self.assertIn('(void)event;',code)
        for token in ('fileHandleForWriting','writeToFile','writeToURL','createDirectory','TIMAntiRecall.log','syslog('):
            self.assertNotIn(token,code)

    def test_open_uses_registered_native_control_action_not_private_guess_or_tap(self):
        source=(ROOT/'Sources/TIMAntiRecallPacketOpen.m').read_text()
        for token in ('actionsForTarget:','UIControlEventTouchUpInside','timantirecall_methodTypes',
                      'class_getImageName','timantirecall_openLabel','timantirecall_before','bindings!=1',
                      'candidate sendActionsForControlEvents','context.timantirecall_valid()', 'timantirecall_controlAction'):
            self.assertIn(token,source)
        for token in ('performSelector:','objc_msgSend','grabRedBag:', 'IOHIDEvent','authkey','valueForKey:'):
            self.assertNotIn(token,source)

    def test_open_is_armed_only_after_route_gates(self):
        source=(ROOT/'Sources/TIMAntiRecallPacket.m').read_text()
        start=source.index('static BOOL timantirecall_packetAttempt')
        body=source[start:source.index('static BOOL timantirecall_packetObserve',start)]
        self.assertLess(body.index('timantirecall_packetReserve('),body.index('timantirecall_beginPacketOpen('))
        self.assertIn('timantirecall_packetStillActive(owner,epoch)',body)
        self.assertIn('timantirecall_autoClaimRedPackets',body)

    def test_real_uikit_open_and_negative_controls_are_required(self):
        driver=(ROOT/'tests/ui/run_inline_ui_tests.py').read_text()
        self.assertIn('Sources/TIMAntiRecallPacketOpen.m',driver)
        self.assertIn('packet-open-action',driver)
        self.assertIn('packet-open-guards',driver)
        cases=(ROOT/'tests/ui/TIMAntiRecallPacketOpenCases.h').read_text()
        for token in ('pre-existing open or payment','stale account/foreground/setting','ambiguous multiple','manual action forwards exactly once'):
            self.assertIn(token,cases)

if __name__=='__main__':unittest.main()
