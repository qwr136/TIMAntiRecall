#!/usr/bin/env python3
"""Reference only: download+verify anywhere; --install requires disposable macOS 15 ARM64.
No private GitHub token. Never run --replace-existing on a personal/production host.
Host Homebrew and its portable Ruby are rolling-recorded, not pinned by this lock.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = Path(__file__).resolve().parent
MACHO = {b'\xcf\xfa\xed\xfe', b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xfe\xed\xfa\xce', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'}

def sha(data):
    return hashlib.sha256(data).hexdigest()

def file_sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for data in iter(lambda: f.read(1024 * 1024), b''):
            h.update(data)
    return h.hexdigest()

def fail(message):
    raise RuntimeError(message)

def fetch(url):
    # Redirection to GHCR's public blob store is handled by urllib. Token stays local.
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'locked-packaging-reference'})
            try:
                return urllib.request.urlopen(req, timeout=120).read()
            except urllib.error.HTTPError as e:
                if e.code != 401 or not url.startswith('https://ghcr.io/v2/'):
                    raise
                repo = url.split('/v2/', 1)[1].split('/blobs/', 1)[0]
                token_url = 'https://ghcr.io/token?' + urllib.parse.urlencode({
                    'service': 'ghcr.io', 'scope': 'repository:' + repo + ':pull'})
                token = json.load(urllib.request.urlopen(token_url, timeout=60))['token']
                req = urllib.request.Request(url, headers={
                    'User-Agent': 'locked-packaging-reference', 'Authorization': 'Bearer ' + token})
                return urllib.request.urlopen(req, timeout=120).read()
        except Exception:
            if attempt == 2:
                # Do not include URLs with redirected authorization parameters in error logs.
                fail('download failed for host ' + urllib.parse.urlsplit(url).hostname)
            time.sleep(1 + attempt)

def run(args, env, check=True):
    p = subprocess.run([str(x) for x in args], env=env, text=True,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if check and p.returncode:
        fail('command failed: ' + ' '.join(str(x) for x in args) + '\n' + p.stdout[-9000:])
    return p

def check_archive(path, name, pkg):
    root = PurePosixPath(name) / pkg['version']
    embedded = str(root / '.brew' / (name + '.rb'))
    # Read members only; do not extract arbitrary tar paths or replace Mach-O bytes.
    with tarfile.open(path, 'r:gz') as archive:
        seen = set()
        for member in archive:
            parts = PurePosixPath(member.name)
            if parts.is_absolute() or '..' in parts.parts or member.name in seen:
                fail('unsafe or duplicate tar member: ' + name)
            seen.add(member.name)
        info = archive.getmember(embedded)
        if not info.isfile() or info.size > 1024 * 1024:
            fail('embedded formula is not a small regular file: ' + name)
        contents = archive.extractfile(info).read()
        if sha(contents) != pkg['formula']['embedded_sha256']:
            fail('embedded formula SHA mismatch: ' + name)
        for binary in pkg.get('verified_binary_paths', []):
            archive.getmember(binary)
    return sha(contents)

def acquire(lock, cache):
    cache.mkdir(parents=True, exist_ok=True)
    core = lock['homebrew_core']['commit']
    for name in lock['install_order']:
        pkg = lock['packages'][name]
        path = cache / pkg['bottle']['filename']
        if not path.exists() or file_sha(path) != pkg['bottle']['sha256']:
            data = fetch(pkg['bottle']['url'])
            if sha(data) != pkg['bottle']['sha256']:
                fail('bottle SHA mismatch: ' + name)
            tmp = path.with_name(path.name + '.partial')
            tmp.write_bytes(data)
            tmp.replace(path)
        check_archive(path, name, pkg)
        formula = cache / (name + '.formula.rb')
        if not formula.exists() or file_sha(formula) != pkg['formula']['sha256']:
            data = fetch('https://raw.githubusercontent.com/Homebrew/homebrew-core/' +
                         core + '/' + pkg['formula']['path'])
            if sha(data) != pkg['formula']['sha256']:
                fail('pinned formula SHA mismatch: ' + name)
            formula.write_bytes(data)
        print('verified', name, pkg['version'], flush=True)

def is_macho_header(header, size):
    if len(header) < 8 or header[:4] not in MACHO:
        return False
    if header[:4] in (b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'):
        # Java .class uses CAFEBABE too; its minor/major word is not a fat slice count.
        endian = '>' if header[:4] == b'\xca\xfe\xba\xbe' else '<'
        count = struct.unpack(endian+'I', header[4:8])[0]
        return 0 < count <= 32 and 8 + count * 20 <= size
    return size >= 28


def macho_files(keg):
    for path in keg.rglob('*'):
        if path.is_file() and not path.is_symlink():
            with path.open('rb') as f:
                if is_macho_header(f.read(8), path.stat().st_size):
                    yield path

def owned(path, kegs):
    real = path.resolve(strict=True)
    for name, keg in kegs.items():
        if real == keg or keg in real.parents:
            return name, real
    fail('non-system library resolved outside locked kegs: ' + str(path) + ' -> ' + str(real))

def dylib_names(path, env):
    text = run(['/usr/bin/otool', '-L', path], env).stdout
    return [line.strip().split(' (compatibility version', 1)[0]
            for line in text.splitlines() if line.startswith(('\t', ' '))]

def rpaths(path, env):
    text = run(['/usr/bin/otool', '-l', path], env).stdout
    return re.findall(r'cmd LC_RPATH\n.*?\n\s*path (.*?) \(offset', text, re.S)

def audit(lock, env):
    cellar = Path('/opt/homebrew/Cellar')
    kegs = {n: (cellar / n / p['version']).resolve(strict=True)
            for n, p in lock['packages'].items()}
    receipt = {'packages': {}, 'mach_o': {}, 'runtime_smoke': {}}
    for name, pkg in lock['packages'].items():
        keg = kegs[name]
        opt = Path('/opt/homebrew/opt') / name
        if opt.resolve(strict=True) != keg:
            fail('opt points at unlocked keg: ' + name)
        tab = keg / 'INSTALL_RECEIPT.json'
        if not tab.exists():
            fail('missing Homebrew installation receipt: ' + name)
        tab_data = json.loads(tab.read_text())
        if not tab_data.get('poured_from_bottle'):
            fail('not poured from a bottle: ' + name)
        formula = keg / '.brew' / (name + '.rb')
        if file_sha(formula) != pkg['formula']['embedded_sha256']:
            fail('installed embedded formula differs: ' + name)
        receipt['packages'][name] = {'version': pkg['version'], 'keg': str(keg),
            'bottle_sha256': pkg['bottle']['sha256'], 'formula_sha256': pkg['formula']['sha256'],
            'embedded_formula_sha256': file_sha(formula), 'install_receipt': tab_data}
        for path in macho_files(keg):
            # These bottles have fixed /opt/homebrew dependencies after pouring.
            # Fail closed on any unresolved @rpath; do not silently assume it is system-owned.
            deps = dylib_names(path, env)
            resolved = []
            for dep in deps:
                if '@@HOMEBREW_' in dep:
                    fail('unrelocated Mach-O load command: ' + str(path))
                if dep.startswith(('/usr/lib/', '/System/Library/')):
                    continue
                if dep.startswith('@loader_path/'):
                    target = path.parent / dep[len('@loader_path/'):]
                elif dep.startswith('@rpath/'):
                    suffix = dep[len('@rpath/'):]
                    candidates = [Path(r.replace('@loader_path', str(path.parent))) / suffix
                                  for r in rpaths(path, env) if '@executable_path' not in r]
                    found = [c for c in candidates if c.exists()]
                    if not found:
                        fail('unresolved @rpath dependency: ' + str(path) + ': ' + dep)
                    target = found[0]
                elif dep.startswith('/'):
                    target = Path(dep)
                else:
                    fail('unsupported load command: ' + str(path) + ': ' + dep)
                owner, real = owned(target, kegs)
                if owner != name and owner not in closure(name, lock):
                    fail('unexpected dependency outside declared DAG: ' + name + ' -> ' + owner)
                resolved.append({'load_command': dep, 'package': owner, 'resolved': str(real)})
            # Native ARM64 Mach-O files are ad-hoc signed; relocation must preserve valid signatures.
            sign = run(['/usr/bin/codesign', '--verify', '--strict', path], env, check=False)
            if sign.returncode:
                fail('Mach-O signature verification failed: ' + str(path) + '\n' + sign.stdout)
            receipt['mach_o'][str(path)] = {'sha256': file_sha(path), 'dependencies': resolved,
                                          'codesign_verified': True}
    # Execute precise keg paths, never a PATH-resolved rolling root/opt entry.
    commands = {'make': [kegs['make'] / 'bin/gmake', '--version'],
                'xz': [kegs['xz'] / 'bin/xz', '--version'],
                'dpkg': [kegs['dpkg'] / 'libexec/bin/dpkg-deb', '--version'],
                'ldid': [kegs['ldid'] / 'bin/ldid']}
    for name, command in commands.items():
        test_env = dict(env, DYLD_PRINT_LIBRARIES='1')
        proc = run(command, test_env, check=False)
        if name != 'ldid' and proc.returncode:
            fail('locked binary smoke failed: ' + name + '\n' + proc.stdout)
        if 'Library not loaded' in proc.stdout or proc.returncode < 0 or proc.returncode > 1:
            fail('loader smoke failed: ' + name + '\n' + proc.stdout)
        loaded = re.findall(r'^dyld\[[0-9]+\]:\s+.*?(/(?:opt/homebrew|usr/lib|System/Library)/[^\n]+)',
                            proc.stdout, re.M)
        if not loaded:
            fail('DYLD_PRINT_LIBRARIES produced no evidence: ' + name)
        real_loaded = []
        for entry in loaded:
            if entry.startswith('/opt/homebrew/'):
                owner, real = owned(Path(entry.strip()), kegs)
                real_loaded.append({'package': owner, 'resolved': str(real)})
        receipt['runtime_smoke'][name] = {'returncode': proc.returncode,
            'loaded_locked_libraries': real_loaded, 'output': proc.stdout}
    return receipt

def closure(name, lock):
    result = set()
    def walk(n):
        for dep in lock['packages'][n]['dependencies']:
            if dep not in result:
                result.add(dep)
                walk(dep)
    walk(name)
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lock', type=Path, default=BASE / 'packaging-lock.json')
    parser.add_argument('--cache', type=Path, default=BASE / 'bottle-cache')
    parser.add_argument('--receipt', type=Path, default=BASE / 'packaging-install-receipt.json')
    parser.add_argument('--install', action='store_true')
    parser.add_argument('--replace-existing', action='store_true',
                        help='REMOVE existing closure kegs; ONLY for disposable test runners')
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    lock_bytes = args.lock.read_bytes()
    lock = json.loads(lock_bytes)['packaging']
    order = lock['install_order']
    if len(set(order)) != len(order) or set(order) != set(lock['packages']):
        fail('install_order differs from packages')
    visited = set()
    for name in order:
        if not set(lock['packages'][name]['dependencies']) <= visited:
            fail('not a topological installation order: ' + name)
        visited.add(name)
    if args.install or args.verify_only:
        if platform.system() != 'Darwin' or platform.machine() != 'arm64' or not platform.mac_ver()[0].startswith('15.'):
            fail('installation/audit requires native macOS 15 ARM64')
    if not args.verify_only:
        acquire(lock, args.cache.resolve())
    if not args.install and not args.verify_only:
        print('all original bottles and both formula SHA values verified; nothing installed')
        return
    env = dict(os.environ)
    for var in ('HOMEBREW_NO_AUTO_UPDATE', 'HOMEBREW_NO_INSTALL_UPGRADE',
                'HOMEBREW_NO_INSTALL_CLEANUP', 'HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK',
                'HOMEBREW_NO_ANALYTICS'):
        env[var] = '1'
    # Do not permit inherited DYLD injection paths to override audited locked libraries.
    for var in list(env):
        if var.startswith('DYLD_'):
            del env[var]
    brew = shutil.which('brew')
    if not brew:
        fail('Homebrew missing; this reference does not install a rolling bootstrap')
    if run([brew, '--prefix'], env).stdout.strip() != '/opt/homebrew':
        fail('requires native /opt/homebrew prefix')
    if run([brew, '--cellar'], env).stdout.strip() != '/opt/homebrew/Cellar':
        fail('requires /opt/homebrew/Cellar')
    brew_version = run([brew, '--version'], env).stdout.strip()
    if args.install:
        if os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted':
            fail('package replacement is restricted to disposable GitHub-hosted runners')
        present = [n for n in order if (Path('/opt/homebrew/Cellar') / n).exists()]
        if present and not args.replace_existing:
            fail('existing kegs require isolated runner --replace-existing: ' + ', '.join(present))
        # All downloads/formula hashes already verified before the first uninstall.
        for name in reversed(order):
            if name in present:
                run([brew, 'uninstall', '--force', '--ignore-dependencies', name], env)
        for name in order:
            pkg = lock['packages'][name]
            formula = Path('/opt/homebrew/Library/Taps/homebrew/homebrew-core') / pkg['formula']['path']
            if file_sha(formula) != pkg['formula']['sha256']:
                fail('active pinned formula mismatch: ' + name)
            # Homebrew 7 rejects arbitrary local bottle paths. Resolve only the
            # checked-out immutable core formula, with the API/update disabled.
            run([brew, 'fetch', '--force-bottle', name], env)
            cached = Path(run([brew, '--cache', name], env).stdout.strip())
            if not cached.is_file() or file_sha(cached) != pkg['bottle']['sha256']:
                fail('Homebrew selected an unlocked bottle: ' + name)
            check_archive(cached, name, pkg)
            output = run([brew, 'install', '--ignore-dependencies', '--force-bottle',
                          '--skip-link', '--skip-post-install', name], env).stdout
            if any(s in output for s in ('Falling back to non-bottle formula',
                                         'Unreadable formula', 'already installed', './configure')):
                fail('bottle fallback or install skipped: ' + name + '\n' + output)
            print('poured locked bottle', name, flush=True)
    receipt = audit(lock, env)
    receipt.update({'lock_sha256': sha(lock_bytes), 'homebrew_version': brew_version,
                    'host': {'macos': platform.mac_ver()[0], 'arch': platform.machine()},
                    'homebrew_engine_status': 'rolling-recorded',
                    'guarantee': 'Downloaded bottle bytes and declared formula snapshots locked; '
                                 'installed dyld resolutions audited at receipt time. '
                                 'Do not run brew update/upgrade concurrently or afterward before build.'})
    args.receipt.parent.mkdir(parents=True, exist_ok=True)
    args.receipt.write_text(json.dumps(receipt, indent=2) + '\n')
    print('audited locked Cellar dynamic-library resolutions:', args.receipt)
    print('Exact PATH entries:')
    for name, suffix in [('make', 'libexec/gnubin'), ('ldid', 'bin'), ('xz', 'bin'),
                         ('dpkg', 'bin'), ('perl', 'bin'), ('gnu-tar', 'libexec/gnubin'),
                         ('gpatch', 'libexec/gnubin')]:
        print('/opt/homebrew/Cellar/' + name + '/' + lock['packages'][name]['version'] + '/' + suffix)

if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print('ERROR:', str(exc), file=sys.stderr)
        sys.exit(1)
