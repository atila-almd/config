#!/usr/bin/env bash
# Native Qt/Quickshell offscreen greeter rendering, never installed acceptance.
set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
identity_dir="$repo_dir/services/desktop/identity"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ $# == 1 && "$1" == /* ]] || fail 'Usage: bash scripts/check-workstation-greeter-views.sh /ABSOLUTE/NEW-REPORT-DIRECTORY'
report="$(realpath -m -- "$1")"
[[ ! -e "$report" ]] || fail 'Report directory already exists'
case "$report/" in "$repo_dir/"*) fail 'Reports must stay outside the working tree' ;; esac
command -v qs >/dev/null || fail 'Native Quickshell is required'
command -v timeout >/dev/null || fail 'timeout is required'
umask 077
mkdir -m0700 -- "$report"
runtime="$(mktemp -d)"
trap 'rm -rf -- "$runtime"' EXIT
mkdir -p -- "$runtime/config"
cp -- "$identity_dir/GreeterView.qml" "$runtime/config/GreeterView.qml"
cp -- "$repo_dir/scripts/fixtures/workstation-greeter/render-shell.qml" "$runtime/config/shell.qml"
for view_case in 0 1 2 3; do
  env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic \
    XDG_RUNTIME_DIR="$runtime" XDG_STATE_HOME="$runtime/state" XDG_CACHE_HOME="$runtime/cache" \
    QML_IMPORT_PATH="$repo_dir/.config/quickshell${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" \
    WORKSTATION_IDENTITY_ROOT="$identity_dir" \
    WORKSTATION_GREETER_THEME_FIXTURE="$repo_dir/themes/catppuccin-mocha/theme.json" \
    WORKSTATION_GREETER_RENDER_REPORT="$report" \
    WORKSTATION_GREETER_RENDER_CASE="$view_case" \
    timeout 20 qs -p "$runtime/config" >> "$report/runtime.log" 2>&1
done
for name in greeter-dark-account greeter-dark-error greeter-light-200 greeter-unavailable; do
  [[ -s "$report/$name.png" ]] || fail "Missing fixture render: $name"
  file --mime-type "$report/$name.png" | grep -Fq 'image/png' || fail "Fixture is not a PNG: $name"
done
if grep -E 'ReferenceError|TypeError|SyntaxError|[Ff]ailed to load|[Bb]inding loop|Cannot assign|Unable to assign|image write failed' "$report/runtime.log"; then
  fail 'Native greeter source rendering reported a runtime error'
fi
printf 'Native offscreen greeter renders written to %s; inspect PNGs. No installed acceptance is implied.\n' "$report"
