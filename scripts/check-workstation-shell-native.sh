#!/usr/bin/env bash
# Actual Quickshell loader smoke check on a private headless Weston display.
# Weston lacks the selected lock protocol; this cannot establish lock acceptance.
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
for command in qs timeout jq weston dbus-run-session; do command -v "$command" >/dev/null || fail "Missing native prerequisite: $command"; done
runtime="$(mktemp -d)"
compositor_pid=''
cleanup() {
  if [[ -n "$compositor_pid" ]]; then kill "$compositor_pid" 2>/dev/null || true; wait "$compositor_pid" 2>/dev/null || true; fi
  rm -rf -- "$runtime"
}
trap cleanup EXIT
umask 077
mkdir -p "$runtime/state/blendos-workstation/theme/current" "$runtime/config"
jq '{schema_version:1,theme_id:.id,release_id:"native-fixture",mode:.mode,colors:.colors}' \
  "$repo_dir/themes/catppuccin-mocha/theme.json" > "$runtime/state/blendos-workstation/theme/current/workstation-shell.json"
export QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic
export XDG_RUNTIME_DIR="$runtime" XDG_STATE_HOME="$runtime/state" XDG_CACHE_HOME="$runtime/cache"
export QML_IMPORT_PATH="$repo_dir/.config/quickshell${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
export QS_DISABLE_CRASH_HANDLER=1 WORKSTATION_SHELL_PANEL_ONLY=1
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
mkdir "$runtime/desktop"
cp -- "$repo_dir/.config/quickshell/workstation/adapters/Desktop.qml" "$runtime/desktop/"
cp -- "$repo_dir/scripts/fixtures/workstation-desktop/shell.qml" "$runtime/desktop/shell.qml"
dbus-run-session -- env QT_QPA_PLATFORM=offscreen timeout 5 qs -p "$runtime/desktop" > "$runtime/desktop.log" 2>&1 || { cat "$runtime/desktop.log" >&2; fail 'Native desktop adapter initialization failed'; }
grep -Fq 'Native desktop snapshot initialized' "$runtime/desktop.log" || { cat "$runtime/desktop.log" >&2; fail 'Native desktop adapter fixture did not complete'; }
mkdir "$runtime/gate"
cp -- "$repo_dir/.config/quickshell/workstation-lock/UnlockGate.qml" "$runtime/gate/"
cp -- "$repo_dir/scripts/fixtures/workstation-unlock-gate/shell.qml" "$runtime/gate/shell.qml"
QT_QPA_PLATFORM=offscreen timeout 5 qs -p "$runtime/gate" > "$runtime/gate.log" 2>&1 || { cat "$runtime/gate.log" >&2; fail 'Native unlock gate failure handling failed'; }
grep -Fq 'Unlock gate native success/failure/start-failure/retry passed' "$runtime/gate.log" || { cat "$runtime/gate.log" >&2; fail 'Unlock gate fixture did not complete'; }
mkdir "$runtime/controls"
cp -a -- "$repo_dir/.config/quickshell/workstation/adapters" "$repo_dir/.config/quickshell/workstation/models" "$runtime/controls/"
cp -- "$repo_dir/scripts/fixtures/workstation-controls-native/shell.qml" "$runtime/controls/shell.qml"
export WORKSTATION_CONTROL_FIXTURE_HELPER="$repo_dir/scripts/fixtures/workstation-controls-native/helper.sh"
dbus-run-session -- env QT_QPA_PLATFORM=offscreen timeout 8 qs -p "$runtime/controls" > "$runtime/controls.log" 2>&1 || { cat "$runtime/controls.log" >&2; fail 'Native control fixture failed'; }
grep -Fq 'Native control protocol, stale capabilities, serialization, hidden completion and section lifecycle passed' "$runtime/controls.log" || { cat "$runtime/controls.log" >&2; fail 'Native controls fixture did not complete'; }
weston --backend=headless --renderer=pixman --shell=kiosk-shell.so --no-config \
  --idle-time=0 --socket=workstation-fixture > "$runtime/weston.log" 2>&1 &
