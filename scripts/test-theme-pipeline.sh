#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

expect_failure() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$description unexpectedly succeeded"
  fi
}

fixture="$test_dir/repository"
home="$test_dir/home"
state="$test_dir/state"
fake_bin="$test_dir/bin"
reload_failure_flag="$test_dir/reload-failure"
mkdir -p -- "$fixture" "$home" "$state" "$fake_bin"
bash "$repo_dir/scripts/copy-source-fixture.sh" "$repo_dir" "$fixture"
export THEME_RELOAD_FAILURE_FLAG="$reload_failure_flag"

cat > "$fake_bin/resvg" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "${RESVG_FAIL:-0}" == '1' ]]; then
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
if [[ "${WALKER_CANCEL:-0}" == '1' ]]; then
  exit 0
fi
printf '%s\n' "${WALKER_SELECTION:-}"
EOF

for command in systemctl hyprctl dunstctl gsettings workstation-wallpaper; do
  cat > "$fake_bin/$command" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
done
cat > "$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *kill*|*restart*|*reload*)
    [[ ! -f "$THEME_RELOAD_FAILURE_FLAG" ]] || exit 1
    ;;
esac
exit 0
EOF
cat > "$fake_bin/workstation-wallpaper" <<'EOF'
#!/usr/bin/env bash
[[ ! -f "$THEME_RELOAD_FAILURE_FLAG" ]] || exit 1
exit 0
EOF
cat > "$fake_bin/qs" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == -c && ( "$2" == workstation || "$2" == workstation-lock ) && "$3 $4 $5 $6" == 'ipc call -- theme' ]]
printf '%s\n' "$*" >> "$THEME_RELOAD_FAILURE_FLAG.qs"
[[ ! -f "$THEME_RELOAD_FAILURE_FLAG.qs-fail" ]]
case "$7" in
  reload) ;;
  release)
    if [[ -n "${QS_STALE_RELEASE:-}" && "$2" == "${QS_STALE_CONFIG:-workstation}" ]]; then printf '%s\n' "$QS_STALE_RELEASE";
    else basename -- "$(readlink -f -- "$BLENDOS_WORKSTATION_THEME_STATE_HOME/blendos-workstation/theme/current")"; fi
    ;;
  *) exit 1 ;;
esac
EOF
chmod u+x -- "$fake_bin"/*

helper="$fixture/bin/workstation-theme"
original_path="$PATH"

run_theme() (
  export HOME="$home"
  export XDG_CONFIG_HOME="$home/.config"
  export XDG_STATE_HOME="$state"
  export BLENDOS_WORKSTATION_THEME_STATE_HOME="$state"
  export BLENDOS_WORKSTATION_THEME_CONFIG_HOME="$home/.config"
  export BLENDOS_WORKSTATION_THEME_BUILTIN_HOME="$fixture/themes"
  export BLENDOS_WORKSTATION_THEME_NO_RELOAD=1
  export PATH="$fake_bin:$original_path"
  "$helper" "$@"
)

run_theme_reload() (
  export HOME="$home"
  export XDG_CONFIG_HOME="$home/.config"
  export XDG_STATE_HOME="$state"
  export BLENDOS_WORKSTATION_THEME_STATE_HOME="$state"
  export BLENDOS_WORKSTATION_THEME_CONFIG_HOME="$home/.config"
  export BLENDOS_WORKSTATION_THEME_BUILTIN_HOME="$fixture/themes"
  unset BLENDOS_WORKSTATION_THEME_NO_RELOAD
  export PATH="$fake_bin:$original_path"
  "$helper" "$@"
)

run_theme_reload_failure() (
  : > "$THEME_RELOAD_FAILURE_FLAG"
  run_theme_reload "$@"
)

grep -Fq 'catppuccin-mocha' <(run_theme list) || fail 'list omitted the bundled theme'
BLENDOS_WORKSTATION_THEME_STATE_HOME="$test_dir/absent-state" \
BLENDOS_WORKSTATION_THEME_CONFIG_HOME="$home/.config" \
BLENDOS_WORKSTATION_THEME_BUILTIN_HOME="$fixture/themes" \
RESVG_FAIL=1 "$helper" snapshot | jq -e '.schema_version==1 and .data.theme_id==null and .data.release_id==null and (.data.themes|length)==1' >/dev/null
[[ ! -e "$test_dir/absent-state" ]] || fail 'theme snapshot created private state'
run_theme validate catppuccin-mocha >/dev/null
run_theme validate --all >/dev/null

before_repo_status="$(git -C "$repo_dir" status --porcelain=v1 -- themes)"
run_theme set catppuccin-mocha --no-reload >/dev/null
current_link="$state/blendos-workstation/theme/current"
current_release="$(readlink -f -- "$current_link")"
case "$current_release" in
  "$state"/blendos-workstation/theme/releases/release-*) ;;
  *) fail 'current does not point into the release root' ;
esac
[[ -f "$current_release/manifest.json" ]] || fail 'active release has no manifest'
[[ "$(jq -er '.id' -- "$current_release/manifest.json")" == 'catppuccin-mocha' ]] ||
  fail 'active manifest has the wrong theme ID'
jq -e --slurpfile manifest "$current_release/manifest.json" '
  .schema_version == 1 and .theme_id == $manifest[0].id and
  .mode == $manifest[0].mode and .colors == $manifest[0].colors
' "$current_release/workstation-shell.json" >/dev/null || fail 'shell palette diverged from theme'
[[ "$(jq -r .release_id "$current_release/workstation-shell.json")" == "${current_release##*/}" ]] || fail 'shell palette lost exact release identity'
RESVG_FAIL=1 run_theme snapshot | jq -e --arg release "${current_release##*/}" '.data.release_id==$release and .data.theme_id=="catppuccin-mocha" and (.data.themes[0]|keys|sort)==["id","label","mode"]' >/dev/null
[[ "$(identify -format '%m' -- "$current_release/wallpaper.png")" == 'PNG' ]] ||
  fail 'SVG wallpaper was not rendered as PNG'

