#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
target_home="${BLENDOS_WORKSTATION_TARGET_HOME:-$HOME}"
contract="$repo_dir/components.tsv"
system_config="$repo_dir/system.yaml"
hypr_config="$repo_dir/.config/hypr/hyprland.lua"
ghostty_config="$repo_dir/.config/ghostty/config.ghostty"
mime_config="$repo_dir/.config/mimeapps.list"
shell_config="$repo_dir/.zshrc"
shell_env_config="$repo_dir/.zshenv"
installer="$repo_dir/install.sh"
portless_docs="$repo_dir/services/portless/README.md"
user_unit_dir="$repo_dir/.config/systemd/user"
session_target="$user_unit_dir/blendos-workstation-session.target"
session_target_wants="$(sed -n 's/^Wants=//p' "$session_target")"
check_installed=false
installed_profile=''
errors=0

if [[ "${1:-}" == '--installed' ]]; then
  check_installed=true
  installed_profile="$(cat "${BLENDOS_WORKSTATION_PROFILE_FILE:-/etc/blendos-workstation/machine-profile}" 2>/dev/null || true)"
  [[ "$installed_profile" =~ ^[a-z][a-z0-9-]*$ ]] || {
    printf 'Installed Machine Profile is missing; run bootstrap first.\n' >&2
    exit 1
  }
