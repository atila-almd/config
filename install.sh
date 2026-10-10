#!/usr/bin/env bash

set -Eeuo pipefail

install_system=true
install_home=true
provision_account=true
identity_only=false
machine_profile=''
mode_count=0

usage() {
  cat <<'EOF'
Usage: bash install.sh [--profile NAME] [--home-only | --system-only | --config-only | --identity-only]

Installs the managed home configuration using symlinks and, by default,
links /system.yaml through ~/system.yaml to the rendered Local State definition.

Options:
  --home-only  Install home configuration without changing /system.yaml.
  --system-only  Link the system definition before rebuilding missing packages.
  --config-only  Deploy home files/units only; skip runtime/account/system setup.
  --identity-only  Publish the public greeter bundle only (requires installed jq).
  --profile NAME  Explicit Machine Profile; otherwise use prior Local State.
  -h, --help   Show this help.
EOF
}

while (($#)); do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || { printf 'Missing profile name.\n' >&2; exit 2; }
      machine_profile="$2"
      shift
      ;;
    --identity-only)
      mode_count=$((mode_count + 1))
      identity_only=true
      install_system=false
      install_home=false
      ;;
    --home-only)
      mode_count=$((mode_count + 1))
      install_system=false
      ;;
    --system-only)
      mode_count=$((mode_count + 1))
      install_home=false
      ;;
    --config-only)
      mode_count=$((mode_count + 1))
      install_system=false
      provision_account=false
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if ((mode_count > 1)); then
  printf 'Choose exactly one installation mode.\n' >&2; exit 2
fi

if [[ "$install_system" == false && "$install_home" == false && "$identity_only" == false ]]; then
  printf 'System-only cannot be combined with home-only or config-only.\n' >&2
  exit 2