grep -Fq '#89b4fa' "$current_release/walker.css" || fail 'Walker missed the accent value'
python3 - "$current_release/dunst-theme.conf" "$current_release/manifest.json" <<'PY'
import configparser, json, pathlib, re, shlex, sys
config = configparser.ConfigParser(interpolation=None)
config.read(sys.argv[1])
colors = {}
for section in config.sections():
    for key, value in config.items(section):
        # Dunst treats unquoted # values as comments, not colors.
        tokens = shlex.split(value, comments=True)
        assert len(tokens) == 1 and re.fullmatch(r"#[0-9a-fA-F]{6}", tokens[0]), (section, key)
        colors[section, key] = tokens[0]
manifest = json.loads(pathlib.Path(sys.argv[2]).read_text())
assert colors['urgency_normal', 'background'] == manifest['colors']['surface']
PY
grep -Fq '89b4fa' "$current_release/hyprland-theme.lua" || fail 'Hyprland missed the accent value'
grep -Fq 'active_border = {' "$current_release/hyprland-theme.lua" || fail 'Hyprland active border is not a gradient table'
grep -Fq 'colors = {' "$current_release/hyprland-theme.lua" || fail 'Hyprland gradient has no colors array'
grep -Fq 'angle = 45' "$current_release/hyprland-theme.lua" || fail 'Hyprland gradient angle is missing'
grep -Fq '#1e1e2e' "$current_release/ghostty-theme.conf" || fail 'Ghostty missed the background value'
grep -Fq 'gtk-theme-name=Adwaita-dark' "$current_release/gtk-3.0-settings.ini" || fail 'GTK 3 missed the theme name'
grep -Fq 'gtk-theme-name=Adwaita-dark' "$current_release/gtk-4.0-settings.ini" || fail 'GTK 4 missed the theme name'

rollback_theme="$home/.config/blendos-workstation/themes/rollback-theme"
mkdir -p -- "$rollback_theme/wallpapers"
cp -- "$fixture/themes/catppuccin-mocha/wallpapers/default.svg" \
  "$rollback_theme/wallpapers/default.svg"
jq '.id = "rollback-theme" | .name = "Rollback Theme" | .mode = "light" |
    .colors.background = "#ffffff" | .colors.foreground = "#151515" | .colors.accent = "#0055aa"' \
  "$fixture/themes/catppuccin-mocha/theme.json" > "$rollback_theme/theme.json"
