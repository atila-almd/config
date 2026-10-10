#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
system_config="$repo_dir/system.yaml"
contract="$repo_dir/components.tsv"
installer="$repo_dir/install.sh"
walker_config="$repo_dir/.config/walker/config.toml"
dunst_config="$repo_dir/.config/dunst/dunstrc"
hypr_config="$repo_dir/.config/hypr/hyprland.lua"
theme_helper="$repo_dir/bin/workstation-theme"
target_unit="$repo_dir/.config/systemd/user/blendos-workstation-session.target"
unit_dir="$repo_dir/.config/systemd/user"
check_installed=false
errors=0

if [[ "${1:-}" == '--installed' ]]; then
  check_installed=true
elif (($#)); then
  printf 'Usage: bash scripts/validate-desktop-shell.sh [--installed]\n' >&2
  exit 2
fi

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  errors=$((errors + 1))
}

expect_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "required file is missing: $path"
}

expect_installer_reference() {
  local reference="$1"
  grep -Fq -- "$reference" "$installer" ||
    fail "installer does not deploy or wire '$reference'"
}

package_names() {
  awk '
    /^aur-packages:$/ { in_aur = 1; next }
    in_aur && /^[^[:space:]#]/ { in_aur = 0 }
    in_aur && /^  - '\''elephant-/ {
      package = $0
      sub(/^  - '\''elephant-/, "", package)
      sub(/'\''[[:space:]]*$/, "", package)
      sub(/^elephant-/, "", package)
      print package
    }
  ' "$system_config" | sort -u
}

configured_walker_providers() {
  {
    sed -n '/^default[[:space:]]*=/p; /^empty[[:space:]]*=/p' -- "$walker_config" |
      grep -oE '"[a-z][a-z0-9_-]*"' | tr -d '"'
    sed -n '/^\[providers\.max_results_provider\]/,/^\[/p' -- "$walker_config" |
      sed -n 's/^[[:space:]]*\([a-z][a-z0-9_-]*\)[[:space:]]*=.*/\1/p'
    sed -n 's/^[[:space:]]*provider[[:space:]]*=[[:space:]]*"\([a-z][a-z0-9_-]*\)".*/\1/p' -- "$walker_config"
  } | sort -u
}

validate_repository() {
  local path unit target_wants configured expected first
  local fallback_start
  local -a required_files=(
    '.config/uwsm/env'
    '.config/walker/config.toml'
    '.config/walker/themes/blendos/style.css'
    '.config/dunst/dunstrc'
    '.config/elephant/elephant.toml'
    '.config/systemd/user/elephant.service'
    '.config/systemd/user/walker.service'
    '.config/systemd/user/workstation-launcher.service'
    '.config/systemd/user/wallpaper-restore.service'
    'bin/session-lock'
    'bin/session-walker'
    'bin/workstation-launcher'
    'bin/workstation-theme'
    'bin/workstation-wallpaper'
    'themes/schema.json'
    'themes/templates/walker.css.tpl'
    'themes/templates/dunst-theme.conf.tpl'
    'themes/templates/hyprland-theme.lua.tpl'
    'themes/templates/ghostty-theme.conf.tpl'
    'themes/templates/gtk-3.0-settings.ini.tpl'
    'themes/templates/gtk-4.0-settings.ini.tpl'
    'themes/catppuccin-mocha/theme.json'
    'themes/catppuccin-mocha/wallpapers/default.svg'
  )
  local -a runtime_paths=(
    '.config/walker/themes/blendos/theme.css'
    '.config/dunst/dunstrc.d/90-theme.conf'
    '.config/ghostty/themes/blendos-workstation'
    '.config/gtk-3.0/settings.ini'
    '.config/gtk-4.0/settings.ini'
  )

  command -v jq >/dev/null 2>&1 || fail 'jq is required for desktop-shell validation'
  [[ -f "$repo_dir/themes/schema.json" ]] || fail 'theme schema is missing'
  if ! jq -e '.type == "object" and .properties.schema.const == 1' -- "$repo_dir/themes/schema.json" >/dev/null 2>&1; then
    fail 'theme schema is not the version-1 schema'
  fi
  for path in "${required_files[@]}"; do
    expect_file "$repo_dir/$path"
  done
  for path in "${required_files[@]}"; do
    case "$path" in
      .config/*|install.sh) expect_installer_reference "$path" ;;
      bin/*) expect_installer_reference "${path##*/}" ;;
    esac
  done


  expected="$(package_names)"
  # The Island owns application/file/calculator/web presentation now. Elephant
  # still builds those providers for the Quickshell adapter, but Walker's
  # selected utility presentation must not expose duplicate search jobs.
  expected="$(printf '%s\n' "$expected" | grep -Ev '^(desktopapplications|files|calc|websearch)$' || true)"
  configured="$(configured_walker_providers)"
  if [[ "$configured" != "$expected" ]]; then
    fail "Walker providers do not match Elephant packages (configured: ${configured//$'\n'/, }; packages: ${expected//$'\n'/, })"
  fi
  if grep -Eq "^[[:space:]]+- 'elephant.*-bin'[[:space:]]*$" "$system_config"; then
    fail 'binary Elephant provider packages are not allowed'
  fi

  target_wants="$(sed -n 's/^Wants=//p' "$target_unit")"
  for unit in elephant.service walker.service workstation-launcher.service wallpaper-restore.service; do
    [[ " $target_wants " == *" $unit "* ]] || fail "$unit is not owned by the desktop session target"
    expect_file "$unit_dir/$unit"
    grep -Fxq 'PartOf=blendos-workstation-session.target' "$unit_dir/$unit" ||
      fail "$unit is missing session ownership"
    grep -Fxq 'ConditionEnvironment=WAYLAND_DISPLAY' "$unit_dir/$unit" ||
      fail "$unit is missing the Wayland condition"
    grep -Fxq 'Slice=session-graphical.slice' "$unit_dir/$unit" ||
      fail "$unit is missing the graphical slice"
  done
  grep -Fxq 'Requires=awww-daemon.service' "$unit_dir/wallpaper-restore.service" ||
    fail 'wallpaper restore does not require Awww'
  grep -Fxq 'After=awww-daemon.service' "$unit_dir/wallpaper-restore.service" ||
    fail 'wallpaper restore does not order after Awww'
  grep -Fxq 'Requires=elephant.service' "$unit_dir/walker.service" ||
    fail 'Walker does not require Elephant'
  grep -Fxq 'After=elephant.service' "$unit_dir/walker.service" ||
    fail 'Walker does not start after Elephant'
  grep -Fxq 'ExecStart=%h/.local/bin/blend_bin/session-walker --gapplication-service' "$unit_dir/walker.service" ||
    fail 'Walker does not use its session rendering wrapper'

  if ! bash "$theme_helper" validate --all >/dev/null 2>&1; then
    fail 'one or more theme manifests failed workstation-theme validation'
  fi
  for path in "${runtime_paths[@]}"; do
    expect_installer_reference "$path"
  done
  if find "$repo_dir/themes" "$repo_dir/.config" "$repo_dir/.local" -type d \( -name releases -o -name wallpaper-state -o -name .theme-staging \) -print -quit | grep -q .; then
    fail 'generated theme release state exists in the repository'
  fi
  if find "$repo_dir/themes" "$repo_dir/.config" "$repo_dir/.local" -type f \( -name wallpaper.png -o -name wallpaper-source -o -name selected \) -print -quit | grep -q .; then
    fail 'generated theme output or selection exists in the repository'
  fi

  grep -Fq 'origin = top-right' "$dunst_config" || fail 'Dunst geometry is not top-right'
  grep -Fq 'offset = 10x52' "$dunst_config" || fail 'Dunst is not offset below the bar'
  grep -Fq 'width = (320, 560)' "$dunst_config" || fail 'Dunst width range is missing'
  grep -Fq 'stack_duplicates = yes' "$dunst_config" || fail 'Dunst duplicate stacking is disabled'
  grep -Fq 'history_length = 50' "$dunst_config" || fail 'Dunst history is not enabled'
  grep -Fq 'progress_bar = true' "$dunst_config" || fail 'Dunst progress bars are disabled'
  if grep -Eq '#[0-9A-Fa-f]{6}' "$dunst_config"; then
    fail 'Dunst base config contains hard-coded theme colors'
  fi
  if grep -Eq '#[0-9A-Fa-f]{6}' "$repo_dir/.config/walker/themes/blendos/style.css"; then
    fail 'Walker base CSS contains hard-coded theme colors'
  fi
  grep -Fq 'session-lock' "$hypr_config" || fail 'Hyprland has no session-lock entry point'
  grep -Fq 'export PATH="$HOME/.local/bin/blend_bin:$HOME/.local/bin:$PATH"' "$repo_dir/.config/uwsm/env" ||
    fail 'UWSM does not export the managed helper PATH'
  grep -Fq 'local monitor_mode = "preferred"' "$hypr_config" || fail 'Hyprland has no physical-display mode default'
  grep -Fq 'local monitor_scale = "auto"' "$hypr_config" || fail 'Hyprland has no physical-display scale default'
  grep -Fq 'dmi_product == "VirtualBox"' "$hypr_config" || fail 'Hyprland has no VirtualBox display override'
  grep -Fq 'monitor_mode = "1920x1080@60"' "$hypr_config" || fail 'Hyprland has no VirtualBox 1080p mode'
  grep -Fq 'mode = monitor_mode' "$hypr_config" || fail 'Hyprland monitor does not use the selected mode'
  grep -Fq 'scale = monitor_scale' "$hypr_config" || fail 'Hyprland monitor does not use the selected scale'
  grep -Fq 'active_border = {' "$hypr_config" || fail 'Hyprland fallback active border is not a gradient table'
  grep -Fq 'colors = {' "$hypr_config" || fail 'Hyprland fallback gradient has no colors array'
  fallback_start="$(grep -n '^local fallback_theme' "$hypr_config" | cut -d: -f1)"
  if [[ -z "$fallback_start" ]]; then
    fail 'Hyprland fallback theme is not documented'
  else
    while IFS=: read -r line ignored; do
      [[ -n "$line" ]] || continue
      if ((line < fallback_start)); then
        fail "Hyprland has hard-coded palette data outside its fallback: line $line"
      fi
    done < <(grep -nE 'rgba\([0-9A-Fa-f]{6}|0x[0-9A-Fa-f]{6}' "$hypr_config" || true)
  fi

  if ! bash "$repo_dir/scripts/validate-component-contract.sh" >/dev/null; then
    fail 'Component Contract validation failed'
  fi
  if ! bash "$repo_dir/scripts/validate-user-session.sh" >/dev/null; then
    fail 'user-session validation failed'
  fi
}

