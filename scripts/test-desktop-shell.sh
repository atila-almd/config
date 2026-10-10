#!/usr/bin/env bash

set -Eeuo pipefail
export BLENDOS_WORKSTATION_MACHINE_PROFILE=vm

repo_dir="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

copy_fixture() {
  local destination="$1"
  local source="$repo_dir"
  if [[ -d "$fixture" && "$destination" != "$fixture" ]]; then
    source="$fixture"
  fi
  mkdir -p -- "$destination"
  bash "$repo_dir/scripts/copy-source-fixture.sh" "$source" "$destination"
}

json_expect() {
  local description="$1"
  local expression="$2"
  local document="$3"
  jq -e "$expression" <<<"$document" >/dev/null || fail "$description"
}

fixture="$test_dir/repository"
home="$test_dir/home"
state="$test_dir/state"
fake_bin="$test_dir/bin"
empty_bin="$test_dir/empty-bin"
mkdir -p -- "$home" "$state" "$fake_bin" "$empty_bin"
ln -s -- "$(command -v go)" "$fake_bin/go"
ln -s -- "$(command -v bash)" "$empty_bin/bash"
ln -s -- "$(command -v jq)" "$empty_bin/jq"
copy_fixture "$fixture"

export DUNST_PAUSED=false
export DUNST_WAITING=0
export NVIDIA_UNAVAILABLE=0
export NVIDIA_SAMPLE=20,60
export AWWW_NOT_READY=0
export AWWW_FAIL=0
export AWWW_LOG=/dev/null
export WALKER_CANCEL=0
export WALKER_SELECTION=

cat > "$fake_bin/resvg" <<'EOF'
#!/usr/bin/env bash
if [[ "$RESVG_FAIL" == '1' ]]; then
  exit 1
fi
if [[ "$#" -ne 2 || "${1:-}" == '--' ]]; then
  printf 'resvg test stub expects: resvg [OPTIONS] <in-svg> <out-png>\n' >&2
  exit 2
fi
convert -- "$1" "$2"
EOF

cat > "$fake_bin/walker" <<'EOF'
#!/usr/bin/env bash
if [[ "$WALKER_CANCEL" == '1' ]]; then
  exit 0
fi
printf '%s\n' "$WALKER_SELECTION"
EOF

cat > "$fake_bin/dunstctl" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  'is-paused ')
    printf '%s\n' "$DUNST_PAUSED"
    ;;
  'count waiting')
    printf '%s\n' "$DUNST_WAITING"
    ;;
  *)
    exit 0
    ;;
esac
EOF

cat > "$fake_bin/nvidia-smi" <<'EOF'
#!/usr/bin/env bash
if [[ "$NVIDIA_UNAVAILABLE" == '1' ]]; then
  exit 1
fi
printf '%s\n' "$NVIDIA_SAMPLE"
EOF

cat > "$fake_bin/awww" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  query)
    [[ "$AWWW_NOT_READY" == '1' ]] && exit 1
    exit 0
    ;;
  img)
    [[ "$AWWW_FAIL" == '1' ]] && exit 1
    printf '%s\n' "$*" >> "$AWWW_LOG"
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF

cat > "$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  '--user show --value --property=Wants --property=Requires blendos-workstation-session.target')
    printf '%s\n' "$DESKTOP_TEST_SESSION_DEPENDENCIES"
    ;;
  '--user is-enabled --quiet blendos-workstation-session.target') exit 0 ;;
  '--user is-enabled --quiet '*) exit 1 ;;
esac
exit 0
EOF

cat > "$fake_bin/qs" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