elif (($#)); then
  printf 'Usage: bash scripts/validate-component-contract.sh [--installed]\n' >&2
  exit 2
fi

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  errors=$((errors + 1))
}

package_declared() {
  local package="$1"
  awk -v expected="  - '$package'" '
    /^(packages|aur-packages):$/ { in_packages = 1; next }
    in_packages && /^[^[:space:]#]/ { in_packages = 0 }
    in_packages && $0 == expected { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$system_config" "${profile_definition:-$system_config}"
}

system_service_declared() {
  local unit="$1"
  awk -v expected="  - '$unit'" '
    /^services:$/ { in_services = 1; next }
    in_services && /^[^[:space:]#]/ { in_services = 0 }
    in_services && $0 == expected { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$system_config"
}

executable_installed() {
  local executable="$1"
  if [[ "$executable" == /* ]]; then
    [[ -x "$executable" ]]
  else
    command -v -- "$executable" >/dev/null 2>&1
  fi
}

declare -A capabilities=()
declare -A hypr_binding_commands=()
declare -A hypr_variables=()
declare -A desktop_defaults=()

while IFS=$'\t' read -r capability package executable integration workflows profiles vm_status physical_status notes adaptation justification evidence extra; do
  [[ -z "$capability" || "$capability" == \#* ]] && continue

  if [[ -n "${extra:-}" || -z "$package" || -z "$executable" || -z "$integration" || -z "$workflows" || -z "$evidence" ]]; then
    fail "malformed component row for '$capability'"
    continue
  fi

  if [[ -n "${capabilities[$capability]:-}" ]]; then
    fail "duplicate capability '$capability'"
  fi
  capabilities[$capability]=1

  [[ "$check_installed" == false || "$profiles" == all || "$profiles" == "$installed_profile" ]] || continue
  profile_definition="$system_config"
  capability_unit_dir="$user_unit_dir"
  capability_wants="$session_target_wants"
  if [[ "$profiles" != all ]]; then
    profile_definition="$repo_dir/profiles/$profiles.yaml"
    capability_unit_dir="$repo_dir/profiles/$profiles/user"
    capability_wants+=" $(sed -n 's/^Wants=//p' "$capability_unit_dir/20-machine-profile.conf" 2>/dev/null || true)"
  fi

  if ! package_declared "$package"; then
    fail "$capability requires undeclared package '$package'"
  fi

  case "$integration" in
    hypr:var:*)
      variable="${integration##*:}"
      hypr_variables[$variable]="$executable"
      if ! grep -Fq "local $variable = \"$executable\"" "$hypr_config"; then
        fail "$capability expects Hyprland variable '$variable' to use '$executable'"
      fi
      ;;
    hypr:binding)
      hypr_binding_commands[$executable]=1
      if ! sed -n 's/.*hl\.dsp\.exec_cmd("\([^" ]*\).*/\1/p' "$hypr_config" | grep -Fxq -- "$executable"; then
        fail "$capability expects a Hyprland binding using '$executable'"
      fi
      if [[ -f "$repo_dir/bin/$executable" ]]; then
        if ! grep -Fq -- "$executable" "$installer"; then
          fail "$capability helper '$executable' is not deployed by the installer"
        fi
      fi
      ;;
    helper:*)
      helper_name="${integration#helper:}"
      if [[ "$helper_name" != "$executable" || ! -f "$repo_dir/bin/$helper_name" ]]; then
        fail "$capability expects project helper '$helper_name'"
      elif ! grep -Fq -- "$helper_name" "$installer"; then
        fail "$capability helper '$helper_name' is not deployed by the installer"
      fi
      if [[ "$check_installed" == true && ! -x "$target_home/.local/bin/blend_bin/$helper_name" ]]; then
        fail "$capability helper is not installed: $helper_name"
      fi
      ;;
    menu:*)
      menu_file="${integration#menu:}"
      menu_path="$repo_dir/.config/elephant/menus/$menu_file"
      if [[ ! -f "$menu_path" ]] || ! grep -Fq -- "$executable" "$menu_path"; then
        fail "$capability expects '$executable' in menu '$menu_file'"
      fi
      if ! grep -Fq -- "'.config/elephant/menus/$menu_file'" "$installer"; then
        fail "$capability menu '$menu_file' is not deployed by the installer"
      fi
      if [[ -f "$repo_dir/bin/$executable" ]] && ! grep -Fq -- "$executable" "$installer"; then
        fail "$capability helper '$executable' is not deployed by the installer"
      fi
      ;;
    xdg-default:*)
      desktop_file="${integration#xdg-default:}"
      desktop_defaults[$desktop_file]=1
      if ! grep -Fq "=$desktop_file" "$mime_config"; then
        fail "$capability expects '$desktop_file' in the MIME defaults"
      fi
      if [[ "$check_installed" == true && ! -f "/usr/share/applications/$desktop_file" ]]; then
        fail "$capability desktop file is not installed: $desktop_file"
      fi
      ;;
    xdg-autostart:*)
      desktop_file="${integration#xdg-autostart:}"
      if [[ "$check_installed" == true && ! -f "/etc/xdg/autostart/$desktop_file" ]]; then
        fail "$capability autostart file is not installed: $desktop_file"
      fi
      ;;
    rootless-user:*)
      unit="${integration#rootless-user:}"
      if ! grep -Eq "^[[:space:]]+- '$unit'[[:space:]]*$" "$system_config"; then
        fail "$capability expects '$unit' in system.yaml user-services"
      fi
      if ! grep -Fq 'sockets.target.wants/podman.socket' "$installer"; then
        fail "$capability expects the installer to enable the rootless Podman socket"
      fi
      if ! grep -Fq 'XDG_RUNTIME_DIR:-/run/user/$UID}/podman/podman.sock' "$shell_env_config"; then
        fail "$capability expects DOCKER_HOST to use the per-user Podman socket"
      fi
      if [[ "$check_installed" == true ]]; then
        if ! systemctl --user is-enabled --quiet "$unit"; then
          fail "$capability user unit is not enabled: $unit"
        fi
        if ! systemctl --user is-active --quiet "$unit"; then
          fail "$capability user unit is not active: $unit"
        fi
      fi
      ;;
    podman:compose-provider)
      if grep -Eq "^[[:space:]]+- '(docker-compose|podman-docker)'[[:space:]]*$" "$system_config"; then
        fail "$capability must not retain Docker compatibility packages"
      fi
      grep -Fq 'portless-compose intranet' "$portless_docs" ||
        fail "$capability expects a documented Portless/Podman Compose workflow"
      ;;
    systemd-user:*)
      unit="${integration#systemd-user:}"
      if [[ ! -f "$capability_unit_dir/$unit" && ! -d "$capability_unit_dir/$unit.d" ]]; then
        fail "$capability expects a managed unit or drop-in for '$unit'"
      fi
      if [[ " $capability_wants " != *" $unit "* ]]; then
        fail "$capability expects '$unit' in blendos-workstation-session.target"
      fi
      if [[ -f "$repo_dir/bin/$executable" ]] && ! grep -Fq -- "$executable" "$installer"; then
        fail "$capability helper '$executable' is not deployed by the installer"
      fi
      ;;
    dbus-user:*)
      unit="${integration#dbus-user:}"
      if [[ "$check_installed" == true ]] && ! systemctl --user cat "$unit" >/dev/null 2>&1; then
        fail "$capability D-Bus user unit is unavailable: $unit"
      fi
      ;;
    system-service:*)
      unit="${integration#system-service:}"
      if ! system_service_declared "$unit"; then
        fail "$capability expects '$unit' in system.yaml services"
      fi
      if [[ "$check_installed" == true ]]; then
        if ! systemctl is-enabled --quiet "$unit"; then
          fail "$capability system unit is not enabled: $unit"
        fi
        if ! systemctl is-active --quiet "$unit"; then
          fail "$capability system unit is not active: $unit"
        fi
      fi
      ;;
    *)
      fail "$capability has unknown integration '$integration'"
      ;;
  esac

  if [[ "$check_installed" == true ]] && ! executable_installed "$executable"; then
    fail "$capability executable is not installed: $executable"
  fi