installed_service_active() {
  local unit="$1"
  if [[ "$unit" == blendos-workstation-session.target ]]; then
    systemctl --user is-enabled --quiet "$unit" || fail "$unit is not enabled"
  elif ! systemctl --user show --value --property=Wants --property=Requires blendos-workstation-session.target |
      tr ' ' '\n' | grep -Fxq -- "$unit"; then
    fail "$unit is not a dependency of the installed workstation session"
  fi
  if ! systemctl --user is-active --quiet "$unit"; then
    fail "$unit is not active"
  fi
}

validate_installed() {
  local tmp_log output expected_accent actual index package version help_output check_flag menu_file menu_name
  local state_root
  local -a packages=(
    elephant elephant-calc elephant-clipboard elephant-desktopapplications
    elephant-files elephant-menus elephant-providerlist elephant-runner
    elephant-symbols elephant-websearch elephant-windows
  )
  local -a versions=()
  local -a runtime_paths=(
    "$HOME/.config/walker/themes/blendos/theme.css"
    "$HOME/.config/dunst/dunstrc.d/90-theme.conf"
    "$HOME/.config/ghostty/themes/blendos-workstation"
    "$HOME/.config/gtk-3.0/settings.ini"
    "$HOME/.config/gtk-4.0/settings.ini"
  )

  if ! systemd-analyze --user verify blendos-workstation-session.target elephant.service walker.service workstation-launcher.service wallpaper-restore.service; then
    fail 'systemd rejected one or more installed desktop-shell units'
  fi
  installed_service_active blendos-workstation-session.target
  for unit in awww-daemon.service wallpaper-restore.service workstation-shell.service workstation-data.service workstation-launcher.service workstation-lock-guard.service hypridle.service dunst.service elephant.service walker.service; do
    installed_service_active "$unit"
  done

  output="$(elephant listproviders 2>&1)" || {
    fail 'elephant listproviders failed'
    output=''
  }
  while IFS= read -r package; do
    [[ -n "$package" ]] || continue
    if [[ "$package" == menus ]]; then
      for menu_file in "$repo_dir/.config/elephant/menus/"*.toml; do
        menu_name="${menu_file##*/}"
        menu_name="${menu_name%.toml}"
        grep -Fxq -- "menus:$menu_name" <<<"$output" || fail "Elephant menu provider is not loaded: $menu_name"
      done
    else
      grep -Fxq -- "$package" <<<"$output" || fail "Elephant provider is not loaded: $package"
    fi
  done < <(package_names)
  command -v pacman >/dev/null 2>&1 || fail 'pacman is not installed'
  for package in "${packages[@]}"; do
    if ! version="$(pacman -Q "$package" 2>/dev/null | awk '{print $2}')"; then
      fail "Elephant package is not installed: $package"
    else
      versions+=("$version")
    fi
  done
  if ((${#versions[@]})) && [[ "$(printf '%s\n' "${versions[@]}" | sort -u | wc -l)" != 1 ]]; then
    fail 'Elephant core and providers do not share one upstream version'
  fi

  for executable in walker dunstctl awww qs workstation-theme; do
    command -v -- "$executable" >/dev/null 2>&1 || fail "installed executable is unavailable: $executable"
  done
  walker --version >/dev/null 2>&1 || fail 'Walker version command failed'
  dunstctl is-paused >/dev/null 2>&1 || fail 'Dunst control command failed'
  awww query >/dev/null 2>&1 || fail 'Awww query failed'
  workstation-theme current >/dev/null 2>&1 || fail 'workstation-theme current failed'

  state_root="${XDG_STATE_HOME:-$HOME/.local/state}/blendos-workstation/theme"
  for path in "${runtime_paths[@]}"; do
    if [[ ! -L "$path" ]]; then
      fail "runtime theme path is not a symlink: $path"
      continue
    fi
    actual="$(readlink -f -- "$path" 2>/dev/null || true)"
    case "$actual" in
      "$(readlink -f -- "$state_root")"/*) ;;
      *) fail "runtime theme path escapes Local State: $path" ;;
    esac
  done

  if command -v ghostty >/dev/null 2>&1; then
    expected_accent="$(jq -er '.colors.accent' -- "$(readlink -f -- "$state_root/current")/manifest.json")"
    if ! ghostty +show-config 2>/dev/null | grep -Fq -- "$expected_accent"; then
      fail 'Ghostty does not report the active generated theme value'
    fi
  else
    fail 'Ghostty is not installed'
  fi
  active_manifest="$(readlink -f -- "$state_root/current")/manifest.json"
  for index in 3 4; do
    gtk_file="$HOME/.config/gtk-${index}.0/settings.ini"
    expected="$(jq -er '.gtk.theme' -- "$active_manifest")"
    grep -Fq "gtk-theme-name=$expected" "$gtk_file" || fail "GTK ${index}.0 does not match the active manifest"
  done

  tmp_log="$(mktemp)"
  trap 'rm -f -- "$tmp_log"' RETURN
  journalctl --user -b -u workstation-shell.service -u dunst.service -u awww-daemon.service \
    -u wallpaper-restore.service -u elephant.service -u walker.service \
    --no-pager >"$tmp_log" 2>/dev/null || true
  if grep -Eiq 'plugin ABI|start request repeated too quickly|crash loop' -- "$tmp_log"; then
    fail 'managed desktop-shell services have a current-boot crash or ABI loop'
  fi
  trap - RETURN
  rm -f -- "$tmp_log"
}

validate_repository
if [[ "$check_installed" == true ]]; then
  validate_installed
fi

if ((errors)); then
  printf '\nDesktop shell validation failed with %d error(s).\n' "$errors" >&2
  exit 1
fi

printf 'desktop shell contract valid.\n'