chmod u+x -- "$fake_bin"/*

run_theme() (
  export HOME="$home"
  export XDG_CONFIG_HOME="$home/.config"
  export XDG_STATE_HOME="$state"
  export BLENDOS_WORKSTATION_THEME_STATE_HOME="$state"
  export BLENDOS_WORKSTATION_THEME_CONFIG_HOME="$home/.config"
  export BLENDOS_WORKSTATION_THEME_BUILTIN_HOME="$fixture/themes"
  export BLENDOS_WORKSTATION_THEME_NO_RELOAD=1
  export PATH="$fake_bin:/usr/bin:/bin"
  "$fixture/bin/workstation-theme" "$@"
)

run_wallpaper() (
  export HOME="$home"
  export XDG_CONFIG_HOME="$home/.config"
  export XDG_STATE_HOME="$state"
  export BLENDOS_WORKSTATION_THEME_STATE_HOME="$state"
  export BLENDOS_WORKSTATION_THEME_CONFIG_HOME="$home/.config"
  export BLENDOS_WORKSTATION_THEME_BUILTIN_HOME="$fixture/themes"
  export PATH="$fake_bin:/usr/bin:/bin"
  "$fixture/bin/workstation-wallpaper" "$@"
)

run_wallpaper_failure() (
  export AWWW_FAIL=1
  run_wallpaper next
)

run_theme_cancel() (
  export WALKER_CANCEL=1
  run_theme choose
)

run_wallpaper_cancel() (
  export WALKER_CANCEL=1
  run_wallpaper choose
)

before_repo_status="$(git -C "$repo_dir" status --porcelain=v1 -- themes .config/hypr .config/ghostty .config/walker .config/dunst .config/gtk-3.0 .config/gtk-4.0)"

grep -Fq 'catppuccin-mocha' <(run_theme list) ||
  fail 'theme list omitted the bundled theme'
run_theme validate catppuccin-mocha >/dev/null
run_theme set catppuccin-mocha --no-reload >/dev/null

multi="$home/.config/blendos-workstation/themes/multi"
mkdir -p -- "$multi/wallpapers"
cp -- "$fixture/themes/catppuccin-mocha/wallpapers/default.svg" \
  "$multi/wallpapers/first.svg"
cp -- "$fixture/themes/catppuccin-mocha/wallpapers/default.svg" \
  "$multi/wallpapers/second.svg"
jq '.id = "multi" | .name = "Multi" | .wallpapers = [
  {"name": "First", "path": "wallpapers/first.svg"},
  {"name": "Second", "path": "wallpapers/second.svg"}
]' "$fixture/themes/catppuccin-mocha/theme.json" > "$multi/theme.json"
run_theme validate multi >/dev/null
run_theme set multi --no-reload >/dev/null

awww_log="$test_dir/awww.log"
wallpaper="$(AWWW_LOG="$awww_log" run_wallpaper current)"
[[ "$wallpaper" == $'multi\t0\tFirst' ]] ||
  fail "unexpected initial wallpaper: $wallpaper"
AWWW_LOG="$awww_log" run_wallpaper next >/dev/null
wallpaper="$(run_wallpaper current)"
[[ "$wallpaper" == $'multi\t1\tSecond' ]] ||
  fail "wallpaper next did not advance: $wallpaper"
AWWW_LOG="$awww_log" run_wallpaper previous >/dev/null
wallpaper="$(run_wallpaper current)"
[[ "$wallpaper" == $'multi\t0\tFirst' ]] ||
  fail "wallpaper previous did not wrap: $wallpaper"
AWWW_LOG="$awww_log" run_wallpaper previous >/dev/null
wallpaper="$(run_wallpaper current)"
[[ "$wallpaper" == $'multi\t1\tSecond' ]] ||
  fail "wallpaper previous did not wrap from zero: $wallpaper"
wallpaper_before_failure="$wallpaper"
if AWWW_LOG="$awww_log" run_wallpaper_failure >/dev/null 2>&1; then
  fail 'Awww failure unexpectedly succeeded'
fi
[[ "$(run_wallpaper current)" == "$wallpaper_before_failure" ]] ||
  fail 'Awww failure changed the wallpaper index'

current_before_choose="$(run_theme current)"
run_theme_cancel
[[ "$(run_theme current)" == "$current_before_choose" ]] ||
  fail 'theme chooser cancellation changed the active theme'
wallpaper_before_choose="$(run_wallpaper current)"
run_wallpaper_cancel
[[ "$(run_wallpaper current)" == "$wallpaper_before_choose" ]] ||
  fail 'wallpaper chooser cancellation changed the active index'

install_fixture="$test_dir/install-repository"
install_home="$test_dir/install-home"
install_state="$test_dir/install-state"
install_process_home="$test_dir/install-process-home"
copy_fixture "$install_fixture"
mkdir -p -- "$install_home/.config" "$install_home/.config/walker" "$install_process_home"
ln -s -- "$install_fixture/.config/hypr" "$install_home/.config/hypr"
ln -s -- "$install_fixture/.config/ghostty" "$install_home/.config/ghostty"
printf 'user-owned Walker state\n' > "$install_home/.config/walker/unrelated.conf"
(
  export HOME="$install_process_home"
  export BLENDOS_WORKSTATION_TARGET_HOME="$install_home"
  export BLENDOS_WORKSTATION_TARGET_STATE_HOME="$install_state"
  export BLENDOS_WORKSTATION_TEST_NO_SUDO=1
  export PATH="$fake_bin:/usr/bin:/bin"
  bash "$install_fixture/install.sh" --home-only
) >/dev/null
[[ -d "$install_home/.config/hypr" && ! -L "$install_home/.config/hypr" ]] ||
  fail 'installer did not migrate the old Hyprland directory symlink'
[[ -d "$install_home/.config/ghostty" && ! -L "$install_home/.config/ghostty" ]] ||
  fail 'installer did not migrate the old Ghostty directory symlink'
[[ -f "$install_home/.config/walker/unrelated.conf" ]] ||
  fail 'installer lost an unrelated user-owned Walker file'
[[ -L "$install_home/.config/hypr/hyprland.lua" ]] ||
  fail 'installer did not deploy Hyprland at file granularity'
[[ -L "$install_home/.config/ghostty/config.ghostty" ]] ||
  fail 'installer did not deploy Ghostty at file granularity'
[[ -L "$install_home/.local/bin/blend_bin/session-walker" ]] ||
  fail 'installer did not deploy the Walker session wrapper'

run_repository_validator() (
  local repository="$1"
  export HOME="$test_dir/validator-home"
  export XDG_STATE_HOME="$test_dir/validator-state"
  export BLENDOS_WORKSTATION_THEME_NO_RELOAD=1
  export PATH="$fake_bin:/usr/bin:/bin"
  cd -- "$repository"
  bash scripts/validate-desktop-shell.sh
)

validator_base="$test_dir/validator-base"
copy_fixture "$validator_base"
run_repository_validator "$validator_base" >/dev/null

provider_case="$test_dir/validator-provider"
copy_fixture "$provider_case"
sed -i "/elephant-symbols/d" "$provider_case/system.yaml"
provider_output="$test_dir/provider-output"
if run_repository_validator "$provider_case" >"$provider_output" 2>&1; then
  fail 'validator accepted a missing Elephant provider package'
fi
grep -Fq 'Walker providers do not match Elephant packages' "$provider_output" ||
  fail 'missing provider package produced the wrong validator error'

target_case="$test_dir/validator-target"
copy_fixture "$target_case"
sed -i 's/ walker.service//' \
  "$target_case/.config/systemd/user/blendos-workstation-session.target"
target_output="$test_dir/target-output"
if run_repository_validator "$target_case" >"$target_output" 2>&1; then
  fail 'validator accepted a target without Walker ownership'
fi
grep -Fq 'walker.service is not owned by the desktop session target' "$target_output" ||
  fail 'missing target service produced the wrong validator error'

binding_case="$test_dir/validator-binding"
copy_fixture "$binding_case"
sed -i '/workstation-theme choose/d' "$binding_case/.config/hypr/hyprland.lua"
binding_output="$test_dir/binding-output"
if run_repository_validator "$binding_case" >"$binding_output" 2>&1; then
  fail 'validator accepted a missing theme binding'
fi
grep -Fq "theme-keybinding expects a Hyprland binding using 'workstation-theme'" \
  "$binding_output" || fail 'missing component binding produced the wrong validator error'

installed_fixture="$test_dir/installed-repository"
installed_home="$test_dir/installed-home"
installed_state="$test_dir/installed-state"
installed_process_home="$test_dir/installed-process-home"
copy_fixture "$installed_fixture"
mkdir -p -- "$installed_home" "$installed_process_home"
(
  export HOME="$installed_process_home"
  export BLENDOS_WORKSTATION_TARGET_HOME="$installed_home"
  export BLENDOS_WORKSTATION_TARGET_STATE_HOME="$installed_state"
  export BLENDOS_WORKSTATION_TEST_NO_SUDO=1
  export PATH="$fake_bin:/usr/bin:/bin"
  bash "$installed_fixture/install.sh" --home-only
) >/dev/null


cat > "$fake_bin/elephant" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$ELEPHANT_PROVIDERS"
EOF

cat > "$fake_bin/pacman" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == '-Q' ]]; then
  printf '%s 2.22.0-1\n' "$2"
fi
EOF

cat > "$fake_bin/systemd-analyze" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$fake_bin/journalctl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$fake_bin/ghostty" <<'EOF'
#!/usr/bin/env bash
printf '#89b4fa\n'
EOF

cat > "$fake_bin/workstation-theme" <<'EOF'
#!/usr/bin/env bash
exec "$INSTALLED_THEME_HELPER" "$@"
EOF

chmod u+x -- "$fake_bin/elephant" "$fake_bin/pacman" \
  "$fake_bin/systemd-analyze" "$fake_bin/journalctl" "$fake_bin/ghostty" \
  "$fake_bin/workstation-theme"

installed_providers=$'calc\nclipboard\ndesktopapplications\nfiles\nmenus:workstation\nmenus:workstation-notifications\nmenus:workstation-tools\nmenus:workstation-capture\nproviderlist\nrunner\nsymbols\nwebsearch\nwindows'
run_installed_validator() (
  export HOME="$installed_home"
  export XDG_STATE_HOME="$installed_state"
  export BLENDOS_WORKSTATION_THEME_NO_RELOAD=1
  export INSTALLED_THEME_HELPER="$installed_fixture/bin/workstation-theme"
  export ELEPHANT_PROVIDERS="$installed_providers"
  export DESKTOP_TEST_SESSION_DEPENDENCIES="${DESKTOP_TEST_SESSION_DEPENDENCIES-awww-daemon.service wallpaper-restore.service workstation-shell.service workstation-data.service workstation-launcher.service workstation-lock-guard.service hypridle.service dunst.service elephant.service walker.service}"
  export PATH="$fake_bin:/usr/bin:/bin"
  cd -- "$installed_fixture"
  bash scripts/validate-desktop-shell.sh --installed
)

run_installed_validator >/dev/null
installed_output="$test_dir/installed-output"
if DESKTOP_TEST_SESSION_DEPENDENCIES='awww-daemon.service wallpaper-restore.service workstation-shell.service workstation-data.service workstation-launcher.service workstation-lock-guard.service hypridle.service dunst.service elephant.service' \
    run_installed_validator >"$installed_output" 2>&1; then
  fail 'installed validator accepted a service outside the session dependencies'
fi
grep -Fq 'walker.service is not a dependency of the installed workstation session' "$installed_output" ||
  fail 'missing installed dependency produced the wrong validator error'
if installed_providers="${installed_providers/menus:workstation-capture/}" \
    run_installed_validator >"$installed_output" 2>&1; then
  fail 'installed validator accepted an unloaded managed menu'
fi
grep -Fq 'Elephant menu provider is not loaded: workstation-capture' "$installed_output" ||
  fail 'missing menu provider produced the wrong validator error'
rm -f -- "$installed_home/.config/walker/themes/blendos/theme.css"
if run_installed_validator >"$installed_output" 2>&1; then
  fail 'installed validator accepted a missing runtime theme symlink'
fi
grep -Fq 'runtime theme path is not a symlink' "$installed_output" ||
  fail 'missing runtime symlink produced the wrong installed validator error'

after_repo_status="$(git -C "$repo_dir" status --porcelain=v1 -- themes .config/hypr .config/ghostty .config/walker .config/dunst .config/gtk-3.0 .config/gtk-4.0)"
[[ "$after_repo_status" == "$before_repo_status" ]] ||
  fail 'desktop-shell tests changed repository status'

printf 'desktop shell tests passed.\n'
