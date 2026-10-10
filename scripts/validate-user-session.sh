#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
unit_dir="$repo_dir/.config/systemd/user"
target='blendos-workstation-session.target'
target_file="$unit_dir/$target"
check_installed=false
errors=0

if [[ "${1:-}" == '--installed' ]]; then
  check_installed=true
elif (($#)); then
  printf 'Usage: bash scripts/validate-user-session.sh [--installed]\n' >&2
  exit 2
fi

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  errors=$((errors + 1))
}

expect_line() {
  local file="$1"
  local line="$2"
  grep -Fxq "$line" "$file" || fail "$(basename "$file") is missing: $line"
}

services=(
  'awww-daemon.service'
  'dunst.service'
  'elephant.service'
  'hyprpolkitagent.service'
  'walker.service'
  'wallpaper-restore.service'
  'wl-clip-persist.service'
)
services+=(workstation-launcher.service)

expect_line "$target_file" 'After=wayland-session@workstation.desktop.target workstation-lock-guard.service'
expect_line "$target_file" 'PartOf=wayland-session@workstation.desktop.target'
expect_line "$target_file" 'Conflicts=wayland-session-shutdown.target'
expect_line "$target_file" 'Before=wayland-session-shutdown.target'
expect_line "$target_file" 'WantedBy=wayland-session@workstation.desktop.target'
expect_line "$target_file" 'Requires=workstation-lock-guard.service'
expect_line "$repo_dir/.local/share/wayland-sessions/workstation.desktop" 'Exec=Hyprland'
expect_line "$repo_dir/system.yaml" "  - 'greetd'"
expect_line "$repo_dir/system.yaml" "  - 'greetd.service'"
if grep -Eq "^[[:space:]]+- 'ly(@|')" "$repo_dir/system.yaml"; then
  fail 'Ly remains declared after the greetd migration'
fi
if grep -Fq 'workstation-uwsm.desktop' "$repo_dir/system.yaml"; then
  fail 'obsolete generated Ly/UWSM session route remains'
fi
expect_line "$unit_dir/workstation-data.service" "PartOf=$target"
expect_line "$unit_dir/workstation-data.service" "After=$target"
expect_line "$unit_dir/workstation-shell.service" "After=$target"
expect_line "$unit_dir/workstation-launcher.service" "After=$target"
# The target's required guard must not propagate an automatic crash restart to
# the independent locker, and its acknowledged inhibitor must survive that crash.
for setting in 'Type=notify' 'Restart=on-failure' 'RestartMode=direct' \
  'StartLimitIntervalSec=0' 'FileDescriptorStoreMax=1' \
  'FileDescriptorStorePreserve=restart'; do
  expect_line "$unit_dir/workstation-lock-guard.service" "$setting"
done

# Replaced desktop owners have no second session, launch path or generated theme.
for retired in .config/noctalia/00-workstation.toml .config/waybar/config.jsonc \
  .config/systemd/user/blendos-desktop-session.target \
  .config/systemd/user/blendos-noctalia-session.target \
  .config/systemd/user/noctalia.service .local/share/wayland-sessions/noctalia.desktop \
  bin/session-noctalia bin/waybar-gpu-status bin/waybar-notifications \
  themes/templates/noctalia-palette.json.tpl themes/templates/noctalia-theme.toml.tpl \
  themes/templates/waybar.css.tpl themes/templates/hyprlock.conf.tpl; do
  [[ ! -e "$repo_dir/$retired" ]] || fail "retired desktop source remains: $retired"
done
if grep -Eq "^[[:space:]]+- '(noctalia|waybar|hyprlock)'" "$repo_dir/system.yaml"; then
  fail 'a retired desktop package remains declared'
fi
if grep -Eq 'BLENDOS_DESKTOP_SHELL|noctalia|exec-once' "$repo_dir/.config/uwsm/env" "$repo_dir/.config/hypr/hyprland.lua"; then
  fail 'compositor or environment retains a shell selector or competing launch path'
fi
expect_line "$repo_dir/.config/hypr/hypridle.conf" '    inhibit_sleep = 3'
expect_line "$repo_dir/.config/hypr/hypridle.conf" '    before_sleep_cmd = session-lock'
# Lua configurations evaluate dispatcher expressions, not legacy `dpms on/off`.
expect_line "$repo_dir/.config/hypr/hypridle.conf" "    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'"
expect_line "$repo_dir/.config/hypr/hypridle.conf" "    on-timeout = hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'"
expect_line "$repo_dir/.config/hypr/hypridle.conf" "    on-resume = hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'"
expect_line "$repo_dir/bin/session-lock" 'exec systemctl --user start workstation-lock.service'
grep -Fq 'workstation-suspend' "$repo_dir/bin/workstation-controls" ||
  fail 'power controls bypass compositor-confirmed suspend'

target_wants="$(sed -n 's/^Wants=//p' "$target_file")"
for unit in "${services[@]}"; do
  if [[ " $target_wants " != *" $unit "* ]]; then
    fail "$target does not want $unit"
  fi

  if [[ -f "$unit_dir/$unit" ]]; then
    managed_file="$unit_dir/$unit"
  elif [[ -f "$unit_dir/$unit.d/10-blendos-session.conf" ]]; then
    managed_file="$unit_dir/$unit.d/10-blendos-session.conf"
  else
    fail "no managed service or drop-in for $unit"
    continue
  fi

  expect_line "$managed_file" "PartOf=$target"
  expect_line "$managed_file" "After=$target"
  expect_line "$managed_file" 'ConditionEnvironment=WAYLAND_DISPLAY'
  expect_line "$managed_file" 'Slice=session-graphical.slice'
done

expect_line "$unit_dir/awww-daemon.service" 'ExecStart=/usr/bin/awww-daemon'
expect_line "$unit_dir/awww-daemon.service" 'ExecStop=/usr/bin/awww kill'
expect_line "$unit_dir/wl-clip-persist.service" 'ExecStart=/usr/bin/wl-clip-persist --clipboard regular --disable-timestamps'
vm_unit_dir="$repo_dir/profiles/vm/user"
expect_line "$vm_unit_dir/vboxclient-clipboard.service" 'ExecStart=/usr/bin/VBoxClient --session-type wayland --clipboard --foreground'
expect_line "$vm_unit_dir/vboxclient-vmsvga.service" 'ExecStart=/usr/bin/VBoxClient --session-type wayland --vmsvga-session --foreground'
expect_line "$vm_unit_dir/20-machine-profile.conf" 'Wants=vboxclient-clipboard.service vboxclient-vmsvga.service'
expect_line "$repo_dir/profiles/vm/autostart/vboxclient.desktop" 'Hidden=true'
grep -Fq 'profiles/vm/autostart/vboxclient.desktop' "$repo_dir/install.sh" || fail 'installer misses the vm autostart override'
grep -Fq 'vboxclient-vmsvga.service' "$repo_dir/install.sh" || fail 'installer misses vm display assistant'
if grep -q 'vboxclient' "$target_file"; then fail 'VM services leak into the common session target'; fi
expect_line "$unit_dir/elephant.service" 'ExecStart=/usr/bin/elephant'
expect_line "$unit_dir/walker.service" 'Requires=elephant.service'
expect_line "$unit_dir/walker.service" 'ExecStart=%h/.local/bin/blend_bin/session-walker --gapplication-service'
expect_line "$unit_dir/wallpaper-restore.service" 'Requires=awww-daemon.service'
expect_line "$unit_dir/wallpaper-restore.service" 'After=awww-daemon.service'

services+=(workstation-shell.service workstation-data.service workstation-lock-guard.service hypridle.service)
expect_line "$unit_dir/workstation-shell.service" "PartOf=$target"
expect_line "$unit_dir/workstation-lock.service" "PartOf=$target"
expect_line "$unit_dir/workstation-lock.service" 'Restart=on-failure'
if [[ "$check_installed" == true ]]; then
  installed_profile="$(cat /etc/blendos-workstation/machine-profile 2>/dev/null || true)"
  [[ -n "$installed_profile" ]] || fail 'no explicit installed Machine Profile'
  if [[ "$installed_profile" == vm ]]; then
    services+=(vboxclient-clipboard.service vboxclient-vmsvga.service)
  fi
  installed_units=("$target" "${services[@]}")
  if ! systemd-analyze --user verify "${installed_units[@]}"; then
    fail 'systemd rejected one or more installed user units'
  fi
  if ! systemctl --user is-enabled --quiet "$target"; then
    fail "$target is not enabled"
  fi
  if systemctl --user is-active --quiet graphical-session.target; then
    for unit in "$target" "${services[@]}"; do
      if ! systemctl --user is-active --quiet "$unit"; then
        fail "$unit is not active in the graphical session"
      fi
    done
    if systemctl --user is-active --quiet app-vboxclient@autostart.service; then
      fail 'upstream VBoxClient-all autostart competes with managed VirtualBox services'
    fi
  fi
fi

if ((errors)); then
  printf '\nUser-session validation failed with %d error(s).\n' "$errors" >&2
  exit 1
fi

printf 'User-session contract valid: %d services checked' "${#services[@]}"
if [[ "$check_installed" == true ]]; then
  printf ' against the installed system'
fi
printf '.\n'
