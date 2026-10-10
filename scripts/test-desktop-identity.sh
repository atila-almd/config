#!/usr/bin/env bash

set -Eeuo pipefail
export BLENDOS_WORKSTATION_MACHINE_PROFILE=vm

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
runner="${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner}"
if [[ ! -x "$runner" ]]; then runner="$(command -v qmltestrunner || true)"; fi
[[ -x "$runner" ]] || {
  printf 'ERROR: native qmltestrunner is required for the greeter presentation tests.\n' >&2
  exit 1
}

bash "$repo_dir/scripts/validate-desktop-identity.sh"
runtime="$(mktemp -d)"
trap 'rm -rf -- "$runtime"' EXIT
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic \
  XDG_CONFIG_HOME="$runtime/config" XDG_CACHE_HOME="$runtime/cache" XDG_STATE_HOME="$runtime/state" \
  "$runner" -platform offscreen -import "$repo_dir/.config/quickshell" \
  -input "$repo_dir/scripts/fixtures/workstation-greeter"
test_home="$runtime/home"
test_identity="$runtime/identity"
mkdir -p -- "$test_home"
BLENDOS_WORKSTATION_TARGET_HOME="$test_home" \
BLENDOS_WORKSTATION_TARGET_STATE_HOME="$runtime/install-state" \
BLENDOS_WORKSTATION_SYSTEM_PATH="$runtime/system.yaml" \
BLENDOS_WORKSTATION_IDENTITY_ROOT="$test_identity" \
BLENDOS_WORKSTATION_TEST_NO_SUDO=1 \
  bash "$repo_dir/install.sh" --identity-only > "$runtime/install-first.log"
for file in GreeterContract.js GreeterView.qml KeyboardState.qml shell.qml greeter-host \
    greeter-ui hyprland.lua hyprland-vm.lua mark-dark.svg mark-light.svg public-theme.json \
    WorkstationShared/AuthForm.qml WorkstationShared/Contract.js WorkstationShared/ThemedPane.qml WorkstationShared/qmldir; do
  [[ -s "$test_identity/$file" ]] || { printf 'ERROR: installer missed identity asset: %s\n' "$file" >&2; exit 1; }
done
BLENDOS_WORKSTATION_TARGET_HOME="$test_home" \
BLENDOS_WORKSTATION_TARGET_STATE_HOME="$runtime/install-state" \
BLENDOS_WORKSTATION_SYSTEM_PATH="$runtime/system.yaml" \
BLENDOS_WORKSTATION_IDENTITY_ROOT="$test_identity" \
BLENDOS_WORKSTATION_TEST_NO_SUDO=1 \
  bash "$repo_dir/install.sh" --identity-only > "$runtime/install-second.log"
if grep -q 'Backed up' "$runtime/install-second.log"; then
  printf 'ERROR: unchanged identity/system-only rerun displaced files\n' >&2
  exit 1
fi
printf 'Desktop identity source and presentation tests passed.\n'
