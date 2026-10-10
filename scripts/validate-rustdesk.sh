#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ ${1:-} == --package && $# == 2 ]]; then
  exec python3 "$root/services/rustdesk/check-package.py" "$2"
fi
[[ $# == 0 ]] || { echo "Usage: $0 [--package FILE]" >&2; exit 2; }
bash -n "$root/services/rustdesk/PKGBUILD"
python3 - "$root" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
recipe = (root / 'services/rustdesk/PKGBUILD').read_text()
assert re.search(r'^_commit=[0-9a-f]{40}$', recipe, re.M)
assert re.search(r'^_vcpkg_commit=[0-9a-f]{40}$', recipe, re.M)
for required in ('flutter,drm,drm-wake,hwcodec,unix-file-copy-paste', 'assert_so_satisfies_the_runtime_abi_gate',
                 'build._carries_drmtap_marker', 'rustdesk.service'):
    assert required in recipe, required
assert 'DRMTAP_ALLOW_UNPINNED-}' in recipe
print('RustDesk source contract checks passed; native build and live acceptance are separate.')
PY
