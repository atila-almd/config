#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
identity_dir="$repo_dir/services/desktop/identity"
system_config="$repo_dir/system.yaml"
installer="$repo_dir/install.sh"
components="$repo_dir/components.tsv"
check_installed=false
errors=0

if [[ "${1:-}" == '--installed' ]]; then
  check_installed=true
elif (($#)); then
  printf 'Usage: bash scripts/validate-desktop-identity.sh [--installed]\n' >&2
  exit 2
fi

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  errors=$((errors + 1))
}

expect_file() {
  local path="$1"
  [[ -s "$path" ]] || fail "missing identity source: ${path#"$repo_dir/"}"
}

package_declared() {
  local package="$1"
  awk -v expected="  - '$package'" '
    /^(packages|aur-packages):$/ { in_packages = 1; next }
    in_packages && /^[^[:space:]#]/ { in_packages = 0 }
    in_packages && $0 == expected { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$system_config"
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

identity_files=(
  GreeterContract.js
  GreeterView.qml
  KeyboardState.qml
  shell.qml
  greeter-host
  greeter-ui
  hyprland.lua
  hyprland-vm.lua
  mark-dark.svg
  mark-light.svg
  public-theme.jq
)
for file in "${identity_files[@]}"; do
  expect_file "$identity_dir/$file"
done
for file in AuthForm.qml Contract.js ThemedPane.qml qmldir; do
  expect_file "$repo_dir/.config/quickshell/WorkstationShared/$file"
done

package_declared greetd || fail "system.yaml does not declare package 'greetd'"
package_declared quickshell || fail "system.yaml does not declare package 'quickshell'"
package_declared hyprland || fail "system.yaml does not declare package 'hyprland'"
system_service_declared greetd.service || fail "system.yaml does not declare service 'greetd.service'"
if grep -Eq "^[[:space:]]+- 'ly(@|')" "$system_config"; then
  fail 'system.yaml still declares Ly'
fi
if grep -Fq 'workstation-uwsm.desktop' "$system_config"; then
  fail 'system.yaml still generates the obsolete Ly/UWSM desktop entry'
fi
if grep -R -Fq '/usr/share/blendos-workstation/identity' \
    "$system_config" "$installer" "$components" "$repo_dir/README.md" \
    "$repo_dir/STATE.md" "$repo_dir/services/desktop" "$identity_dir"; then
  fail 'identity bundle still targets immutable /usr/share'
fi

grep -Fq 'Quickshell.Services.Greetd' "$identity_dir/shell.qml" || fail 'greeter does not use the native greetd adapter'
grep -Fq 'Greetd.createSession' "$identity_dir/shell.qml" || fail 'greeter does not create greetd sessions'
grep -Fq 'Greetd.respond' "$identity_dir/shell.qml" || fail 'greeter does not answer greetd prompts'
grep -Fq 'Greetd.launch' "$identity_dir/shell.qml" || fail 'greeter does not launch the Workstation session'
grep -Fq 'Greetd.cancelSession' "$identity_dir/shell.qml" || fail 'greeter cannot cancel a login conversation'
if grep -Fq 'PamContext' "$identity_dir/shell.qml"; then
  fail 'greeter must not replace greetd with PamContext'
fi
if grep -REn '(^|[[:space:]])(Timer|Process|FileView)[[:space:]]*\{' "$identity_dir/GreeterView.qml"; then
  fail 'greeter presentation acquired controller or timer ownership'
fi
if grep -REn '(^|/)\.config/hypr/hyprland\.lua|workstation-lock|workstation-shell|blendos-workstation-session.target|/home/|XDG_STATE_HOME' "$identity_dir"; then
  fail 'pre-login identity sources depend on private desktop state'
fi
for config in "$identity_dir/hyprland.lua" "$identity_dir/hyprland-vm.lua"; do
  grep -Fq 'hl.monitor({' "$config" || fail "isolated greeter compositor has no monitor declaration: $(basename "$config")"
  grep -Fq 'hl.config({' "$config" || fail "isolated greeter compositor has no config declaration: $(basename "$config")"
  if grep -Eq 'dofile|os\.getenv|hl\.bind|hl\.dsp|exec-once|(^|[[:space:]])source([[:space:]]|=)' "$config"; then
    fail "isolated greeter compositor has a private-state or launch dependency: $(basename "$config")"
  fi
  grep -Fq 'disable_splash_rendering = true' "$config" || fail "isolated greeter compositor leaves its splash enabled: $(basename "$config")"
  grep -Fq 'disable_hyprland_guiutils_check = true' "$config" || fail "isolated greeter compositor leaves the unused guiutils check enabled: $(basename "$config")"
done

grep -Fq 'identityRoot + "/public-theme.json"' "$identity_dir/shell.qml" || fail 'greeter theme path is not the public identity path'
grep -Fq 'identity_root="${BLENDOS_WORKSTATION_IDENTITY_ROOT:-/etc/blendos-workstation/identity}"' "$identity_dir/greeter-host" || fail 'greeter host has no system identity root'
grep -Fq 'identity_root="${BLENDOS_WORKSTATION_IDENTITY_ROOT:-/etc/blendos-workstation/identity}"' "$identity_dir/greeter-ui" || fail 'greeter UI has no system identity root'
grep -Fq 'exec /usr/bin/qs -p "$identity_root"' "$identity_dir/greeter-ui" || fail 'greeter UI does not launch the isolated Quickshell project'
grep -Fqx 'export QML_IMPORT_PATH="$identity_root"' "$identity_dir/greeter-ui" || fail 'greeter UI inherits an arbitrary QML import path'
grep -Fqx 'export QML2_IMPORT_PATH="$identity_root"' "$identity_dir/greeter-ui" || fail 'greeter UI inherits an arbitrary legacy QML import path'
grep -Fq 'identity_root/greeter-ui' "$identity_dir/greeter-host" || fail 'greeter host does not own the UI lifecycle'
grep -Fq 'trap cleanup EXIT' "$identity_dir/greeter-host" || fail 'greeter host has no compositor cleanup trap'
grep -Fq 'trap terminate INT TERM' "$identity_dir/greeter-host" || fail 'greeter host signal trap does not terminate the host'
grep -Fq '[[ -x /usr/bin/start-hyprland ]]' "$identity_dir/greeter-host" || fail 'greeter host does not require the Hyprland watchdog launcher'
grep -Fq '/usr/bin/start-hyprland --path /usr/bin/Hyprland -- --config "$config"' "$identity_dir/greeter-host" || fail 'greeter host bypasses the Hyprland watchdog launcher'
grep -Fq 'declare -A existing_wayland_sockets=()' "$identity_dir/greeter-host" || fail 'greeter host does not record existing Wayland sockets'
grep -Fq 'existing_wayland_sockets["${socket_path##*/}"]=1' "$identity_dir/greeter-host" || fail 'greeter host does not record Wayland socket names'
grep -Fq 'socket_name="$candidate"' "$identity_dir/greeter-host" || fail 'greeter host does not discover the new Wayland socket'
grep -Fq 'export WAYLAND_DISPLAY="$socket_name"' "$identity_dir/greeter-host" || fail 'greeter host does not pass the discovered Wayland socket to Quickshell'
if grep -Fq 'runtime_dir/$WAYLAND_DISPLAY' "$identity_dir/greeter-host"; then
  fail 'greeter host waits for a fixed Wayland socket name'
fi
grep -Fq 'hyprland-vm.lua' "$identity_dir/greeter-host" || fail 'greeter host lacks the scoped VirtualBox profile'
vm_line="$(grep -n -Ei 'virtualbox|innotek' "$identity_dir/greeter-host" | head -n1 | cut -d: -f1)"
for override in QT_QUICK_BACKEND LIBGL_ALWAYS_SOFTWARE GALLIUM_DRIVER; do
  override_line="$(grep -n "export $override" "$identity_dir/greeter-host" | head -n1 | cut -d: -f1)"
  [[ -n "$vm_line" && -n "$override_line" && "$override_line" -gt "$vm_line" ]] ||
    fail "$override is not scoped after the VirtualBox check"
done

grep -Fq 'command = "/etc/blendos-workstation/identity/greeter-host"' "$system_config" || fail 'greetd config does not select the project greeter host'
grep -Fq 'user = "greeter"' "$system_config" || fail 'greetd config does not use the dedicated greeter account'
grep -Fq 'ConditionPathExists=/etc/blendos-workstation/identity/greeter-host' "$system_config" || fail 'greetd boot guard is missing'
grep -Fq 'session optional pam_gnome_keyring.so auto_start' "$system_config" || fail 'greetd keyring session integration is missing'
grep -Fq 'password optional pam_gnome_keyring.so' "$system_config" || fail 'greetd keyring password integration is missing'
grep -Fq 'install_identity_assets' "$installer" || fail 'installer does not publish identity assets'
grep -Fq 'services/desktop/identity' "$installer" || fail 'installer has no identity source path'
grep -Fq 'BLENDOS_WORKSTATION_IDENTITY_ROOT' "$installer" || fail 'identity provisioning has no disposable-root hook'

awk -F '\t' '
  $1 == "graphical-login" && $2 == "greetd" && $3 == "greetd" && $4 == "system-service:greetd.service" { login = 1 }
  $1 == "login-greeter" && $2 == "quickshell" && $3 == "/etc/blendos-workstation/identity/greeter-host" && $4 == "system-service:greetd.service" { greeter = 1 }
  END { exit(login && greeter ? 0 : 1) }
' "$components" || fail 'component contract has no graphical-login and login-greeter rows'
grep -Fxq 'Exec=Hyprland' "$repo_dir/.local/share/wayland-sessions/workstation.desktop" || fail 'UWSM compositor entry changed from Exec=Hyprland'

if command -v jq >/dev/null 2>&1; then
  public_theme="$(jq -c -e -f "$identity_dir/public-theme.jq" "$repo_dir/themes/catppuccin-mocha/theme.json")" || {
    fail 'public theme projection failed'
    public_theme='{}'
  }
  if ! jq -e 'type == "object" and (keys | sort) == ["colors", "mode", "release_id", "schema_version", "theme_id"] and .schema_version == 1 and .release_id == "public-default" and (.mode == "dark" or .mode == "light") and (.colors | type == "object")' <<<"$public_theme" >/dev/null; then
    fail 'public theme does not satisfy the greeter palette contract'
  fi
else
  fail 'jq is required to validate the public greeter palette'
fi

if [[ "$check_installed" == true ]]; then
  installed_root="${BLENDOS_WORKSTATION_IDENTITY_ROOT:-/etc/blendos-workstation/identity}"
  installed_files=(
    GreeterContract.js GreeterView.qml KeyboardState.qml shell.qml
    greeter-host greeter-ui hyprland.lua hyprland-vm.lua
    mark-dark.svg mark-light.svg public-theme.json
    WorkstationShared/AuthForm.qml WorkstationShared/Contract.js
    WorkstationShared/ThemedPane.qml WorkstationShared/qmldir
  )
  for file in "${installed_files[@]}"; do
    [[ -s "$installed_root/$file" ]] || fail "installed identity asset is missing: $installed_root/$file"
  done
  [[ -x "$installed_root/greeter-host" ]] || fail 'installed greeter host is not executable'
  [[ -x "$installed_root/greeter-ui" ]] || fail 'installed greeter UI is not executable'
  [[ -x /usr/bin/start-hyprland ]] || fail 'installed Hyprland watchdog launcher is unavailable'
  [[ -x /usr/bin/Hyprland ]] || fail 'installed Hyprland compositor is unavailable'
  [[ -f /etc/greetd/config.toml ]] || fail 'installed greetd config is missing'
  grep -Fqx 'command = "/etc/blendos-workstation/identity/greeter-host"' /etc/greetd/config.toml || fail 'installed greetd command is wrong'
  grep -Fqx 'user = "greeter"' /etc/greetd/config.toml || fail 'installed greetd user is wrong'
  [[ -f /etc/systemd/system/greetd.service.d/10-blendos-identity.conf ]] || fail 'installed greetd asset guard is missing'
  grep -Fq 'ConditionPathExists=/etc/blendos-workstation/identity/public-theme.json' /etc/systemd/system/greetd.service.d/10-blendos-identity.conf || fail 'installed greetd public-asset guard is missing'
  [[ -f /etc/pam.d/greetd ]] || fail 'installed greetd PAM configuration is missing'
  for line in 'auth optional pam_gnome_keyring.so' 'session optional pam_gnome_keyring.so auto_start' 'password optional pam_gnome_keyring.so'; do
    grep -Fqx "$line" /etc/pam.d/greetd || fail "installed greetd PAM lacks: $line"
  done
  id greeter >/dev/null 2>&1 || fail 'greetd package did not provide the dedicated greeter account'
  if ! systemctl is-enabled --quiet greetd.service; then fail 'greetd.service is not enabled'; fi
  if ! systemctl is-active --quiet greetd.service; then fail 'greetd.service is not active'; fi
  for retired in ly@tty2.service sddm.service gdm.service lightdm.service; do
    if systemctl is-enabled --quiet "$retired" 2>/dev/null || systemctl is-active --quiet "$retired" 2>/dev/null; then
      fail "retired or competing display manager is active: $retired"
    fi
  done
  if command -v ly >/dev/null 2>&1 || pacman -Q ly >/dev/null 2>&1; then
    fail 'Ly remains installed'
  fi
  if grep -REn '/home/|XDG_STATE_HOME|\.local/state|\.config/hypr/hyprland.lua|blendos-workstation-session.target' "$installed_root"; then
    fail 'installed pre-login sources reference private desktop state'
  fi
  jq -e '.schema_version == 1 and .release_id == "public-default" and (.colors | type == "object")' "$installed_root/public-theme.json" >/dev/null 2>&1 || fail 'installed public theme is invalid'
fi

if ((errors)); then
  printf '\nDesktop identity validation failed with %d error(s).\n' "$errors" >&2
  exit 1
fi

printf 'Desktop identity contract valid'
if [[ "$check_installed" == true ]]; then printf ' against the installed system'; fi
printf '.\n'
