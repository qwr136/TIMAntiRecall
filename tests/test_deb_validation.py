#!/usr/bin/env python3
"""独立坏包回归；不读工程元数据，不需要编译器、ldid 或网络。"""
import contextlib
import gzip
import importlib.util
import io
import json
import lzma
import plistlib
import struct
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("deb_gate", Path(__file__).with_name("verify_deb.py"))
gate = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(gate)
CPU = 0x100000c
PREFIX = "XFProbe"
PACKAGE = "com.example.probe"
BUNDLE = "com.apple.springboard"


def thin(subtype, kind=6, endian="<"):
    # 一段 __TEXT 与 LC_ID_DYLIB；bundle 不含 LC_ID_DYLIB。
    name = b"/Library/Probe.dylib\0"
    size = (24 + len(name) + 7) & ~7
    identity = struct.pack(endian + "6I", 0xd, size, 24, 0, 0x10000, 0x10000) + name
    identity += b"\0" * (size - len(identity))
    commands = 72 + (size if kind == 6 else 0)
    total = 32 + commands
    segment = struct.pack(endian + "II16sQQQQIIII", 0x19, 72, b"__TEXT", 0, total,
                          0, total, 5, 5, 0, 0)
    header = struct.pack(endian + "8I", 0xfeedfacf, CPU, subtype, kind,
                         2 if kind == 6 else 1, commands, 0, 0)
    return header + segment + (identity if kind == 6 else b"")


def fat(kind=6, wide=False, endian=">"):
    step = 32 if wide else 20
    result = bytearray(struct.pack(endian + "II", 0xcafebabf if wide else 0xcafebabe, 2))
    result.extend(b"\0" * (step * 2))
    for index, subtype in enumerate((0, 2)):
        offset = (len(result) + 7) & ~7
        result.extend(b"\0" * (offset - len(result)))
        binary = thin(subtype, kind)
        result.extend(binary)
        row = (CPU, subtype, offset, len(binary), 3) + ((0,) if wide else ())
        struct.pack_into(endian + ("IIQQII" if wide else "IIIII"), result, 8 + index * step, *row)
    return bytes(result)


def tar_blob(files):
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode="w", format=tarfile.USTAR_FORMAT) as tar:
        for name, data in files.items():
            member = tarfile.TarInfo("./" + name)
            member.size = len(data)
            member.mode = 0o755 if name.endswith(".dylib") else 0o644
            tar.addfile(member, io.BytesIO(data))
    return stream.getvalue()


def ar_blob(members):
    result = bytearray(b"!<arch>\n")
    for name, data in members:
        header = f"{name + '/':<16}{0:<12}{0:<6}{0:<6}{'100644':<8}{len(data):<10}`\n".encode("ascii")
        assert len(header) == 60
        result.extend(header + data + (b"\n" if len(data) % 2 else b""))
    return bytes(result)


class DebValidationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "probe.deb"
        self.meta = {"package": PACKAGE, "class_prefix": PREFIX, "bundle": BUNDLE,
                     "scheme": "roothide", "preferences": False}
        self.control = {"Package": PACKAGE, "Version": "1.0", "Architecture": "iphoneos-arm64e",
                        "Depends": "mobilesubstrate, roothide"}
        self.inject = "Library/MobileSubstrate/DynamicLibraries/" + PREFIX
        self.files = {self.inject + ".dylib": fat(),
                      self.inject + ".plist": plistlib.dumps({"Filter": {"Bundles": [BUNDLE]}})}

    def write(self, members=None, compression="gz"):
        encode = {"gz": gzip.compress, "xz": lzma.compress, "": lambda b: b}[compression]
        suffix = "." + compression if compression else ""
        control = "".join(key + ": " + value + "\n" for key, value in self.control.items()).encode()
        if members is None:
            members = [("debian-binary", b"2.0\n"),
                       ("control.tar" + suffix, encode(tar_blob({"control": control}))),
                       ("data.tar" + suffix, encode(tar_blob(self.files)))]
        self.path.write_bytes(ar_blob(members))
        return self.path

    def validate(self, **kwargs):
        kwargs.setdefault("manifest", self.meta)
        with contextlib.redirect_stdout(io.StringIO()):
            return gate.validate_deb(self.path, **kwargs)

    def assert_bad(self, token=None, **kwargs):
        errors = self.validate(**kwargs)
        self.assertTrue(errors, "坏包不应通过")
        if token:
            self.assertIn(token, "\n".join(errors))

    def enable_prefs(self):
        self.meta["preferences"] = True
        self.control["Depends"] += ", preferenceloader"
        base = "Library/PreferenceBundles/" + PREFIX + "Prefs.bundle/"
        self.prefs_base = base
        self.loader = "Library/PreferenceLoader/Preferences/" + PREFIX + "Prefs.plist"
        self.files[self.loader] = plistlib.dumps({"entry": {"bundle": PREFIX + "Prefs",
                                                          "detail": PREFIX + "RootListController"}})
        self.files[base + "Info.plist"] = plistlib.dumps({
            "CFBundleExecutable": PREFIX + "Prefs", "CFBundleIdentifier": PACKAGE + ".preferences",
            "CFBundlePackageType": "BNDL", "NSPrincipalClass": PREFIX + "RootListController"})
        self.files[base + PREFIX + "Prefs"] = fat(kind=8)
        self.files[base + PREFIX + "Root.plist"] = plistlib.dumps({"items": []})

    def test_valid_baseline_schemes_and_layouts(self):
        for scheme, architecture in gate.ARCHITECTURES.items():
            for inject_dir in ("Library/MobileSubstrate/DynamicLibraries/", "Library/TweakInject/"):
                for compression in ("", "gz", "xz"):
                    with self.subTest(scheme=scheme, inject=inject_dir, compression=compression):
                        self.meta["scheme"] = scheme
                        self.control["Architecture"] = architecture
                        self.control["Depends"] = "mobilesubstrate" + (", roothide" if scheme == "roothide" else "")
                        base = ("var/jb/" if scheme == "rootless" else "") + inject_dir + PREFIX
                        self.files = {base + ".dylib": fat(), base + ".plist": plistlib.dumps({"Filter": {"Bundles": [BUNDLE]}})}
                        self.write(compression=compression)
                        self.assertEqual(self.validate(), [])
                        self.assertEqual(self.validate(manifest=None), [])

    def test_valid_fat_variants(self):
        for wide in (False, True):
            for endian in (">", "<"):
                with self.subTest(wide=wide, endian=endian):
                    self.files[self.inject + ".dylib"] = fat(wide=wide, endian=endian)
                    self.write()
                    self.assertEqual(self.validate(), [])

    def test_valid_preferences(self):
        self.enable_prefs()
        self.write()
        self.assertEqual(self.validate(), [])
        self.assertEqual(self.validate(manifest=None), [])

    def test_wrong_metadata(self):
        for key, bad, token in (("Package", "com.other.probe", "Package"), ("Version", "2.0", "Version"),
                                ("Architecture", "iphoneos-arm64", "Architecture")):
            with self.subTest(key=key):
                original = self.control[key]
                self.control[key] = bad
                self.write()
                self.assert_bad(token, expected_version="1.0")
                self.control[key] = original
        self.write()
        self.assert_bad("scheme", scheme="rootful")

    def test_missing_and_spoofed_dependencies(self):
        for depends in ("mobilesubstrate", "not-mobilesubstrate, roothide", "mobilesubstrate | other, roothide",
                        "mobilesubstrate, not-roothide", "mobilesubstrate, roothide | other",
                        "mobilesubstrate:amd64, roothide", ""):
            with self.subTest(depends=depends):
                self.control["Depends"] = depends
                self.write()
                self.assert_bad("依赖")
        self.control["Depends"] = "mobilesubstrate (>= 0.9), roothide (>= 1.0)"
        self.write()
        self.assertEqual(self.validate(), [])

    def test_manifestless_still_checks_architecture_scheme(self):
        self.control["Architecture"] = "amd64"
        self.write()
        self.assert_bad("Architecture", manifest=None)
        self.control["Architecture"] = "iphoneos-arm64e"
        self.control["Depends"] = "mobilesubstrate"
        self.write()
        self.assert_bad("roothide", manifest=None)

    def test_wrong_layout(self):
        self.files = {"var/jb/" + name: blob for name, blob in self.files.items()}
        self.write()
        self.assert_bad("布局")

    def test_missing_dylib(self):
        del self.files[self.inject + ".dylib"]
        self.write()
        self.assert_bad("dylib")

    def test_filters_reject_missing_wrong_or_corrupt(self):
        name = self.inject + ".plist"
        for value in (None, b"bad plist", plistlib.dumps({}), plistlib.dumps({"Filter": []}),
                      plistlib.dumps({"Filter": {"Bundles": ["com.other.app"]}}),
                      plistlib.dumps({"Filter": {"Bundles": []}}),
                      plistlib.dumps({"Filter": {"Executables": ["SpringBoard"]}}),
                      plistlib.dumps({"Filter": {}})):
            with self.subTest(value=value):
                if value is None:
                    self.files.pop(name, None)
                else:
                    self.files[name] = value
                self.write()
                self.assert_bad("Filter")

    def test_explicit_global_filter_requires_authorization(self):
        self.files[self.inject + ".plist"] = plistlib.dumps({"Filter": {}})
        self.meta["allow_all_processes"] = True
        self.write()
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            self.assertEqual(gate.validate_deb(self.path, manifest=self.meta), [])
        self.assertIn("WARN", stream.getvalue())
        self.files[self.inject + ".plist"] = plistlib.dumps({})
        self.write()
        self.assert_bad("Filter")

    def test_missing_or_corrupt_preferences(self):
        self.enable_prefs()
        original = dict(self.files)
        for name in (self.loader, self.prefs_base + "Info.plist", self.prefs_base + PREFIX + "Prefs",
                     self.prefs_base + PREFIX + "Root.plist"):
            with self.subTest(missing=name):
                self.files = dict(original)
                del self.files[name]
                self.write()
                self.assert_bad()
        self.files = dict(original)
        self.control["Depends"] = "mobilesubstrate, roothide, not-preferenceloader"
        self.write()
        self.assert_bad("preferenceloader")
        self.control["Depends"] = "mobilesubstrate, roothide, preferenceloader | other"
        self.write()
        self.assert_bad("preferenceloader")
        self.control["Depends"] = "mobilesubstrate, roothide, preferenceloader"
        for name in (self.loader, self.prefs_base + "Info.plist", self.prefs_base + PREFIX + "Root.plist"):
            self.files = dict(original)
            self.files[name] = b"corrupt"
            self.write()
            self.assert_bad()
        self.files = dict(original)
        info = plistlib.loads(self.files[self.prefs_base + "Info.plist"])
        info["CFBundleExecutable"] = "OtherPrefs"
        self.files[self.prefs_base + "Info.plist"] = plistlib.dumps(info)
        self.write()
        self.assert_bad("不匹配")

    def test_invalid_ar_and_tar_containers(self):
        self.write()
        baseline = self.path.read_bytes()
        for blob in (b"not deb", baseline[:-1], baseline + b"x", baseline[:100],
                     baseline[:66] + b"xx" + baseline[68:]):
            with self.subTest(length=len(blob)):
                self.path.write_bytes(blob)
                self.assert_bad("解析失败")
        self.write()
        members = list(gate.read_ar(self.path.read_bytes()).items())
        for bad in (members[1:], [members[1], members[0], members[2]], members + [members[1]],
                    [("debian-binary", b"3.0\n")] + members[1:],
                    members[:2] + [("data.tar.gz", members[2][1][:-4])],
                    members[:2] + [("data.tar", tar_blob(self.files).rstrip(b"\0"))]):
            with self.subTest(member_names=[n for n, _ in bad]):
                self.write(members=bad)
                self.assert_bad("解析失败")
        bad_control = tar_blob({"control": b"Package without colon\n"})
        self.write(members=[members[0], ("control.tar", bad_control), members[2]])
        self.assert_bad("control")
        corrupt = bytearray(tar_blob(self.files))
        corrupt[0] ^= 1
        self.write(members=members[:2] + [("data.tar", bytes(corrupt))])
        self.assert_bad("解析失败")

    def test_macho_mutations(self):
        baseline = fat()
        first = struct.unpack_from(">I", baseline, 16)[0]
        second = struct.unpack_from(">I", baseline, 36)[0]
        mutations = []

        def change(offset, value, fmt=">I"):
            blob = bytearray(baseline)
            struct.pack_into(fmt, blob, offset, value)
            mutations.append(bytes(blob))

        mutations.extend([thin(0), b"\xca\xfe\xba\xbe" + struct.pack(">I", 2) + b"\0" * 40,
                          baseline[:40]])
        change(4, 0)                          # 空表
        change(4, 100)                        # 架构表越界
        change(8, 12)                         # ARM32 冒充 arm64
        change(12, 9)                         # 外部 subtype 错误
        change(16, 8)                         # slice 指向架构表
        change(16, first + 1)                 # 不对齐
        change(20, len(baseline))              # slice 越界
        change(24, 32)                        # 对齐指数非法
        change(36, first)                     # slice 重叠
        change(second, 0, "<I")               # 内部 magic 错误
        change(second + 4, 12, "<I")          # 内外 CPU 不同
        change(second + 8, 0, "<I")           # 仅改 FAT CPU 标签无效
        change(first + 12, 2, "<I")           # MH_EXECUTE 冒充 dylib
        change(first + 16, 9999, "<I")        # ncmds 越界
        change(first + 20, 9999, "<I")        # sizeofcmds 越界
        change(first + 32, 0x1b, "<I")         # 只有头和 identity 的空壳无 segment
        change(first + 36, 4, "<I")           # cmdsize 太短
        change(first + 36, 80, "<I")          # segment/section 表不匹配
        change(first + 32 + 48, 9999, "<Q")   # segment filesize 越界
        change(first + 32 + 72, 0xc, "<I")    # 缺 LC_ID_DYLIB
        change(first + 32 + 72 + 8, 999, "<I") # dylib name 越界
        for index, blob in enumerate(mutations):
            with self.subTest(index=index):
                self.files[self.inject + ".dylib"] = blob
                self.write()
                self.assert_bad()

    def test_cli_and_compatibility(self):
        self.write()
        project = Path(self.temp.name)
        (project / "tweak.json").write_text(json.dumps(self.meta), encoding="utf-8")
        argv = ["--project", str(project), "--scheme", "roothide", "--expected-version", "1.0", str(self.path)]
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(gate.main(argv), 0)
            self.assertEqual(gate.check(self.path, manifest=self.meta), [])
            argv[-2] = "9.0"
            self.assertEqual(gate.main(argv), 1)
        self.path.write_bytes(b"broken")
        proc = subprocess.run([sys.executable, str(Path(gate.__file__)), str(self.path)],
                              capture_output=True, text=True)
        self.assertEqual(proc.returncode, 1)
        self.assertNotIn("Traceback", proc.stderr + proc.stdout)
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertTrue(gate.check(self.path.with_name("absent.deb")))


if __name__ == "__main__":
    unittest.main()
