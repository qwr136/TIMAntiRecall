#!/usr/bin/env python3
"""Bind clean tracked source blobs, CI identity and actual dylib bytes; stdlib only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
from build_contract import require, validate, version_for_run, version_tuple


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def git(root, *args):
    return subprocess.check_output(['git', *args], cwd=root, stderr=subprocess.PIPE).decode().strip()


def source_snapshot(project, version):
    root = Path(project).resolve()
    meta = validate(root)
    version_tuple(version)
    commit = git(root, 'rev-parse', 'HEAD')
    require(len(commit) == 40, 'full source commit is required')
    require(not git(root, 'status', '--porcelain', '--untracked-files=normal'),
            'source must be clean, including untracked build inputs')
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        require(commit == os.environ.get('GITHUB_SHA'), 'source HEAD differs from GitHub SHA')
        require(version == version_for_run(os.environ.get('GITHUB_RUN_NUMBER', '')),
                'version differs from CI run number')
        for key in ('GITHUB_REPOSITORY', 'GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT', 'GITHUB_REF'):
            require(bool(os.environ.get(key)), 'missing CI identity: ' + key)
    # ls-tree uses NUL delimiters: whitespace in filenames cannot hide a blob.
    entries = subprocess.check_output(['git', 'ls-tree', '-rz', '--full-tree', 'HEAD'], cwd=root)
    blobs = []
    for row in entries.split(b'\0'):
        if not row:
            continue
        header, raw_path = row.split(b'\t', 1)
        mode, kind, blob = header.decode().split()
        path = raw_path.decode('utf-8')
        require(kind == 'blob' and mode in ('100644', '100755'), 'non-regular tracked input: ' + path)
        actual = root/path
        require(actual.is_file() and not actual.is_symlink(), 'missing/unsafe tracked input: ' + path)
        content = actual.read_bytes()
        actual_blob = hashlib.sha1(b'blob ' + str(len(content)).encode() + b'\0' + content).hexdigest()
        require(actual_blob == blob, 'tracked blob differs from HEAD: ' + path)
        blobs.append({'path': path, 'mode': mode, 'blob_sha1': blob, 'sha256': digest(actual)})
    require(blobs, 'no tracked source blobs')
    paths = {b['path'] for b in blobs}
    mandatory = {'Makefile', 'TIMAntiRecallBuild.mk', 'build.sh', 'control', 'tweak.json',
                 'toolchain-lock.json', 'scripts/build_evidence.py', 'scripts/verify_dylib.py'}
    require(mandatory <= paths, 'build inputs missing from tracked blob list')
    inputs = sorted(str(p.relative_to(root)) for folder in ('Sources', 'Hooks')
                    for p in (root/folder).glob('*.m'))
    require(inputs and any(p.startswith('Hooks/') for p in inputs), 'no Objective-C Hooks/*.m build input')
    require(set(inputs) <= paths, 'untracked compile input')
    identity = {key: os.environ.get(env, '') for key, env in (
        ('repository', 'GITHUB_REPOSITORY'), ('run_id', 'GITHUB_RUN_ID'),
        ('run_attempt', 'GITHUB_RUN_ATTEMPT'), ('run_number', 'GITHUB_RUN_NUMBER'),
        ('source_ref', 'GITHUB_REF'), ('workflow_ref', 'GITHUB_WORKFLOW_REF'))}
    return dict(identity, source_sha=commit, source_tree=git(root, 'rev-parse', 'HEAD^{tree}'),
                tracked_blobs=blobs, compile_inputs=inputs, version=version,
                package=meta['package'], scheme=meta['scheme'],
                lock_sha256=digest(root/'toolchain-lock.json'))


def seal(project, version):
    from verify_dylib import validate_file
    from toolchain import write_json
    root = Path(project).resolve()
    current = source_snapshot(root, version)
    previous = json.loads((root/'reports/build-source.json').read_text())
    require(previous == current, 'source/run/lock changed during compilation')
    artifact = validate_file(root/'dist/TIMAntiRecall.dylib', root, 'trollfools', version)
    result = {'source': current, 'artifact': artifact,
              'compile_contract': {'target': 'iphone:clang:16.5:16.5', 'archs': ['arm64', 'arm64e'],
                                   'make_target': 'all', 'code_signature_page_hashes_verified': True}}
    write_json(root/'reports/build-seal.json', result)
    return result


def receipt(project, evidence, output, version):
    from verify_dylib import validate_file
    from toolchain import write_json
    root = Path(project).resolve()
    current = source_snapshot(root, version)
    seal_record = json.loads((root/'reports/build-seal.json').read_text())
    actual = validate_file(root/'dist/TIMAntiRecall.dylib', root, 'trollfools', version)
    native = json.loads((root/'reports/native-tests.json').read_text())
    require(native.get('status') == 'passed' and native.get('source') == current,
            'native Foundation runtime tests missing, failed or from different source/run')
    require(seal_record['source'] == current and seal_record['artifact'] == actual,
            'build seal differs from source/run/artifact')
    require(evidence['lock_sha256'] == current['lock_sha256'], 'receipt lock mismatch')
    verified = json.loads((root/'reports/dylib-verification.json').read_text())
    require(verified == actual, 'dylib verification report does not match artifact')
    require(not list((root/'packages').glob('*.deb')), 'unexpected deb output')
    require({p.name for p in (root/'dist').iterdir()} <= {'TIMAntiRecall.dylib', 'build-receipt.json'},
            'unexpected deliverable in dist')
    result = dict(evidence, **current, artifact=actual, native_tests=native,
                  compile_contract=seal_record['compile_contract'],
                  validation='Source gates + native macOS runtime doubles + real dual-arch dylib inspection; device untested')
    write_json(output, result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('snapshot', 'seal'))
    parser.add_argument('--project', default='.')
    parser.add_argument('--version', required=True)
    args = parser.parse_args()
    if args.command == 'snapshot':
        from toolchain import write_json
        write_json(Path(args.project)/'reports/build-source.json', source_snapshot(args.project, args.version))
    else:
        seal(args.project, args.version)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        raise SystemExit('ERROR: ' + str(error))
