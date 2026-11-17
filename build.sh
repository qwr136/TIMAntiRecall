#!/bin/sh
set -eu
cd "$(dirname "$0")"
DEFAULT_SCHEME=trollfools
[ "$#" -gt 0 ] || set -- "$DEFAULT_SCHEME"
if [ "$#" -ne 1 ] || [ "$1" != "$DEFAULT_SCHEME" ]; then
    printf 'ERROR: only one trollfools standalone dylib contract is supported\n' >&2
    exit 2
fi
if [ -n "${THEOS_PACKAGE_SCHEME:-}" ]; then
    printf 'ERROR: THEOS_PACKAGE_SCHEME must be empty for standalone injection\n' >&2
    exit 2
fi
python3 scripts/build_contract.py --project . --scheme "$1"
python3 scripts/toolchain.py static
: "${THEOS:?Set THEOS to the locked Theos checkout first}"
python3 scripts/toolchain.py verify --output reports/local-toolchain.json
VERSION="${TIMANTIRECALL_VERSION:-0.10}"
python3 scripts/build_evidence.py snapshot --project . --version "$VERSION"
python3 tests/run_tests.py -v
# Never accept an old artifact if make fails, and never invoke package/stage/install.
mkdir -p dist
rm -f dist/TIMAntiRecall.dylib dist/build-receipt.json reports/build-seal.json
make clean THEOS_PACKAGE_SCHEME=
make all THEOS_PACKAGE_SCHEME= TIMANTIRECALL_VERSION="$VERSION" ARCHS="arm64 arm64e"
python3 scripts/verify_dylib.py --project . --scheme trollfools --expected-version "$VERSION" --output reports/dylib-verification.json dist/TIMAntiRecall.dylib
python3 scripts/build_evidence.py seal --project . --version "$VERSION"
printf 'Verified standalone library: dist/TIMAntiRecall.dylib (device untested)\n'
