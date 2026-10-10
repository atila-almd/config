#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

fixture="$test_dir/repository"
mkdir -p -- "$fixture"
bash "$repo_dir/scripts/copy-source-fixture.sh" "$repo_dir" "$fixture"

hypr_config="$fixture/.config/hypr/hyprland.lua"
sed -i '/hl.bind(mainMod \.\. " + CTRL + L", hl.dsp.exec_cmd("session-lock"))/d' "$hypr_config"

if output="$(bash "$fixture/scripts/validate-component-contract.sh" 2>&1)"; then
  fail 'component contract accepted a lock capability without a binding'
fi
grep -Fq "lock-screen expects a Hyprland binding using 'session-lock'" <<<"$output" ||
  fail 'missing lock binding produced the wrong validation error'

cp -- "$repo_dir/.config/hypr/hyprland.lua" "$hypr_config"
sed -i '/workstation-theme choose/d' "$hypr_config"

if output="$(bash "$fixture/scripts/validate-component-contract.sh" 2>&1)"; then
  fail 'component contract accepted a theme capability without a binding'
fi
grep -Fq "theme-keybinding expects a Hyprland binding using 'workstation-theme'" <<<"$output" ||
  fail 'missing theme binding produced the wrong validation error'

cp -- "$repo_dir/.config/hypr/hyprland.lua" "$hypr_config"
sed -i "/^services:/,/^user-services:/ { /^  - 'ufw'$/d; }" "$fixture/system.yaml"

if output="$(bash "$fixture/scripts/validate-component-contract.sh" 2>&1)"; then
  fail 'component contract accepted a host firewall without its system service'
fi
grep -Fq "host-firewall expects 'ufw' in system.yaml services" <<<"$output" ||
  fail 'missing firewall service produced the wrong validation error'

cp -- "$repo_dir/system.yaml" "$fixture/system.yaml"
sed -i 's|image/png=imv.desktop|image/png=missing.desktop|' "$fixture/.config/mimeapps.list"
if output="$(bash "$fixture/scripts/validate-component-contract.sh" 2>&1)"; then
  fail 'component contract accepted an undeclared image default'
fi
grep -Fq "uses undeclared desktop entry 'missing.desktop'" <<<"$output" ||
  fail 'undeclared MIME default produced the wrong validation error'
cp -- "$repo_dir/.config/mimeapps.list" "$fixture/.config/mimeapps.list"

sed -i 's/session-terminal -e btop/session-terminal -e missing-tool/' "$fixture/.config/elephant/menus/workstation-tools.toml"
if output="$(bash "$fixture/scripts/validate-workstation-controls.sh" 2>&1)"; then
  fail 'workstation controls accepted an undeclared nested terminal command'
fi
grep -Fq 'missing-tool is not declared' <<<"$output" ||
  fail 'undeclared menu action produced the wrong validation error'

printf 'component contract tests passed.\n'
