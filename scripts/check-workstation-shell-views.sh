#!/usr/bin/env bash
# Native Qt/Quickshell offscreen source rendering, never installed acceptance.
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ $# == 1 && "$1" == /* ]] || fail 'Usage: bash scripts/check-workstation-shell-views.sh /ABSOLUTE/NEW-REPORT-DIRECTORY'
report="$(realpath -m -- "$1")"
[[ ! -e "$report" ]] || fail 'Report directory already exists'
case "$report/" in "$repo_dir/"*) fail 'Reports must stay outside the working tree' ;; esac
command -v qs >/dev/null || fail 'Native Quickshell is required'
command -v timeout >/dev/null || fail 'timeout is required'
umask 077
mkdir -m0700 -- "$report"
runtime="$(mktemp -d)"
trap 'rm -rf -- "$runtime"' EXIT
cp -a -- "$repo_dir/.config/quickshell/workstation" "$runtime/config"
cp -- "$repo_dir/scripts/fixtures/workstation-views/shell.qml" "$runtime/config/shell.qml"
for view_case in 0 1 2 3 4; do
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic \
  XDG_RUNTIME_DIR="$runtime" XDG_STATE_HOME="$runtime/state" XDG_CACHE_HOME="$runtime/cache" \
  QML_IMPORT_PATH="$repo_dir/.config/quickshell${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" \
  WORKSTATION_THEME_FIXTURE="$repo_dir/themes/catppuccin-mocha/theme.json" \
  WORKSTATION_VIEW_REPORT="$report" \
  WORKSTATION_VIEW_CASE="$view_case" \
  timeout 20 qs -p "$runtime/config" >> "$report/runtime.log" 2>&1
done
for name in bar-wide-dark bar-narrow-dark auth-dark auth-light bar-default-dark; do
  [[ -s "$report/$name.png" ]] || fail "Missing fixture render: $name"
done
if grep -E 'ReferenceError|TypeError|SyntaxError|[Ff]ailed to load|[Bb]inding loop|Cannot assign|Unable to assign|image write failed' "$report/runtime.log"; then
  fail 'Native source rendering reported a runtime error'
fi
printf 'Native offscreen bar/auth renders written to %s; inspect PNGs. No installed acceptance is implied.\n' "$report"