fi

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
target_home="${BLENDOS_WORKSTATION_TARGET_HOME:-$HOME}"
target_state_home="${BLENDOS_WORKSTATION_TARGET_STATE_HOME:-${XDG_STATE_HOME:-$target_home/.local/state}}"
[[ "$target_state_home" == /* ]] || { printf 'Local State path must be absolute.\n' >&2; exit 2; }
target_state_home="$(realpath -m -- "$target_state_home")"
[[ "$target_state_home" == /* && "$target_state_home" != "$repo_dir" && "$target_state_home" != "$repo_dir"/* ]] || {
  printf 'Local State must be absolute and outside the checkout.\n' >&2; exit 2
}
machine_state="$target_state_home/blendos-workstation/machine"
machine_profile="${machine_profile:-${BLENDOS_WORKSTATION_MACHINE_PROFILE:-}}"
if [[ -z "$machine_profile" && -f "$machine_state/profile" ]]; then
  IFS= read -r machine_profile < "$machine_state/profile"
fi
[[ "$machine_profile" =~ ^[a-z][a-z0-9-]*$ ]] || {
  printf 'Select a Machine Profile explicitly: ./bootstrap vm or ./bootstrap physical.\n' >&2
  exit 2
}
# Home-only deployment cannot switch the system/runtime hardware selection.
if [[ "$install_system" == false && "$identity_only" == false && -f "$machine_state/profile" ]]; then
  previous_profile="$(cat "$machine_state/profile")"
  [[ "$previous_profile" == "$machine_profile" ]] || {
    printf 'Switch Machine Profiles through bootstrap and rebuild first.\n' >&2; exit 2
  }
fi
# Validate the approved profile before any home/system mutation.
python3 "$repo_dir/scripts/render-system-definition.py" "$machine_profile" >/dev/null
system_definition="${BLENDOS_WORKSTATION_SYSTEM_DEFINITION:-$machine_state/system.yaml}"
backup_stamp="$(date -u +%Y%m%dT%H%M%S.%NZ)-$$"
backup_root="$target_state_home/blendos-workstation/backups/$backup_stamp"
theme_state_root="$target_state_home/blendos-workstation/theme"
backup_created=false
trap 'printf "Installation failed at line %s. Backups: %s. Correct the error and rerun.\n" "$LINENO" "$backup_root" >&2' ERR

# Ordinary configuration is symlinked, and Hyprland can reload changed files.
# Only deployment from outside a graphical session is safe during migration.
if [[ "$install_home" == true && "$target_home" == "$HOME" ]]; then
  if command -v systemctl >/dev/null 2>&1 &&
     systemctl --user is-active --quiet graphical-session.target; then
    printf 'Home deployment requires an inactive graphical session. Save work and log out deliberately, then install from a TTY or SSH.\n' >&2
    exit 1
  fi
  if [[ "$provision_account" == true ]]; then
  for prerequisite in mise zsh; do
    if ! command -v "$prerequisite" >/dev/null 2>&1; then
      printf 'Missing %s. Run --system-only, rebuild blendOS, then rerun home installation.\n' "$prerequisite" >&2
      exit 1
    fi
  done
  fi
fi

resolved_path() {
  readlink -f -- "$1" 2>/dev/null || true
}

run_privileged() {
  if [[ "${BLENDOS_WORKSTATION_TEST_NO_SUDO:-0}" == '1' ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

install_identity_assets() {
  local identity_source="$repo_dir/services/desktop/identity"
  # blendOS keeps /usr immutable at runtime; managed public identity belongs
  # in the mutable system configuration tree instead of a user home.
  local identity_root="${BLENDOS_WORKSTATION_IDENTITY_ROOT:-/etc/blendos-workstation/identity}"
  local identity_stage relative
  local -a public_files=(
    GreeterContract.js
    GreeterView.qml
    KeyboardState.qml
    shell.qml
    hyprland.lua
    hyprland-vm.lua
    mark-dark.svg
    mark-light.svg
  )
  local -a shared_files=(AuthForm.qml Contract.js ThemedPane.qml qmldir)
  local -a executable_files=(greeter-host greeter-ui)

  [[ "$identity_root" == /* ]] || {
    printf 'Greeter identity root must be absolute: %s\n' "$identity_root" >&2
    exit 1
  }
  for relative in "${public_files[@]}" "${executable_files[@]}" public-theme.jq; do
    [[ -f "$identity_source/$relative" ]] || {
      printf 'Missing managed identity source: %s\n' "$identity_source/$relative" >&2
      exit 1
    }
  done
  for relative in "${shared_files[@]}"; do
    [[ -f "$repo_dir/.config/quickshell/WorkstationShared/$relative" ]] || {
      printf 'Missing managed shared presentation source: %s\n' "$repo_dir/.config/quickshell/WorkstationShared/$relative" >&2
      exit 1
    }
  done
  command -v jq >/dev/null 2>&1 || {
    printf 'jq is required to publish the public greeter palette. Rebuild blendOS, then rerun install.sh.\n' >&2
    exit 1
  }

  identity_stage="$(mktemp -d)"
  mkdir -p -- "$identity_stage/WorkstationShared"
  for relative in "${public_files[@]}"; do
    install -Dm644 -- "$identity_source/$relative" "$identity_stage/$relative"
  done
  for relative in "${shared_files[@]}"; do
    install -Dm644 -- "$repo_dir/.config/quickshell/WorkstationShared/$relative" "$identity_stage/WorkstationShared/$relative"
  done
  for relative in "${executable_files[@]}"; do
    install -Dm755 -- "$identity_source/$relative" "$identity_stage/$relative"
  done
  jq -e -f "$identity_source/public-theme.jq" \
    "$repo_dir/themes/catppuccin-mocha/theme.json" > "$identity_stage/public-theme.json"

  run_privileged install -d -m0755 -- "$identity_root" "$identity_root/WorkstationShared"
  for relative in "${public_files[@]}" public-theme.json; do
    run_privileged install -Dm644 -- "$identity_stage/$relative" "$identity_root/$relative"
  done
  for relative in "${shared_files[@]}"; do
    run_privileged install -Dm644 -- "$identity_stage/WorkstationShared/$relative" "$identity_root/WorkstationShared/$relative"
  done
  for relative in "${executable_files[@]}"; do
    run_privileged install -Dm755 -- "$identity_stage/$relative" "$identity_root/$relative"
  done
  rm -rf -- "$identity_stage"
  printf 'Published public Workstation identity assets: %s\n' "$identity_root"
}

publish_machine_profile() {
  local identity_root="${BLENDOS_WORKSTATION_IDENTITY_ROOT:-/etc/blendos-workstation/identity}"
  local temporary
  temporary="$(mktemp)"
  printf '%s\n' "$machine_profile" > "$temporary"
  run_privileged install -Dm644 -- "$temporary" "${identity_root%/*}/machine-profile"
  rm -f -- "$temporary"
}

if [[ "$identity_only" == true ]]; then
  install_identity_assets
  publish_machine_profile
  exit 0
fi

ensure_backup_root() {
  if [[ "$backup_created" == false ]]; then
    mkdir -p -- "$backup_root"
    backup_created=true
  fi
}

backup_home_path() {
  local destination="$1"
  local relative backup

  relative="${destination#"$target_home"/}"
  backup="$backup_root/$relative"
  ensure_backup_root
  mkdir -p -- "$(dirname -- "$backup")"
  mv -- "$destination" "$backup"
  printf 'Backed up %s -> %s\n' "$destination" "$backup"
}

link_home_path() {
  local source="$1"
  local destination="$2"
  local source_resolved destination_resolved

  if [[ ! -e "$source" ]]; then
    printf 'Missing managed source: %s\n' "$source" >&2
    exit 1
  fi

  source_resolved="$(resolved_path "$source")"
  destination_resolved="$(resolved_path "$destination")"
  if [[ -L "$destination" && "$destination_resolved" == "$source_resolved" ]]; then
    printf 'Already linked: %s\n' "$destination"
    return
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    backup_home_path "$destination"
  fi

  mkdir -p -- "$(dirname -- "$destination")"
  ln -s -- "$source" "$destination"
  printf 'Linked %s -> %s\n' "$destination" "$source"
}

install_home_file() {
  local source="$1"
  local destination="$2"

  if [[ ! -f "$source" ]]; then
    printf 'Missing managed source: %s\n' "$source" >&2
    exit 1
  fi

  if [[ -f "$destination" && ! -L "$destination" ]] && cmp -s -- "$source" "$destination"; then
    chmod 0644 -- "$destination"
    printf 'Already installed: %s\n' "$destination"
    return
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    backup_home_path "$destination"
  fi

  install -Dm644 -- "$source" "$destination"
  printf 'Installed %s -> %s\n' "$source" "$destination"
}

migrate_config_directory() {
  local relative="$1"
  local destination="$target_home/$relative"
  local expected_source="$repo_dir/$relative"
  local destination_resolved expected_resolved

  if [[ -L "$destination" ]]; then
    destination_resolved="$(resolved_path "$destination")"
    expected_resolved="$(resolved_path "$expected_source")"
    if [[ "$destination_resolved" == "$expected_resolved" ]]; then
      rm -f -- "$destination"
    else
      backup_home_path "$destination"
    fi
  elif [[ -e "$destination" && ! -d "$destination" ]]; then
    backup_home_path "$destination"
  fi

  mkdir -p -- "$destination"
}

link_runtime_path() {
  local source="$1"
  local destination="$2"
  local destination_resolved state_resolved

  [[ -e "$source" ]] || {
    printf 'Missing generated theme source: %s\n' "$source" >&2
    exit 1
  }

  destination_resolved="$(resolved_path "$destination")"
  state_resolved="$(resolved_path "$theme_state_root")"
  if [[ -L "$destination" ]]; then
    if [[ "$destination_resolved" == "$state_resolved"/* ]]; then
      rm -f -- "$destination"
    elif [[ "$destination_resolved" == "$(resolved_path "$source")" ]]; then
      printf 'Already linked: %s\n' "$destination"
      return
    else
      backup_home_path "$destination"
    fi
  elif [[ -e "$destination" ]]; then
    backup_home_path "$destination"
  fi

  mkdir -p -- "$(dirname -- "$destination")"
  ln -s -- "$source" "$destination"
  printf 'Linked runtime theme path %s -> %s\n' "$destination" "$source"
}

if [[ "$install_home" == true ]]; then
install -d -m0700 -- "$machine_state"
printf '%s\n' "$machine_profile" > "$machine_state/profile"
chmod 0600 -- "$machine_state/profile"
data_build_dir="$(mktemp -d)"
trap 'rm -rf -- "$data_build_dir"' EXIT
for binary in workstation-data workstation-lock-guard workstation-launcher; do
  bash "$repo_dir/scripts/build-$binary.sh" "$data_build_dir/$binary"
done
for binary in workstation-data workstation-lock-guard workstation-launcher; do
  data_executable="$target_home/.local/libexec/blendos-workstation/$binary"
  if [[ -f "$data_executable" && ! -L "$data_executable" ]] && cmp -s -- "$data_build_dir/$binary" "$data_executable"; then
    chmod 0755 -- "$data_executable"
  else
    if [[ -e "$data_executable" || -L "$data_executable" ]]; then
      backup_home_path "$data_executable"
    fi
    install -Dm755 -- "$data_build_dir/$binary" "$data_executable"
  fi
done
config_directories=(
  '.config/uwsm'
  '.config/ghostty/themes'
  '.config/walker'
  '.config/walker/themes'
  '.config/walker/themes/blendos'
  '.config/dunst'
  '.config/dunst/dunstrc.d'
  '.config/elephant'
  '.config/elephant/menus'
  '.config/gtk-3.0'
  '.config/gtk-4.0'
)

# Older installs linked the whole Hyprland and Ghostty directories into the
# repository. Remove only those exact managed links; preserve every other
# directory or back it up before creating the file-level layout.
migrate_config_directory '.config/hypr'
migrate_config_directory '.config/ghostty'
for relative in "${config_directories[@]}"; do
  migrate_config_directory "$relative"
done

managed_home_paths=(
  '.config/quickshell/workstation'
  '.config/quickshell/workstation-lock'
  '.config/quickshell/WorkstationShared'
  '.local/share/wayland-sessions/workstation.desktop'
  '.config/git'
  '.config/mise'
  '.config/mimeapps.list'
  '.config/xdg-terminals.list'
  '.gitconfig'
  '.zprofile'
  '.zshrc'
  '.zshenv'
  '.local/share/applications/com.mitchellh.ghostty.desktop'
)

for relative in "${managed_home_paths[@]}"; do
  link_home_path "$repo_dir/$relative" "$target_home/$relative"
done

managed_config_files=(
  '.config/uwsm/env'
  '.config/ghostty/config.ghostty'
  '.config/hypr/hyprland.lua'
  '.config/hypr/hypridle.conf'
  '.config/walker/config.toml'
  '.config/walker/themes/blendos/style.css'
  '.config/dunst/dunstrc'
  '.config/elephant/elephant.toml'
  '.config/elephant/menus/workstation.toml'
  '.config/elephant/menus/workstation-notifications.toml'
  '.config/elephant/menus/workstation-capture.toml'
  '.config/elephant/menus/workstation-tools.toml'
)

for relative in "${managed_config_files[@]}"; do
  link_home_path "$repo_dir/$relative" "$target_home/$relative"
done

if [[ "$machine_profile" == vm ]]; then
  link_home_path "$repo_dir/profiles/vm/autostart/vboxclient.desktop" \
    "$target_home/.config/autostart/vboxclient.desktop"
elif [[ -e "$target_home/.config/autostart/vboxclient.desktop" || -L "$target_home/.config/autostart/vboxclient.desktop" ]]; then
  backup_home_path "$target_home/.config/autostart/vboxclient.desktop"
fi

theme_helper="$repo_dir/bin/workstation-theme"
theme_id=''
candidate_theme="$(
  HOME="$target_home" \
  XDG_CONFIG_HOME="$target_home/.config" \
  BLENDOS_WORKSTATION_THEME_STATE_HOME="$target_state_home" \
    bash "$theme_helper" current 2>/dev/null || true
)"
if [[ -n "$candidate_theme" && "$candidate_theme" != 'none' ]] &&
  HOME="$target_home" \
  XDG_CONFIG_HOME="$target_home/.config" \
  BLENDOS_WORKSTATION_THEME_STATE_HOME="$target_state_home" \
    bash "$theme_helper" validate "$candidate_theme" >/dev/null 2>&1; then
  theme_id="$candidate_theme"
else
  theme_id='catppuccin-mocha'
fi
HOME="$target_home" \
XDG_CONFIG_HOME="$target_home/.config" \
BLENDOS_WORKSTATION_THEME_STATE_HOME="$target_state_home" \
  bash "$theme_helper" set "$theme_id" --no-reload >/dev/null

theme_runtime_source="$theme_state_root/current"
link_runtime_path "$theme_runtime_source/walker.css" \
  "$target_home/.config/walker/themes/blendos/theme.css"
link_runtime_path "$theme_runtime_source/dunst-theme.conf" \
  "$target_home/.config/dunst/dunstrc.d/90-theme.conf"
link_runtime_path "$theme_runtime_source/ghostty-theme.conf" \
  "$target_home/.config/ghostty/themes/blendos-workstation"
link_runtime_path "$theme_runtime_source/gtk-3.0-settings.ini" \
  "$target_home/.config/gtk-3.0/settings.ini"
link_runtime_path "$theme_runtime_source/gtk-4.0-settings.ini" \
  "$target_home/.config/gtk-4.0/settings.ini"

managed_user_unit_paths=(
  '.config/systemd/user/workstation-data.service'
  '.config/systemd/user/workstation-launcher.service'
  '.config/systemd/user/workstation-shell.service'
  '.config/systemd/user/workstation-lock.service'
  '.config/systemd/user/workstation-lock-guard.service'
  '.config/systemd/user/hypridle.service'
  '.config/systemd/user/blendos-backup.service'
  '.config/systemd/user/blendos-backup.timer'
  '.config/systemd/user/awww-daemon.service'
  '.config/systemd/user/blendos-workstation-session.target'
  '.config/systemd/user/dunst.service.d/10-blendos-session.conf'
  '.config/systemd/user/elephant.service'
  '.config/systemd/user/hyprpolkitagent.service.d/10-blendos-session.conf'
  '.config/systemd/user/portless.service'
  '.config/systemd/user/walker.service'
  '.config/systemd/user/wallpaper-restore.service'
  '.config/systemd/user/wl-clip-persist.service'
)

for relative in "${managed_user_unit_paths[@]}"; do
  install_home_file "$repo_dir/$relative" "$target_home/$relative"
done

profile_units=(vboxclient-clipboard.service vboxclient-vmsvga.service)
for unit in "${profile_units[@]}"; do
  destination="$target_home/.config/systemd/user/$unit"
  if [[ "$machine_profile" == vm ]]; then
    install_home_file "$repo_dir/profiles/vm/user/$unit" "$destination"
  elif [[ -e "$destination" || -L "$destination" ]]; then
    backup_home_path "$destination"
  fi
done
profile_dropin="$target_home/.config/systemd/user/blendos-workstation-session.target.d/20-machine-profile.conf"
if [[ "$machine_profile" == vm ]]; then
  install_home_file "$repo_dir/profiles/vm/user/20-machine-profile.conf" "$profile_dropin"
elif [[ -e "$profile_dropin" || -L "$profile_dropin" ]]; then
  backup_home_path "$profile_dropin"
fi

session_target="$target_home/.config/systemd/user/blendos-workstation-session.target"
session_wants_link="$target_home/.config/systemd/user/wayland-session@workstation.desktop.target.wants/blendos-workstation-session.target"
link_home_path "$session_target" "$session_wants_link"

managed_bin_helpers=(
  bin/workstation-data
  bin/workstation-launcher
  bin/session-terminal
  bin/session-walker
  bin/session-workstation-shell
  bin/session-workstation-lock
  bin/workstation-suspend
  bin/portless-compose
  bin/git-profile
  bin/session-lock
  bin/workstation-theme
  bin/workstation-wallpaper
  bin/workstation-capture
  bin/workstation-keybindings
  bin/workstation-project
  bin/workstation-agent
  bin/workstation-doctor
  bin/workstation-backup
  bin/workstation-maintain
  bin/workstation-controls
  bin/workstation-media
  bin/workstation-record
  bin/workstation-remind
)

for helper_path in "${managed_bin_helpers[@]}"; do
  helper="${helper_path##*/}"
  chmod u+x -- "$repo_dir/$helper_path"
  link_home_path "$repo_dir/$helper_path" \
    "$target_home/.local/bin/blend_bin/$helper"
done

if [[ "$target_home" == "$HOME" ]] && command -v systemctl >/dev/null 2>&1; then
  if systemctl --user daemon-reload 2>/dev/null; then
    printf 'Desktop units loaded; session changes take effect at next login.\n'
  else
    printf 'User systemd manager unavailable; units will load at next login.\n'
  fi
fi

# Identity values and directory mappings are intentionally Local State.
git_identity_root="${BLENDOS_WORKSTATION_GIT_STATE_HOME:-$target_state_home/blendos-workstation/git}"
install -d -m0700 -- "$git_identity_root/profiles"
if [[ ! -e "$git_identity_root/config" ]]; then
  install -m0600 -- /dev/null "$git_identity_root/config"
fi

if [[ "$provision_account" == true ]]; then
if [[ "$target_home" == "$HOME" ]]; then
  if command -v mise >/dev/null 2>&1; then
    mise install
    bash "$repo_dir/scripts/patch-portless-unprivileged-bind.sh"
  else
    printf 'Mise is unavailable; rebuild blendOS before installing Portless.\n' >&2
    exit 1
  fi

  if command -v sysctl >/dev/null 2>&1; then
    run_privileged sysctl -w net.ipv4.ip_unprivileged_port_start=80
  fi

  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload
    systemctl --user enable --now portless.service
  fi
fi

podman_socket='/usr/lib/systemd/user/podman.socket'
podman_link="$target_home/.config/systemd/user/sockets.target.wants/podman.socket"
if [[ -e "$podman_socket" ]]; then
  link_home_path "$podman_socket" "$podman_link"

  if [[ "$target_home" == "$HOME" ]] && command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload
    systemctl --user enable --now podman.socket
  fi
else
  printf 'Podman user socket unit is unavailable; install the podman package first.\n' >&2
fi

if [[ "$target_home" == "$HOME" ]]; then
  login_user="$(id -un)"
  zsh_command="$(command -v zsh || true)"
  zsh_path="$(resolved_path "$zsh_command")"
  current_shell="$(getent passwd "$login_user" | cut -d: -f7)"

  if [[ -z "$zsh_command" || -z "$zsh_path" ]]; then
    printf 'Zsh is unavailable; install the zsh package before changing the login shell.\n' >&2
    exit 1
  elif ! grep -Fxq -- "$zsh_path" /etc/shells; then
    printf 'Canonical Zsh path is not registered in /etc/shells: %s\n' "$zsh_path" >&2
    printf 'Rebuild blendOS so system.yaml refreshes /etc/shells, then rerun install.sh.\n' >&2
    exit 1
  elif [[ "$current_shell" == "$zsh_path" ]]; then
    printf 'Login shell already set: %s\n' "$zsh_path"
  else
    run_privileged usermod --shell "$zsh_path" "$login_user"
    printf 'Set %s login shell: %s\n' "$login_user" "$zsh_path"
  fi
fi

fi # provision_account
fi # install_home

if [[ "$install_system" == true ]]; then
  if [[ -z "${BLENDOS_WORKSTATION_SYSTEM_DEFINITION:-}" ]]; then
    install -d -m0700 -- "$machine_state"
    definition_stage="$(mktemp "$machine_state/.system.XXXXXX")"
    python3 "$repo_dir/scripts/render-system-definition.py" "$machine_profile" > "$definition_stage"
    if [[ -f "$system_definition" ]] && cmp -s "$definition_stage" "$system_definition"; then
      rm -f -- "$definition_stage"
    else
      mv -f -- "$definition_stage" "$system_definition"
    fi
  fi
  [[ -f "$system_definition" && "$system_definition" == /* ]] || {
    printf 'Rendered System Definition must be an existing absolute file.\n' >&2
    exit 1
  }
  link_home_path "$system_definition" "$target_home/system.yaml"
  if [[ "$install_home" == true ]] && getent passwd 'gnome-initial-setup' >/dev/null; then
    run_privileged userdel -- 'gnome-initial-setup'
    printf 'Removed transient account: gnome-initial-setup\n'
  fi

  system_source="$target_home/system.yaml"
  system_destination="${BLENDOS_WORKSTATION_SYSTEM_PATH:-/system.yaml}"
  system_source_resolved="$(resolved_path "$system_source")"
  system_destination_resolved="$(resolved_path "$system_destination")"

  if [[ -L "$system_destination" && "$system_destination_resolved" == "$system_source_resolved" ]]; then
    printf 'Already linked: %s\n' "$system_destination"
  else
    system_backup="${system_destination}.before-blendos-workstation.$backup_stamp"
    if run_privileged test -e "$system_destination" || run_privileged test -L "$system_destination"; then
      run_privileged mv -- "$system_destination" "$system_backup"
      printf 'Backed up %s -> %s\n' "$system_destination" "$system_backup"
    fi
    run_privileged ln -s -- "$system_source" "$system_destination"
    printf 'Linked %s -> %s\n' "$system_destination" "$system_source"
  fi

  if [[ "$install_home" == false ]]; then
    printf 'System definition staged. Use ./bootstrap %s to rebuild; reboot deliberately, then rerun bootstrap from an inactive graphical session.\n' "$machine_profile"
  elif command -v ufw >/dev/null 2>&1; then
    # Default-deny unsolicited host traffic while preserving authenticated
    # tailnet access. RustDesk continues to work through its outbound relay.
    run_privileged ufw default deny incoming
    run_privileged ufw default allow outgoing
    run_privileged ufw default deny routed
    run_privileged ufw allow in on tailscale0 comment 'Authenticated Tailscale peers'
    run_privileged ufw --force enable
  else
    printf 'UFW is unavailable; rebuild blendOS, then rerun install.sh to apply the firewall baseline.\n' >&2
    exit 1
  fi

  if [[ "$install_home" == true && "$target_home" == "$HOME" ]] &&
     command -v systemctl >/dev/null 2>&1; then
    install_identity_assets
    publish_machine_profile
    run_privileged systemctl daemon-reload
    run_privileged systemctl enable --now greetd.service
  fi
fi

printf '\nInstallation complete.\n'
if [[ "$backup_created" == true ]]; then
  printf 'Home backups: %s\n' "$backup_root"
fi
printf 'Resolved system config: %s\n' "$(resolved_path "$target_home/system.yaml")"
