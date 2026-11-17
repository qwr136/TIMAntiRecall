#!/usr/bin/env python3
"""Compile and execute real macOS Foundation runtime doubles, never fake Foundation."""
import argparse
import json
import os
import tempfile
from pathlib import Path
import platform
import subprocess
from build_contract import require
from build_evidence import source_snapshot
from toolchain import write_json


def run(project, version):
    root = Path(project).resolve()
    test = root/'tests/native/TIMAntiRecallRuntimeTests.m'
    report = root/'reports/native-tests.json'
    if not test.is_file():
        # Explicit scaffold boundary. Receipt refuses to release this state.
        write_json(report, {'status': 'missing', 'reason': 'tests/native/TIMAntiRecallRuntimeTests.m not yet supplied'})
        raise ValueError('native runtime test source missing; build and delivery are blocked')
    require(platform.system() == 'Darwin' and platform.machine() == 'arm64',
            'native runtime tests require real macOS arm64 Foundation')
    source = source_snapshot(root, version)
    output = root/'reports/TIMAntiRecallRuntimeTests'
    sources = [str(root/p) for p in source['compile_inputs']]
    command = ['xcrun', '--sdk', 'macosx', 'clang', '-arch', 'arm64', '-fobjc-arc', '-fblocks',
               '-Wall', '-Wextra', '-DTIMANTIRECALL_NATIVE_TEST=1', '-DTIMANTIRECALL_TESTING=1',
               '-I'+str(root/'Sources'), '-I'+str(root/'Headers'),
               '-framework', 'Foundation', '-framework', 'CoreFoundation',
               *sources, str(test), '-o', str(output)]
    report.parent.mkdir(parents=True, exist_ok=True)
    write_json(report, {'status': 'running', 'source': source, 'command': command})
    with (root/'reports/native-tests.log').open('w') as log:
        subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
        subprocess.run([str(output)], cwd=root, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
        smoke=root/'tests/native/TIMAntiRecallConstructorTests.m'
        require(smoke.is_file(), 'real constructor smoke test is required')
        smoke_output=root/'reports/TIMAntiRecallConstructorTests'
        smoke_command=command.copy()
        smoke_command[smoke_command.index(str(test))]=str(smoke)
        smoke_command[smoke_command.index(str(output))]=str(smoke_output)
        smoke_command.insert(smoke_command.index('clang')+1,'-DTIMANTIRECALL_CONSTRUCTOR_TEST=1')
        subprocess.run(smoke_command, cwd=root, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
        preload=root/'reports/TIMAntiRecallPreloadFixture.dylib'
        preload_source=root/'tests/native/TIMAntiRecallPreloadFixture.c'
        require(preload_source.is_file(), 'image0 preloaded-dylib fixture is required')
        subprocess.run(['xcrun','--sdk','macosx','clang','-arch','arm64','-dynamiclib',
                        '-Wall','-Wextra',str(preload_source),'-o',str(preload)],
                       cwd=root,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=60)
        for inserted in (False,True):
            with tempfile.TemporaryDirectory(prefix='timantirecall-constructor-') as temporary:
                home=Path(temporary)/'home'; home.mkdir()
                tmp=Path(temporary)/'tmp'; tmp.mkdir()
                environment=dict(os.environ,HOME=str(home),TMPDIR=str(tmp))
                if inserted:
                    environment['DYLD_INSERT_LIBRARIES']=str(preload)
                    environment['TIMANTIRECALL_REQUIRE_INSERTED_FIRST']='1'
                subprocess.run([str(smoke_output)],cwd=root,env=environment,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=30)
    require(source == source_snapshot(root, version), 'source changed during runtime regression')
    write_json(report, {'status': 'passed', 'source': source, 'command': command,
                        'scope': 'real macOS Foundation runtime doubles; not TIM/iOS device behavior'})
    print('PASS native macOS Foundation runtime doubles')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', default='.')
    parser.add_argument('--version', required=True)
    args = parser.parse_args()
    run(args.project, args.version)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        raise SystemExit('ERROR: ' + str(error))