compositor_pid=$!
for ((attempt=0; attempt<100; attempt++)); do
  [[ ! -S "$runtime/workstation-fixture" ]] || break
  kill -0 "$compositor_pid" 2>/dev/null || { cat "$runtime/weston.log" >&2; fail 'Fixture compositor stopped'; }
  sleep 0.05
done
[[ -S "$runtime/workstation-fixture" ]] || fail 'Fixture compositor did not become ready'
export WAYLAND_DISPLAY=workstation-fixture
status=0
timeout 2 qs -p "$repo_dir/.config/quickshell/workstation" > "$runtime/shell.log" 2>&1 || status=$?
[[ "$status" == 124 ]] || { cat "$runtime/shell.log" >&2; fail 'Fixture shell did not stay resident'; }
grep -Fq 'Configuration Loaded' "$runtime/shell.log" || { cat "$runtime/shell.log" >&2; fail 'Shell source did not load'; }
status=0
WORKSTATION_SHELL_PREVIEW=1 WORKSTATION_SHELL_PREVIEW_CONTROLS=1 WORKSTATION_SHELL_FIXTURE="$repo_dir/scripts/fixtures/workstation-shell/controls-preview.json" \
  timeout 2 qs -p "$repo_dir/.config/quickshell/workstation" > "$runtime/preview-controls.log" 2>&1 || status=$?
[[ "$status" == 124 ]] || { cat "$runtime/preview-controls.log" >&2; fail 'Control preview did not stay resident'; }
grep -Fq 'Configuration Loaded' "$runtime/preview-controls.log" || { cat "$runtime/preview-controls.log" >&2; fail 'Control preview did not load'; }
cp -- "$runtime/state/blendos-workstation/theme/current/workstation-shell.json" "$runtime/valid-theme.json"
printf '{}\n' > "$runtime/state/blendos-workstation/theme/current/workstation-shell.json"
status=0
timeout 3 qs -p "$repo_dir/.config/quickshell/workstation" > "$runtime/invalid-theme.log" 2>&1 || status=$?
[[ "$status" == 1 ]] && grep -Fq 'Initial workstation theme is invalid' "$runtime/invalid-theme.log" || { cat "$runtime/invalid-theme.log" >&2; fail 'Invalid initial theme did not fail startup'; }
rm -- "$runtime/state/blendos-workstation/theme/current/workstation-shell.json"
status=0
timeout 3 qs -p "$repo_dir/.config/quickshell/workstation" > "$runtime/missing-theme.log" 2>&1 || status=$?
[[ "$status" == 1 ]] && grep -Fq 'Workstation theme unavailable' "$runtime/missing-theme.log" || { cat "$runtime/missing-theme.log" >&2; fail 'Missing initial theme did not fail startup'; }
cp -- "$runtime/valid-theme.json" "$runtime/state/blendos-workstation/theme/current/workstation-shell.json"
status=0
timeout 12 qs -p "$repo_dir/.config/quickshell/workstation-lock" > "$runtime/lock.log" 2>&1 || status=$?
[[ "$status" != 0 && "$status" != 124 ]] || { cat "$runtime/lock.log" >&2; fail 'Locker did not explicitly reject unavailable Wayland locking'; }
grep -Eq 'does not support.*ext-session-lock|refused or ended lock acquisition|lock acknowledgement timed out' "$runtime/lock.log" || { cat "$runtime/lock.log" >&2; fail 'Missing lock acquisition failure'; }
if grep -E 'Failed to load configuration|ReferenceError|TypeError|SyntaxError|[Bb]inding loop|Cannot assign|Unable to assign' "$runtime/shell.log" "$runtime/lock.log" "$runtime/desktop.log" "$runtime/controls.log" "$runtime/preview-controls.log"; then
  fail 'Actual Quickshell roots reported a source/runtime error'
fi
printf 'Native shell root/module loaded; locker root/module rejected unavailable Wayland protection. No installed acceptance is implied.\n'