done < "$contract"

# Every managed association must have a declared package and desktop entry.
# On the guest, verify effective defaults too: another config can override ours.
while IFS='=' read -r mime_type desktop_file; do
  [[ -n "$mime_type" && -n "$desktop_file" ]] || continue
  desktop_file="${desktop_file%%;*}"
  if [[ -z "${desktop_defaults[$desktop_file]:-}" ]]; then
    fail "MIME default '$mime_type' uses undeclared desktop entry '$desktop_file'"
  fi
  if [[ "$check_installed" == true ]]; then
    actual_default="$(xdg-mime query default "$mime_type" 2>/dev/null || true)"
    [[ "$actual_default" == "$desktop_file" ]] ||
      fail "MIME default '$mime_type' resolves to '$actual_default', expected '$desktop_file'"
  fi
done < <(awk '
  /^\[Default Applications\]$/ { defaults = 1; next }
  /^\[/ { defaults = 0 }
  defaults && /^[^#[:space:]][^=]*=/ { print }
' "$mime_config")

while IFS= read -r command; do
  [[ -z "$command" ]] && continue
  if [[ -z "${hypr_binding_commands[$command]:-}" ]]; then
    fail "Hyprland uses undeclared command '$command' in an exec binding"
  fi
done < <(sed -n 's/.*hl\.dsp\.exec_cmd("\([^" ]*\).*/\1/p' "$hypr_config" | sort -u)

while IFS= read -r variable; do
  [[ -z "$variable" ]] && continue
  if [[ -z "${hypr_variables[$variable]:-}" ]]; then
    fail "Hyprland uses undeclared command variable '$variable'"
  fi
done < <(sed -n 's/.*hl\.dsp\.exec_cmd(\([A-Za-z_][A-Za-z0-9_]*\)).*/\1/p' "$hypr_config" | sort -u)

if grep -Eq "alias (docker|docker-compose)=" "$shell_config"; then
  fail 'shell aliases must not obscure the Podman-native command contract'
fi

if [[ ! -s "$ghostty_config" ]]; then
  fail 'the terminal capability requires a managed Ghostty configuration'
fi
if ! grep -Fq "'.config/ghostty'" "$installer"; then
  fail 'the installer does not deploy the managed Ghostty configuration'
fi
if [[ "$check_installed" == true ]] && ! ghostty +show-config >/dev/null 2>&1; then
  fail 'Ghostty rejected the installed configuration'
fi

if ((errors)); then
  printf '\nComponent contract failed with %d error(s).\n' "$errors" >&2
  exit 1
fi

printf 'Component contract valid: %d capabilities checked' "${#capabilities[@]}"
if [[ "$check_installed" == true ]]; then
  printf ' against the installed system'
fi
printf '.\n'
