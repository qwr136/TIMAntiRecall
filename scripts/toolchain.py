#!/usr/bin/env python3
"""Locked toolchain preparation, verification and build receipts. Python stdlib only.
Never installs a tweak, runs package scripts, changes iOS settings or starts a release.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

sys.path.insert(0, str(Path(__file__).resolve().parent))

SHA = re.compile(r'[0-9a-f]{40}\Z')
SHA256 = re.compile(r'[0-9a-f]{64}\Z')


def require(ok, message):
    if not ok:
        raise ValueError(message)


def run(argv, cwd=None):
    return subprocess.check_output([str(x) for x in argv], cwd=cwd, text=True,
                                   stderr=subprocess.PIPE, timeout=240).strip()


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def blob_hash(raw):
    return hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()


def load_lock(project):
    path = Path(project) / 'toolchain-lock.json'
    d = json.loads(path.read_text(encoding='utf-8'))
    require(d.get('schema') == 1 and type(d['schema']) is int, 'unsupported toolchain lock schema')
    for section in ('platform', 'actions', 'theos', 'sdk', 'packaging', 'policy'):
        require(isinstance(d.get(section), dict), 'missing lock section: ' + section)
    require(d['policy']['mismatch'] == 'fail', 'version mismatches must fail')
    for repo in ('theos', 'sdk'):
        require(SHA.fullmatch(d[repo]['commit']), 'unfixed ' + repo + ' commit')
        require(d[repo]['repository'].startswith('https://github.com/'), 'unsupported source endpoint')
    require(SHA.fullmatch(d['sdk']['tree']), 'SDK tree must be fixed')
    for value in list(d['theos']['submodules'].values()) + list(d['sdk']['metadata_blobs'].values()):
        require(SHA.fullmatch(value), 'source hash must be fixed')
    require(re.fullmatch(r'\d+\.\d+\.\d+', d['python_version']), 'Python version must be exact')
    require(re.fullmatch(r'\d+\.\d+(?:\.\d+)?', d['platform']['xcode_version']), 'Xcode version must be exact')
    for action in d['actions'].values():
        require(re.fullmatch(r'[\w.-]+/[\w./-]+@[0-9a-f]{40}', action), 'unfixed action: ' + action)
    require(d['packaging'], 'packaging tools are not locked')
    return d


def static_errors(project):
    project = Path(project)
    try:
        lock = load_lock(project)
        meta = json.loads((project/'tweak.json').read_text())
        sdk = lock['sdk']
        require(meta['sdk_version'] == sdk['target_version'], 'manifest SDK differs from lock')
        require(sdk['directory'] == 'iPhoneOS' + meta['sdk_version'] + '.sdk', 'SDK directory differs from target')
        build = (project/(meta['name']+'Build.mk')).read_text()
        require(('iphone:clang:' + sdk['target_version'] + ':') in build, 'Build.mk SDK differs from lock')
        require((project/'scripts/toolchain.py').is_file(), 'toolchain checker missing')
        require((project/'scripts/locked_packaging.py').is_file(), 'packaging installer missing')
        wrapper = '\n'.join(line for line in (project/'build.sh').read_text().splitlines()
                            if not line.lstrip().startswith('#'))
        require('scripts/toolchain.py verify' in wrapper, 'local build wrapper misses lock verification')
        verification = re.search(r'^\s*python3\s+scripts/toolchain\.py\s+verify(?:\s|$)', wrapper, re.M)
        make_calls = list(re.finditer(r'(?:^|[;&|])\s*(?:[\w./-]*/)?(?:gmake|make)\s', wrapper, re.M))
        require(verification and make_calls and all(verification.start() < call.start() for call in make_calls),
                'lock verification must run before every make command')
        from build_contract import validate as validate_contract
        validate_contract(project)
        if not meta.get('github_actions'):
            return []
        text = '\n'.join(line for line in (project/'.github/workflows/build.yml').read_text().splitlines()
                         if not line.lstrip().startswith('#'))
        uses = re.findall(r'^\s*-?\s*uses:\s*(\S+)', text, re.M)
        require(uses and all(a in lock['actions'].values() for a in uses), 'workflow action differs from lock')
        for key in ('checkout', 'setup_python', 'cache', 'upload_artifact', 'release'):
            require(lock['actions'][key] in uses, 'workflow missing locked action: ' + key)
        require('latest-stable' not in text and 'ubuntu-latest' not in text, 'workflow uses a rolling latest selector')
        require(re.search(r'runs-on:\s*'+re.escape(lock['platform']['runner'])+r'\s*$', text, re.M), 'runner differs from lock')
        for needle in ('THEOS_COMMIT: '+lock['theos']['commit'],
                       'SDK_COMMIT: '+sdk['commit'],
                       'DEVELOPER_DIR: '+lock['platform']['developer_dir'],
                       "python-version: '"+lock['python_version']+"'"):
            require(needle in text, 'workflow missing locked value: ' + needle)
        for needle in ('toolchain.py prepare', 'toolchain.py verify', 'toolchain.py receipt',
                       "hashFiles('toolchain-lock.json')", '${{ runner.arch }}', 'timeout-minutes:'):
            require(needle in text, 'workflow missing gate: ' + needle)
        return []
    except (OSError, ValueError, KeyError, TypeError) as e:
        return ['Toolchain lock: ' + str(e)]


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + '.tmp')
    temp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    temp.replace(path)


def clean_repo(repo, expected):
    require(run(['git', 'rev-parse', 'HEAD'], repo) == expected, 'source checkout commit mismatch: '+str(repo))
    require(not run(['git', 'status', '--porcelain', '--untracked-files=no'], repo),
            'source checkout has tracked modifications: '+str(repo))


def checkout(repository, commit, destination, sparse=None):
    destination = Path(destination)
    if not (destination/'.git').exists():
        if destination.exists():
            require(not any(destination.iterdir()), 'refusing to initialize source checkout over nonempty path: '+str(destination))
        destination.parent.mkdir(parents=True, exist_ok=True)
        run(['git', 'init', str(destination)])
        run(['git', 'remote', 'add', 'origin', repository], destination)
        run(['git', 'fetch', '--depth', '1', '--filter=blob:none', 'origin', commit], destination)
        if sparse:
            run(['git', 'sparse-checkout', 'init', '--cone'], destination)
            run(['git', 'sparse-checkout', 'set', sparse], destination)
        run(['git', 'checkout', '--detach', commit], destination)
    clean_repo(destination, commit)
    return destination


def verify_sources(lock, theos, sdk_source):
    theos, sdk_source = Path(theos), Path(sdk_source)
    clean_repo(theos, lock['theos']['commit'])
    submodules = run(['git', 'submodule', 'status', '--recursive'], theos).splitlines()
    require(submodules and all(re.match(r'^\s*[0-9a-f]{40}\s', line) for line in submodules), 'uninitialized or changed submodules')
    actual = {line.strip().split()[1]: line.strip().split()[0] for line in submodules}
    for path, commit in lock['theos']['submodules'].items():
        require(actual.get(path) == commit, 'Theos submodule mismatch: '+path)
        clean_repo(theos/path, commit)
    clean_repo(sdk_source, lock['sdk']['commit'])
    sdk = lock['sdk']
    source = sdk_source/sdk['directory']
    require(run(['git', 'rev-parse', 'HEAD:'+sdk['directory']], sdk_source) == sdk['tree'], 'SDK tree mismatch')
    require(not run(['git', 'status', '--porcelain', '--untracked-files=all', '--', sdk['directory']], sdk_source),
            'SDK contains modified or extra files')
    installed = theos/'sdks'/sdk['directory']
    require(installed.is_dir() and installed.resolve() == source.resolve(), 'Theos SDK does not point to verified checkout')
    evidence = {}
    for name, expected in sdk['metadata_blobs'].items():
        raw = (source/name).read_bytes()
        require(blob_hash(raw) == expected, 'SDK metadata hash mismatch: '+name)
        value = plistlib.loads(raw) if name.endswith('.plist') else json.loads(raw)
        require(value['Version'] == sdk['internal_version'], 'SDK internal version mismatch')
        evidence[name] = {'blob': expected, 'version': value['Version']}
    require((theos/'vendor/include/roothide.h').is_file(), 'pinned RootHide header missing')
    require((theos/'vendor/include/Preferences/PSListController.h').is_file(), 'pinned Preferences headers missing')
    return {'theos_commit': lock['theos']['commit'], 'submodules': actual,
            'sdk_commit': sdk['commit'], 'sdk_tree': sdk['tree'], 'sdk_metadata': evidence}


def verify_platform(lock):
    p = lock['platform']
    require(platform.system() == p['os'], 'locked builds require '+p['os'])
    require(platform.machine() == p['architecture'], 'host architecture differs from lock')
    os_version = run(['sw_vers', '-productVersion'])
    require(os_version.split('.')[0] == p['macos_major'], 'macOS major differs from lock')
    require(os.environ.get('DEVELOPER_DIR') == p['developer_dir'], 'DEVELOPER_DIR differs from lock')
    xcode = run(['xcodebuild', '-version'])
    require(xcode == 'Xcode '+p['xcode_version']+'\nBuild version '+p['xcode_build'], 'Xcode version/build differs from lock')
    clang = run(['xcrun', '--sdk', 'iphoneos', 'clang', '--version'])
    require('(clang-'+p['clang_build']+')' in clang, 'Apple clang build differs from lock')
    require(platform.python_version() == lock['python_version'], 'Python differs from lock')
    return {'system': platform.system(), 'architecture': platform.machine(), 'macos': os_version,
            'os_build': run(['sw_vers','-buildVersion']), 'xcode': xcode, 'clang': clang,
            'python': platform.python_version(), 'developer_dir': os.environ['DEVELOPER_DIR'],
            'runner_image': os.environ.get('ImageVersion', ''), 'runner_os': os.environ.get('RUNNER_OS', ''),
            'runner_arch': os.environ.get('RUNNER_ARCH', '')}


def fetch_verified(url, expected, destination):
    destination = Path(destination)
    if destination.exists():
        require(digest(destination) == expected, 'cached download checksum mismatch')
        return destination
    require(url.startswith('https://'), 'download must use HTTPS')
    destination.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={'User-Agent': 'xiaofei-toolchain-lock/1'})
    temp = destination.with_suffix(destination.suffix+'.partial')
    try:
        with urllib.request.urlopen(request, timeout=90) as response, temp.open('wb') as output:
            shutil.copyfileobj(response, output)
        require(digest(temp) == expected, 'download checksum mismatch')
        temp.replace(destination)
    finally:
        if temp.exists(): temp.unlink()
    return destination


def packaging_bin_paths(lock):
    p = lock['packaging']['packages']
    base = Path('/opt/homebrew/Cellar')
    paths = [base/'make'/p['make']['version']/'libexec/gnubin']
    paths += [base/name/p[name]['version']/'bin' for name in lock['packaging']['install_order']]
    return paths


def install_packaging(lock, cache):
    require(os.environ.get('GITHUB_ACTIONS') == 'true' and os.environ.get('RUNNER_ENVIRONMENT') == 'github-hosted',
            'automatic packaging installation is restricted to disposable GitHub-hosted runners')
    core = lock['packaging']['homebrew_core']
    tap = Path('/opt/homebrew/Library/Taps/homebrew/homebrew-core')
    # Only a disposable hosted runner may move its preinstalled core tap.
    # User work and normal local installations are never reset by this script.
    if (tap/'.git').exists() and run(['git','rev-parse','HEAD'],tap) != core['commit']:
        require(not run(['git','status','--porcelain'],tap), 'runner core tap is dirty')
        run(['git','fetch','--depth','1','origin',core['commit']],tap)
        run(['git','checkout','--detach',core['commit']],tap)
    checkout(core['repository'], core['commit'], tap)
    script = Path(__file__).with_name('locked_packaging.py')
    subprocess.run([sys.executable,str(script),'--lock','toolchain-lock.json','--cache',str(cache),
                    '--receipt','reports/packaging-install.json','--install','--replace-existing'],check=True)


def verify_packaging(lock):
    script = Path(__file__).with_name('locked_packaging.py')
    result = Path('reports/packaging-current.json')
    subprocess.run([sys.executable,str(script),'--lock','toolchain-lock.json','--verify-only',
                    '--receipt',str(result)],check=True)
    evidence = json.loads(result.read_text())
    base = Path('/opt/homebrew/Cellar')
    pkgs = lock['packaging']['packages']
    commands = {'make':base/'make'/pkgs['make']['version']/'bin/gmake',
                'dpkg-deb':base/'dpkg'/pkgs['dpkg']['version']/'bin/dpkg-deb',
                'xz':base/'xz'/pkgs['xz']['version']/'bin/xz',
                'ldid':base/'ldid'/pkgs['ldid']['version']/'bin/ldid',
                'perl':base/'perl'/pkgs['perl']['version']/'bin/perl'}
    evidence['commands'] = {}
    for name,path in commands.items():
        require(shutil.which(name) and Path(shutil.which(name)).resolve() == path.resolve(),
                'PATH command differs from locked tool: '+name)
        evidence['commands'][name]={'path':str(path),'sha256':digest(path)}
    return evidence


def locations():
    root = Path(os.environ.get('TOOLCHAIN_ROOT', '/tmp/xiaofei-toolchain'))
    return root, Path(os.environ.get('THEOS', str(root/'theos'))), root/'sdks'


def prepare(project, lock):
    verify_platform(lock)
    root, theos, sdk_source = locations()
    checkout(lock['theos']['repository'], lock['theos']['commit'], theos)
    run(['git', 'submodule', 'update', '--init', '--recursive'], theos)
    checkout(lock['sdk']['repository'], lock['sdk']['commit'], sdk_source, lock['sdk']['directory'])
    link = theos/'sdks'/lock['sdk']['directory']
    link.parent.mkdir(parents=True, exist_ok=True)
    if not link.exists() and not link.is_symlink():
        link.symlink_to(sdk_source/lock['sdk']['directory'], target_is_directory=True)
    verify_sources(lock, theos, sdk_source)
    # Packaging is installed from checksum-locked bottles, never rolling formula names.
    install_packaging(lock, root/'downloads')
    package_bins = packaging_bin_paths(lock)
    if os.environ.get('GITHUB_PATH'):
        with open(os.environ['GITHUB_PATH'], 'a') as stream:
            for path in package_bins:
                stream.write(str(path)+'\n')
            stream.write(str(theos/'bin')+'\n')
    os.environ['PATH'] = os.pathsep.join([str(path) for path in package_bins] +
                                       [str(theos/'bin'), os.environ.get('PATH','')])
    print('Prepared exact Theos/SDK and packaging tools')


def verify(project, lock):
    host = verify_platform(lock)
    root, theos, sdk_source = locations()
    source = verify_sources(lock, theos, sdk_source)
    package = verify_packaging(lock)
    require(shutil.which('make') and Path(shutil.which('make')).resolve() ==
            Path(package['commands']['make']['path']).resolve(), 'PATH make is not the locked GNU make')
    return {'status':'verified', 'lock_sha256':digest(Path(project)/'toolchain-lock.json'),
            'host':host, 'sources':source, 'packaging':package}


def receipt(project, lock, output, version=None):
    from build_evidence import receipt as dylib_receipt
    version = version or os.environ.get('TIMANTIRECALL_VERSION', '0.10')
    evidence = verify(project, lock)
    result = dylib_receipt(project, evidence, output, version)
    print('Saved verified standalone dylib receipt:', output)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=('static','prepare','verify','receipt'))
    parser.add_argument('--project',default='.')
    parser.add_argument('--output',default='reports/toolchain-verification.json')
    parser.add_argument('--version',default=None)
    args = parser.parse_args()
    try:
        errors = static_errors(args.project)
        require(not errors, '\n'.join(errors))
        lock = load_lock(args.project)
        if args.command == 'static':
            print('PASS toolchain lock, workflow and build-wrapper consistency')
        elif args.command == 'prepare': prepare(args.project,lock)
        elif args.command == 'verify':
            write_json(args.output,verify(args.project,lock))
            print('PASS actual host, source hashes, SDK and packaging tool versions')
        else: receipt(args.project,lock,args.output,args.version)
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as e:
        print('ERROR: '+str(e),file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
