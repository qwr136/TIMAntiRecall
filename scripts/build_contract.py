#!/usr/bin/env python3
"""Standalone injection build contract. Does not claim hook behavior is tested."""
import argparse
import json
import re
from pathlib import Path


def require(ok, message):
    if not ok:
        raise ValueError(message)


def active(path):
    return '\n'.join(line.split('#', 1)[0].rstrip() for line in Path(path).read_text().splitlines())


def control_fields(path):
    fields = {}
    for line in Path(path).read_text().splitlines():
        if not line:
            continue
        key, separator, value = line.partition(':')
        require(separator and key not in fields and not key[0].isspace(), 'invalid control metadata')
        fields[key] = value.strip()
    return fields


def version_for_run(number):
    require(str(number).isdecimal() and int(number) > 0, 'run number must be positive')
    number = int(number)
    return f'{number // 10}.{(number % 10) * 10:02d}'


def version_tuple(version):
    require(re.fullmatch(r'(0|[1-9]\d*)\.(\d{2})', version) is not None, 'invalid build version')
    major, minor = map(int, version.split('.'))
    require(major <= 65535 and minor % 10 == 0, 'version outside 0.10 sequence')
    return [major, minor, 0]


def validate(project):
    root = Path(project)
    meta = json.loads((root/'tweak.json').read_text())
    for key, value in {'schema': 1, 'name': 'TIMAntiRecall', 'package': 'com.minis.timantirecall',
                       'author': 'Xiaofei', 'scheme': 'trollfools', 'injection': 'trollfools',
                       'bundle': 'com.tencent.tim', 'executable': 'QQ',
                       'artifact': 'dist/TIMAntiRecall.dylib', 'minimum_ios': '16.5',
                       'architectures': ['arm64', 'arm64e'], 'delivery_architectures': ['arm64'],
                       'preferences': False, 'slider': False,
                       'target_app_architecture': 'arm64', 'target_app_version': '4.1.0'}.items():
        require(meta.get(key) == value, 'manifest contract differs: ' + key)
    version_tuple(meta['version'])
    fields = control_fields(root/'control')
    for key, value in {'Package': meta['package'], 'Author': meta['author'], 'Maintainer': meta['author'],
                       'Version': meta['version'], 'Architecture': 'arm64',
                       'X-Build-Architectures': 'arm64 arm64e',
                       'X-Artifact': meta['artifact'], 'X-Injection': meta['injection']}.items():
        require(fields.get(key) == value, 'control metadata differs: ' + key)
    require(not fields.get('Depends'), 'standalone library cannot have Debian Depends')
    make = active(root/'Makefile')
    shared = active(root/'TIMAntiRecallBuild.mk')
    for needle in ('LIBRARY_NAME = TIMAntiRecall', '$(wildcard Sources/*.m Hooks/*.m)',
                   'include $(THEOS_MAKE_PATH)/library.mk', 'TIMAntiRecall_INSTALL = 0',
                   'TIMAntiRecall_INSTALL_PATH = @rpath'):
        require(needle in make, 'library Makefile missing: ' + needle)
    require(re.search(r'^TIMAntiRecall_LIBRARIES\s*=\s*$', make, re.M), 'instance LIBRARIES must be empty')
    require(re.search(r'^LIBRARIES\s*=\s*$', shared, re.M), 'global LIBRARIES must be empty')
    require('ARCHS = arm64 arm64e' in shared, 'both genuine architectures required')
    require('TARGET = iphone:clang:16.5:16.5' in shared and not re.search(r'^TARGET\s*[:?+]?=', make, re.M),
            'SDK/deployment target must be defined only in Build.mk')
    require('override THEOS_PACKAGE_SCHEME :=' in shared, 'Theos packaging scheme must be empty')
    require(not re.search(r'tweak\.mk|substrate|roothide|libroot|rootless|/var/jb|WebKit|SUBPROJECTS', make),
            'jailbreak, UI or subproject dependency in library Makefile')
    require('TIMANTIRECALL_VERSION' in make and '-current_version' in make, 'binary version flag missing')
    wrapper = active(root/'build.sh')
    require('DEFAULT_SCHEME=trollfools' in wrapper, 'wrapper scheme differs')
    require(not re.search(r'\bmake\s+(?:package|stage|install)\b', wrapper), 'package/install forbidden')
    for needle in ('scripts/toolchain.py verify', 'scripts/build_evidence.py snapshot',
                   'scripts/build_evidence.py seal', 'scripts/verify_dylib.py'):
        require(needle in wrapper, 'wrapper missing gate: ' + needle)
    require('scripts/prepare_delivery.py' in wrapper and
            wrapper.index('make all') < wrapper.index('scripts/prepare_delivery.py') < wrapper.index('scripts/verify_dylib.py'),
            'real arm64 extraction must follow universal compilation and precede verification')
    require('reports/universal/TIMAntiRecall.dylib' in make and
            'dist/TIMAntiRecall.dylib' not in make, 'Makefile must not deliver FAT directly')
    require('scripts/prepare_delivery.py' in wrapper and
            wrapper.index('make all') < wrapper.index('scripts/prepare_delivery.py') < wrapper.index('scripts/verify_dylib.py'),
            'exact arm64 extraction must follow universal compile before final verification')
    require(re.findall(r'^Architecture:\s*(\S+)', (root/'control').read_text(), re.M) == ['arm64'] and
            re.findall(r'^X-Build-Architectures:\s*(\S+\s+\S+)', (root/'control').read_text(), re.M) == ['arm64 arm64e'],
            'final architecture metadata must describe arm64 delivery and dual-arch build separately')
    if meta.get('github_actions'):
        workflow = active(root/'.github/workflows/build.yml')
        require(re.findall(r'^\s*-\s+build_variant:\s*(\S+)', workflow, re.M) == ['trollfools'],
                'CI matrix must contain only trollfools')
        require('needs: test' in workflow and 'runs-on: ubuntu-24.04' in workflow, 'Linux source gate missing')
        steps = ('toolchain.py prepare', 'toolchain.py verify', 'scripts/run_native_tests.py',
                 'sh build.sh', 'scripts/verify_dylib.py', 'toolchain.py receipt', 'name: Upload Artifacts')
        positions = [workflow.find(step) for step in steps]
        require(all(i >= 0 for i in positions) and positions == sorted(positions), 'CI gate order invalid')
        require('packages/*.deb' not in workflow and 'verify_deb.py' not in workflow, 'CI must not deliver deb')
        require('dist/TIMAntiRecall.dylib' in workflow and 'dist/build-receipt.json' in workflow,
                'CI delivery paths differ')
        for option in ('--project .', '--scheme', '--expected-version'):
            require(option in workflow, 'CI artifact check missing ' + option)
        require('target_commitish: ${{ github.sha }}' in workflow, 'Release must target built SHA')
    return meta


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', default='.')
    parser.add_argument('--scheme', default='trollfools')
    parser.add_argument('--run-number')
    args = parser.parse_args()
    require(args.scheme == 'trollfools', 'only trollfools is supported')
    if args.run_number:
        print(version_for_run(args.run_number))
    else:
        validate(args.project)
        print('PASS standalone dylib build contract')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit('ERROR: ' + str(error))
