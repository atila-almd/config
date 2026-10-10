#!/usr/bin/env bash
# Native Quickshell/socket/theme integration in private fixture state.
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
for command in qs go jq resvg dbus-daemon; do
  command -v "$command" >/dev/null || fail "Missing native prerequisite: $command"
done
[[ -n "${WAYLAND_DISPLAY:-}" && -n "${XDG_RUNTIME_DIR:-}" && -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] || fail 'Run in the graphical account'
case "$WAYLAND_DISPLAY" in /*) ;; *) export WAYLAND_DISPLAY="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ;; esac
scratch="$(mktemp -d)"
data_pid='' shell_pid=''
cleanup() {
  for pid in "$shell_pid" "$data_pid"; do
    [[ -z "$pid" ]] || { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }
  done
  rm -rf -- "$scratch"
}
trap cleanup EXIT
mkdir -m0700 -- "$scratch/runtime" "$scratch/state" "$scratch/config" "$scratch/cache" "$scratch/project"
export XDG_RUNTIME_DIR="$scratch/runtime" XDG_STATE_HOME="$scratch/state" XDG_CACHE_HOME="$scratch/cache"
export PATH="$repo_dir/bin:$PATH" QT_QUICK_CONTROLS_STYLE=Basic QT_QUICK_BACKEND=software
export WORKSTATION_SHELL_SHOW_PANEL=1 WORKSTATION_SHELL_PANEL_ONLY=1
export QML_IMPORT_PATH="$repo_dir/.config/quickshell${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
unset WORKSTATION_SHELL_PREVIEW BLENDOS_WORKSTATION_PROJECT_STATE_HOME BLENDOS_WORKSTATION_AGENT_STATE_HOME
cp -a -- "$repo_dir/.config/quickshell/workstation" "$scratch/config/workstation"
export BLENDOS_WORKSTATION_THEME_STATE_HOME="$scratch/state" BLENDOS_WORKSTATION_THEME_CONFIG_HOME="$scratch/config"
export BLENDOS_WORKSTATION_THEME_BUILTIN_HOME="$repo_dir/themes"
bash "$repo_dir/bin/workstation-theme" set catppuccin-mocha --no-reload >/dev/null
bash "$repo_dir/scripts/build-workstation-data.sh" "$scratch/workstation-data"
start_data() {
  DBUS_SYSTEM_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" "$scratch/workstation-data" serve > "$scratch/data.log" 2>&1 &
  data_pid=$!
}
start_data
qs -p "$scratch/config/workstation" > "$scratch/shell.log" 2>&1 &
shell_pid=$!
ipc() { qs -p "$scratch/config/workstation" ipc call -- "$@"; }
expect_status() {
  local expression="$1" result=''
  for ((attempt=0; attempt<100; attempt++)); do
    kill -0 "$shell_pid" 2>/dev/null || { cat "$scratch/shell.log" >&2; fail 'Quickshell stopped'; }
    if result="$(ipc panel status 2>/dev/null)" && jq -e "$expression" <<< "$result" >/dev/null; then return; fi
    sleep 0.1
  done
  printf '%s\n' "$result" >&2
  cat "$scratch/shell.log" >&2
  fail "Panel did not reach expected status: $expression"
}
expect_status '.projects_status == "ready" and .project_count == 0 and .agent_runs_status == "ready"'
[[ ! -e "$scratch/state/blendos-workstation/projects" && ! -e "$scratch/state/blendos-workstation/agents" ]] || fail 'Empty reads created workflow state'
workstation-project add panel-fixture "$scratch/project" >/dev/null
expect_status '.projects_status == "ready" and .project_count == 1'
ipc panel hide >/dev/null
expect_status '.observing == false and .view_loaded == false and .project_count == 0'
ipc panel show >/dev/null
expect_status '.observing == true and .view_loaded == true and .project_count == 1'
expect_controls() {
  local expression="$1" result=''
  for ((attempt=0; attempt<100; attempt++)); do
    if result="$(ipc controls status 2>/dev/null)" && jq -e "$expression" <<< "$result" >/dev/null; then return; fi
    sleep 0.1
  done
  printf '%s\n' "$result" >&2
  fail "Controls did not reach expected status: $expression"
}
ipc controls section network >/dev/null
expect_controls '.observing and .view_loaded and (.native_loaded == false) and (.topics | sort) == ["agent_runs","appearance","network","projects"]'
ipc panel hide >/dev/null
expect_controls '(.topics | sort) == ["appearance","network"]'
expect_status '.observing == false and .project_count == 0'
ipc controls section settings >/dev/null
expect_controls '.section == "settings" and .topics == ["appearance"]'
ipc controls hide >/dev/null
expect_controls '.observing == false and .view_loaded == false and .native_loaded == false and .topics == []'
ipc panel show >/dev/null
expect_status '.projects_status == "ready" and .project_count == 1'
kill "$data_pid"
wait "$data_pid" || true
data_pid=''
expect_status '.projects_status == "Disconnected" and .project_count == 0'
start_data
expect_status '.projects_status == "ready" and .project_count == 1'
private_theme="$scratch/config/blendos-workstation/themes/panel-light"
mkdir -p "$private_theme"
cp -a "$repo_dir/themes/catppuccin-mocha/." "$private_theme/"
jq '.id = "panel-light" | .name = "Panel Light" | .mode = "light" |
  .colors.background = "#ffffff" | .colors.foreground = "#111111"' \
  "$private_theme/theme.json" > "$scratch/theme.json"
mv "$scratch/theme.json" "$private_theme/theme.json"
workstation-theme set panel-light --no-reload >/dev/null
ipc theme reload >/dev/null
expect_status '.theme_id == "panel-light"'
expected_release="$(jq -r '.release_id' "$scratch/state/blendos-workstation/theme/current/workstation-shell.json")"
[[ "$(ipc theme release)" == "$expected_release" ]] || fail 'Theme IPC did not acknowledge the exact release'
workstation-project remove panel-fixture >/dev/null
expect_status '.projects_status == "ready" and .project_count == 0'
if grep -E '(^|[[:space:]])ERROR([^[:alpha:]]|$)|ReferenceError|TypeError|SyntaxError|[Ff]ailed to load|[Bb]inding loop|Cannot assign|Unable to assign' "$scratch/shell.log"; then
  fail 'Quickshell reported a runtime error'
fi
ipc panel close >/dev/null
expect_status '.observing == false and .view_loaded == false and .window_visible == false'
kill "$shell_pid"
wait "$shell_pid" || true
shell_pid=''
printf 'Native socket updates, read-only state, hide/show, reconnect and atomic theme reload passed.\n'
