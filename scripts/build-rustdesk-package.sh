#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ $(uname -s) == Linux && $(uname -m) == x86_64 && $EUID != 0 ]] || {
  echo 'Build as a non-root user on an x86_64 Arch build host.' >&2; exit 1;
}
for cmd in makepkg git cargo rustup python; do
  command -v "$cmd" >/dev/null || { echo "Missing build prerequisite: $cmd" >&2; exit 1; }
done
: "${FLUTTER_ROOT:?Flutter 3.24.5 SDK path required}"
: "${BRIDGE_FLUTTER_ROOT:?Flutter 3.22.3 bridge SDK path required}"
: "${VCPKG_ROOT:?Bootstrapped pinned vcpkg path required}"
build_dir=${XDG_CACHE_HOME:-$HOME/.cache}/blendos-workstation/rustdesk-build
mkdir -p "$build_dir"
cp "$root/services/rustdesk/PKGBUILD" "$build_dir/PKGBUILD"
cd "$build_dir"
makepkg --syncdeps --cleanbuild --force
mapfile -t packages < <(makepkg --packagelist)
[[ ${#packages[@]} == 1 ]] || { echo 'Expected one native package.' >&2; exit 1; }
bash "$root/scripts/validate-rustdesk.sh" --package "${packages[0]}"
printf 'Validated native package: %s\n' "${packages[0]}"