run_theme set rollback-theme --no-reload >/dev/null
jq -e '.theme_id == "rollback-theme" and .mode == "light" and
  .colors.background == "#ffffff" and .colors.foreground == "#151515" and
  .colors.accent == "#0055aa"' "$current_link/workstation-shell.json" >/dev/null ||
  fail 'shell palette did not follow the alternate theme'
prior_current="$(readlink -f -- "$current_link")"
prior_previous="$(readlink -f -- "$state/blendos-workstation/theme/previous")"
prior_selected="$(cat -- "$state/blendos-workstation/theme/selected")"
if run_theme_reload_failure set catppuccin-mocha >/dev/null 2>&1; then
  fail 'active reload failure unexpectedly succeeded'
fi
[[ "$(readlink -f -- "$current_link")" == "$prior_current" ]] ||
  fail 'reload rollback changed the current release'
[[ "$(readlink -f -- "$state/blendos-workstation/theme/previous")" == "$prior_previous" ]] ||
  fail 'reload rollback changed the previous release'
[[ "$(cat -- "$state/blendos-workstation/theme/selected")" == "$prior_selected" ]] ||
  fail 'reload rollback left selected theme state inconsistent'
rm -f -- "$reload_failure_flag"
run_theme_reload reload
[[ -s "$reload_failure_flag.qs" ]] || fail 'active shell theme reload was not requested'
touch "$reload_failure_flag.qs-fail"
if run_theme_reload set catppuccin-mocha >/dev/null 2>&1; then
  fail 'shell IPC failure unexpectedly succeeded'
fi
[[ "$(readlink -f -- "$current_link")" == "$prior_current" ]] || fail 'shell reload failure did not roll back'
rm -f -- "$reload_failure_flag.qs-fail"

# Acknowledging the same theme name from an earlier release is not success.
for consumer in workstation workstation-lock; do
  if QS_STALE_RELEASE="${prior_current##*/}" QS_STALE_CONFIG="$consumer" run_theme_reload set rollback-theme >/dev/null 2>&1; then
    fail "$consumer accepted an older release of the same theme"
  fi
  [[ "$(readlink -f -- "$current_link")" == "$prior_current" ]] || fail 'stale release acknowledgement did not roll back'
  [[ "$(cat -- "$state/blendos-workstation/theme/selected")" == "$prior_selected" ]] || fail 'stale acknowledgement changed selected theme'
done
run_theme_reload set rollback-theme >/dev/null
[[ "$(readlink -f -- "$current_link")" != "$prior_current" ]] || fail 'same-theme activation did not produce a new release'
prior_current="$(readlink -f -- "$current_link")"
prior_previous="$(readlink -f -- "$state/blendos-workstation/theme/previous")"

# Mutations cannot race a theme transaction and apply an observed wallpaper ID
# to a different release; snapshots do not render or create private directories.
wallpaper_helper="$fixture/bin/workstation-wallpaper"
run_wallpaper() (
  export HOME="$home" XDG_STATE_HOME="$state" XDG_CONFIG_HOME="$home/.config"
  export BLENDOS_WORKSTATION_THEME_STATE_HOME="$state" BLENDOS_WORKSTATION_THEME_CONFIG_HOME="$home/.config" BLENDOS_WORKSTATION_THEME_BUILTIN_HOME="$fixture/themes"
  export PATH="$fake_bin:$original_path"
  "$wallpaper_helper" "$@"
)
cat > "$fake_bin/awww" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$THEME_RELOAD_FAILURE_FLAG.awww"
EOF
chmod +x "$fake_bin/awww"
run_wallpaper snapshot | jq -e --arg release "${prior_current##*/}" '.data.release_id==$release and .data.wallpaper_id=="0" and (.data.items|length)==1' >/dev/null
[[ "$(run_wallpaper current)" == $'rollback-theme\t0\tDefault' ]] || fail 'wallpaper current could not read the default before private state exists'
[[ ! -e "$state/blendos-workstation/theme/wallpapers" ]] || fail 'wallpaper snapshot created state'
for expected in 'wrong-theme' 'rollback-theme'; do
  status=0
  expected_release="${prior_current##*/}"
  [[ "$expected" != rollback-theme ]] || expected_release=release-obsolete
  run_wallpaper set 0 --expect-theme "$expected" --expect-release "$expected_release" >/dev/null 2>&1 || status=$?
  [[ "$status" == 75 ]] || fail 'stale wallpaper request was not rejected'
