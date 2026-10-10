#!/usr/bin/env bash
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
runner="${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner}"
[[ -x "$runner" ]] || { printf 'Qt Quick Test unavailable: %s\n' "$runner" >&2; exit 1; }
runtime="$(mktemp -d)"
trap 'rm -rf -- "$runtime"' EXIT
report="$runtime"
if [[ $# == 2 && "$1" == --render ]]; then
  report="$2"
  [[ "$report" == /* ]] || { printf 'Render directory must be absolute.\n' >&2; exit 2; }
  report="$(realpath -m -- "$report")"
  case "$report/" in "$repo_dir/"*) printf 'Render reports must stay outside the working tree.\n' >&2; exit 2 ;; esac
  [[ ! -e "$report" ]] || { printf 'Render directory already exists.\n' >&2; exit 1; }
  mkdir -m 700 -- "$report"
elif (($#)); then
  printf 'Usage: test-workstation-control-center.sh [--render NEW_ABSOLUTE_DIRECTORY]\n' >&2
  exit 2
fi
export XDG_RUNTIME_DIR="$runtime" QT_QUICK_CONTROLS_STYLE=Basic QT_QUICK_BACKEND=software
cd -- "$report"
"$runner" -platform offscreen -import "$repo_dir/.config/quickshell" -input "$repo_dir/scripts/fixtures/workstation-control-center"
printf 'Pure control-center fixtures passed; rendered states: %s\n' "$report"
