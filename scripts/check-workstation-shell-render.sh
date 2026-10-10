#!/usr/bin/env bash
# A bounded, disposable preview on the current Hyprland display. No live actions.
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ $# == 1 && "$1" == /* ]] || fail 'Usage: bash scripts/check-workstation-shell-render.sh /ABSOLUTE/NEW-REPORT-DIRECTORY'
report="$1"
[[ ! -e "$report" ]] || fail 'Report directory already exists'
case "$(realpath -m -- "$report")/" in "$repo_dir/"*) fail 'Render reports must stay outside the working tree' ;; esac
for command in qs jq hyprctl grim magick resvg; do
  command -v "$command" >/dev/null || fail "Missing rendering prerequisite: $command"
done
[[ -n "${WAYLAND_DISPLAY:-}" && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || fail 'Run inside the graphical Hyprland account'
umask 077
mkdir -m0700 -- "$report"
scratch="$(mktemp -d)"
shell_pid=''
cleanup() {
  if [[ -n "$shell_pid" ]]; then kill "$shell_pid" 2>/dev/null || true; wait "$shell_pid" 2>/dev/null || true; fi
  rm -rf -- "$scratch"
}
trap cleanup EXIT
mkdir -p -- "$scratch/config" "$scratch/state" "$scratch/cache"
cp -a -- "$repo_dir/.config/quickshell/workstation" "$scratch/config/workstation"
BLENDOS_WORKSTATION_THEME_STATE_HOME="$scratch/state" \
  BLENDOS_WORKSTATION_THEME_CONFIG_HOME="$scratch/config" \
  BLENDOS_WORKSTATION_THEME_BUILTIN_HOME="$repo_dir/themes" \
  bash "$repo_dir/bin/workstation-theme" set catppuccin-mocha --no-reload > "$report/theme.log"
title="Workstation render check $$"
env WORKSTATION_SHELL_PREVIEW=1 WORKSTATION_SHELL_PREVIEW_TITLE="$title" \
  QML_IMPORT_PATH="$repo_dir/.config/quickshell${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" \
  WORKSTATION_SHELL_FIXTURE="$repo_dir/scripts/fixtures/workstation-shell/preview.json" \
  XDG_STATE_HOME="$scratch/state" XDG_CACHE_HOME="$scratch/cache" \
  QT_QUICK_CONTROLS_STYLE=Basic QT_QUICK_BACKEND=software \
  qs -p "$scratch/config/workstation" > "$report/runtime.log" 2>&1 &
shell_pid=$!
client=''
for ((attempt=0; attempt<100; attempt++)); do
  kill -0 "$shell_pid" 2>/dev/null || { cat "$report/runtime.log" >&2; fail 'Quickshell exited before rendering'; }
  client="$(hyprctl -j clients | jq -c --arg title "$title" '[.[] | select(.title == $title and .mapped == true)] | if length == 1 then .[0] else empty end')"
  [[ -z "$client" ]] || break
  sleep 0.1
done
[[ -n "$client" ]] || fail 'No mapped fixture window before timeout'
address="$(jq -r .address <<< "$client")"
[[ "$address" =~ ^0x[[:xdigit:]]+$ ]] || fail 'Invalid fixture window address'
hyprctl dispatch "hl.dsp.focus({ window = 'address:$address' })" > "$report/focus.log"
sleep 0.3
geometry="$(jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' <<< "$client")"
grim -g "$geometry" "$report/window.png"
read -r width height colors < <(magick identify -format '%w %h %k\n' "$report/window.png")
((width >= 500 && height >= 400 && colors > 16)) || fail 'Window capture is empty, undersized or uniform'
pixel="$(magick "$report/window.png" -format '%[hex:p{10,80}]' info:)"
[[ "${pixel:0:6}" == 1E1E2E ]] || fail 'Dark theme background did not reach rendered pixels'

# Render a complete private light theme through the same owner, then reload
# this exact process across the atomic pointer switch.
private_theme="$scratch/config/blendos-workstation/themes/render-light"
mkdir -p -- "$private_theme"
cp -a -- "$repo_dir/themes/catppuccin-mocha/." "$private_theme/"
jq '.id = "render-light" | .name = "Render Light" | .mode = "light" |
  .colors.background = "#ffffff" | .colors.background_alt = "#eeeeee" |
  .colors.surface = "#dddddd" | .colors.surface_alt = "#cccccc" |
  .colors.foreground = "#111111" | .colors.foreground_muted = "#555555" |
  .colors.selection = "#bbccee" | .colors.muted = "#777777" | .colors.accent = "#0055aa"' \
  "$private_theme/theme.json" > "$scratch/light.json"
mv -- "$scratch/light.json" "$private_theme/theme.json"
BLENDOS_WORKSTATION_THEME_STATE_HOME="$scratch/state" \
  BLENDOS_WORKSTATION_THEME_CONFIG_HOME="$scratch/config" \
  BLENDOS_WORKSTATION_THEME_BUILTIN_HOME="$repo_dir/themes" \
  bash "$repo_dir/bin/workstation-theme" set render-light --no-reload >> "$report/theme.log"
qs -p "$scratch/config/workstation" ipc call -- theme reload >/dev/null
for ((attempt=0; attempt<50; attempt++)); do
  [[ "$(qs -p "$scratch/config/workstation" ipc call -- theme current)" != render-light ]] || break
  sleep 0.1
done
sleep 0.3
grim -g "$geometry" "$report/window-light.png"
pixel="$(magick "$report/window-light.png" -format '%[hex:p{10,80}]' info:)"
[[ "${pixel:0:6}" == FFFFFF ]] || fail 'Light theme reload did not reach rendered pixels'
if grep -E '(^|[[:space:]])ERROR([^[:alpha:]]|$)|ReferenceError|TypeError|SyntaxError|[Ff]ailed to load|[Bb]inding loop|Cannot assign|Unable to assign' "$report/runtime.log"; then
  fail 'Quickshell reported a runtime error'
fi
printf 'Rendered %s x %s fixture with %s colors; atomic dark/light palette switch reached pixels. Inspect PNGs in %s.\n' "$width" "$height" "$colors" "$report"