done
[[ ! -e "$reload_failure_flag.awww" ]] || fail 'stale wallpaper request reached the daemon'
run_wallpaper set 0 --expect-theme rollback-theme --expect-release "${prior_current##*/}" >/dev/null
[[ -s "$reload_failure_flag.awww" ]] || fail 'current wallpaper request did not reach the daemon'
(
  exec 9>"$state/blendos-workstation/theme/operation.lock"
  flock 9
  status=0; run_wallpaper set 0 >/dev/null 2>&1 || status=$?
  [[ "$status" == 73 ]] || fail 'concurrent appearance mutation was accepted'
  # The renderer's child restore adopts its real inherited lock descriptor.
  WORKSTATION_THEME_LOCK_FD=9 run_wallpaper restore >/dev/null
)

old_current="$prior_current"
mkdir -p -- "$home/.config/blendos-workstation/themes/bad-color"
cp -a -- "$fixture/themes/catppuccin-mocha/." "$home/.config/blendos-workstation/themes/bad-color"
sed -i 's/"id": "catppuccin-mocha"/"id": "bad-color"/; s/#89b4fa/#nothex/' \
  "$home/.config/blendos-workstation/themes/bad-color/theme.json"
expect_failure 'invalid color validation' run_theme validate bad-color

mkdir -p -- "$home/.config/blendos-workstation/themes/missing-field"
cp -a -- "$fixture/themes/catppuccin-mocha/." "$home/.config/blendos-workstation/themes/missing-field"
sed -i '/"accent":/d; s/"id": "catppuccin-mocha"/"id": "missing-field"/' \
  "$home/.config/blendos-workstation/themes/missing-field/theme.json"
expect_failure 'missing field validation' run_theme validate missing-field

mkdir -p -- "$home/.config/blendos-workstation/themes/bad-traversal"
cp -a -- "$fixture/themes/catppuccin-mocha/." "$home/.config/blendos-workstation/themes/bad-traversal"
sed -i 's/"id": "catppuccin-mocha"/"id": "bad-traversal"/; s#wallpapers/default.svg#../outside.svg#' \
  "$home/.config/blendos-workstation/themes/bad-traversal/theme.json"
expect_failure 'wallpaper traversal validation' run_theme validate bad-traversal

mkdir -p -- "$home/.config/blendos-workstation/themes/missing-wallpaper"
cp -a -- "$fixture/themes/catppuccin-mocha/." "$home/.config/blendos-workstation/themes/missing-wallpaper"
sed -i 's/"id": "catppuccin-mocha"/"id": "missing-wallpaper"/; s#wallpapers/default.svg#wallpapers/no-such.svg#' \
  "$home/.config/blendos-workstation/themes/missing-wallpaper/theme.json"
expect_failure 'missing wallpaper validation' run_theme validate missing-wallpaper

printf '\n${THEME_NOT_ALLOWED}\n' >> "$fixture/themes/templates/walker.css.tpl"
expect_failure 'unresolved template token render' run_theme set catppuccin-mocha --no-reload
[[ "$(readlink -f -- "$current_link")" == "$old_current" ]] ||
  fail 'unresolved template failure changed current'
sed -i '$d' "$fixture/themes/templates/walker.css.tpl"

if RESVG_FAIL=1 run_theme set catppuccin-mocha --no-reload >/dev/null 2>&1; then
  fail 'renderer failure unexpectedly succeeded'
fi
[[ "$(readlink -f -- "$current_link")" == "$old_current" ]] ||
  fail 'renderer failure changed current'

WALKER_CANCEL=1 run_theme choose
[[ "$(readlink -f -- "$current_link")" == "$old_current" ]] ||
  fail 'theme chooser cancellation changed current'

after_repo_status="$(git -C "$repo_dir" status --porcelain=v1 -- themes)"
[[ "$after_repo_status" == "$before_repo_status" ]] ||
  fail 'applying a theme changed repository status'

printf 'theme pipeline tests passed.\n'
