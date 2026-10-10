#!/usr/bin/env bash
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
helper="$repo_dir/bin/workstation-controls"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
mkdir "$test_dir/bin" "$test_dir/home"
export HOME="$test_dir/home" XDG_STATE_HOME="$test_dir/state" CONTROL_TEST_LOG="$test_dir/calls"
export PATH="$test_dir/bin:/usr/bin:/bin"
for name in pavucontrol nm-connection-editor session-workstation-shell systemd-run wpctl playerctl systemctl uwsm session-lock workstation-suspend dunstctl; do
  cat > "$test_dir/bin/$name" <<'FAKE'
#!/usr/bin/env bash
printf '%s' "${0##*/}" >> "$CONTROL_TEST_LOG"
printf ' <%s>' "$@" >> "$CONTROL_TEST_LOG"
printf '\n' >> "$CONTROL_TEST_LOG"
exit "${CONTROL_TEST_STATUS:-0}"
FAKE
done
cat > "$test_dir/bin/systemd-detect-virt" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "${CONTROL_TEST_VIRT:-none}"
FAKE
chmod +x "$test_dir/bin/"*
run() {
  export BLENDOS_WORKSTATION_PROFILE_FILE="$test_dir/profile"
  if [[ "${CONTROL_TEST_VIRT:-none}" == oracle ]]; then printf "vm\n" > "$test_dir/profile"; else printf "physical\n" > "$test_dir/profile"; fi
  bash "$helper" "$@"
}
request() { jq -cn --arg action "$1" --argjson args "${2:-\{\}}" '{schema_version:1,request_id:"test-1",action:$action,args:$args}'; }
dispatch() { run dispatch "$(request "$@")"; }
expect() { local filter="$1"; shift; "$@" | jq -e "$filter" >/dev/null; }

: > "$CONTROL_TEST_LOG"
run audio; run media; run display; run power; run settings; run notifications
grep -Fxq 'session-workstation-shell <--controls> <audio>' "$CONTROL_TEST_LOG"
grep -Fxq 'session-workstation-shell <--controls> <outputs>' "$CONTROL_TEST_LOG"
grep -Fxq 'session-workstation-shell <--controls> <settings>' "$CONTROL_TEST_LOG"
grep -Fxq 'session-workstation-shell <--controls> <notifications>' "$CONTROL_TEST_LOG"
run network
grep -Fxq 'nm-connection-editor <>' "$CONTROL_TEST_LOG"
cat > "$test_dir/bin/pavucontrol" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "${GSK_RENDERER:-unset}" > "$CONTROL_TEST_LOG"
FAKE
CONTROL_TEST_VIRT=oracle GSK_RENDERER= run audio-mixer
grep -Fxq cairo "$CONTROL_TEST_LOG"
CONTROL_TEST_VIRT=none GSK_RENDERER= run audio-mixer
grep -Fxq unset "$CONTROL_TEST_LOG"
CONTROL_TEST_VIRT=oracle GSK_RENDERER=gl run audio-mixer
grep -Fxq gl "$CONTROL_TEST_LOG"

expect '.status=="error" and .error.code=="invalid_request"' run dispatch '{"schema_version":2}'
for args in '{"id":"17","volume":1.1}' '{"id":"@DEFAULT_AUDIO_SINK@","volume":0.5}' '{"id":"17; touch secret","volume":0.5}' '{"id":"17","volume":"0.5"}' '{"id":"17","volume":0.5,"extra":true}'; do
  expect '.error.code=="invalid_request"' dispatch audio.set_volume "$args"
done
: > "$CONTROL_TEST_LOG"
expect '.status=="ok" and .request_id=="test-1"' dispatch audio.set_volume '{"id":"17","volume":0.25}'
grep -Fxq 'wpctl <set-volume> <17> <0.25> <--limit> <1>' "$CONTROL_TEST_LOG"
expect '.status=="ok"' dispatch audio.set_mute '{"id":"17","muted":false}'
grep -Fxq 'wpctl <set-mute> <17> <0>' "$CONTROL_TEST_LOG"
expect '.status=="ok"' dispatch media.next '{"id":"org.mpris.MediaPlayer2.demo.instance1"}'
grep -Fxq 'playerctl <--player> <demo.instance1> <next>' "$CONTROL_TEST_LOG"
CONTROL_TEST_STATUS=3 expect '.error.code=="stale_id"' dispatch audio.set_default '{"id":"17"}'
CONTROL_TEST_STATUS=2 expect '.error.code=="backend_unavailable"' dispatch audio.set_default '{"id":"17"}'

: > "$CONTROL_TEST_LOG"
expect '.status=="ok"' dispatch notifications.show '{"id":"17"}'
grep -Fxq 'dunstctl <history-pop> <17>' "$CONTROL_TEST_LOG"
expect '.status=="ok"' dispatch notifications.dismiss '{"id":"17"}'
grep -Fxq 'dunstctl <history-rm> <17>' "$CONTROL_TEST_LOG"
expect '.status=="ok"' dispatch notifications.clear '{}'
grep -Fxq 'dunstctl <history-clear>' "$CONTROL_TEST_LOG"
expect '.status=="ok"' dispatch notifications.set_dnd '{"paused":true}'
grep -Fxq 'dunstctl <set-paused> <true>' "$CONTROL_TEST_LOG"
expect '.error.code=="invalid_request"' dispatch notifications.dismiss '{"id":"17","extra":true}'
expect '.error.code=="invalid_request"' dispatch notifications.dismiss '{"id":"-1"}'
expect '.error.code=="invalid_request"' dispatch notifications.set_dnd '{"paused":"yes"}'
expect '.error.code=="invalid_request"' dispatch notifications.clear '{"extra":true}'

: > "$CONTROL_TEST_LOG"
expect '.status=="cancelled" and .error==null' dispatch power.shutdown '{"confirmed":false}'
[[ ! -s "$CONTROL_TEST_LOG" ]]
expect '.error.code=="invalid_request"' dispatch power.shutdown '{}'
expect '.status=="ok"' dispatch power.shutdown '{"confirmed":true}'
grep -Fxq 'systemctl <poweroff>' "$CONTROL_TEST_LOG"

expect '.status=="ok" and .data=={schema_version:1}' dispatch settings.export '{}'
[[ ! -e "$XDG_STATE_HOME" ]]
expect '.error.code=="invalid_request"' dispatch settings.update '{"text_scale":3}'
[[ ! -e "$XDG_STATE_HOME" ]]
expect '.status=="ok" and .data.text_scale==1.25' dispatch settings.update '{"text_scale":1.25}'
settings="$XDG_STATE_HOME/blendos-workstation/shell/settings.json"
[[ "$(stat -c %a "$settings")" == 600 && "$(stat -c %a "${settings%/*}")" == 700 ]]
# Independent updates serialize their read/merge/write and retain both fields.
for iteration in {1..8}; do
  dispatch settings.reset '{}' >/dev/null
  dispatch settings.update '{"density":"compact"}' > "$test_dir/density.json" & density_pid=$!
  dispatch settings.update '{"text_scale":1.5}' > "$test_dir/scale.json" & scale_pid=$!
  wait "$density_pid" "$scale_pid"
  jq -e '.status=="ok"' "$test_dir/density.json" "$test_dir/scale.json" >/dev/null
  jq -e '.density=="compact" and .text_scale==1.5' "$settings" >/dev/null
done
printf '{"schema_version":1,"private_path":"secret"}\n' > "$settings"
expect '.error.code=="invalid_settings"' dispatch settings.export '{}'
expect '.error.code=="invalid_settings"' dispatch settings.update '{"density":"spacious"}'
expect '.status=="ok" and .data=={schema_version:1}' dispatch settings.reset '{}'
mv "$settings" "$test_dir/saved-settings"
ln -s "$test_dir/saved-settings" "$settings"
expect '.error.code=="invalid_settings"' dispatch settings.export '{}'
expect '.error.code=="settings_failed"' dispatch settings.reset '{}'
[[ "$(cat "$test_dir/saved-settings")" == '{"schema_version":1}' ]]

cat > "$test_dir/bin/workstation-theme" <<'FAKE'
#!/usr/bin/env bash
printf '{"schema_version":1,"data":{"theme_id":"dark","release_id":"release-new","themes":[]}}\n'
FAKE
cat > "$test_dir/bin/workstation-record" <<'FAKE'
#!/usr/bin/env bash
printf '{"schema_version":1,"data":{"run_id":"recording-current","state":"recording","can_stop":true}}\n'
FAKE
chmod +x "$test_dir/bin/workstation-theme" "$test_dir/bin/workstation-record"
expect '.error.code=="stale_id"' dispatch appearance.set_wallpaper '{"id":"0","theme_id":"dark","release_id":"release-old"}'
expect '.error.code=="stale_id"' dispatch recording.stop '{"run_id":"recording-old"}'
rm "$settings"
mv "$test_dir/saved-settings" "$settings"
# Activation between helper reads must not publish a mixed release. The next
# bounded attempt sees the new complete pair without rendering any assets.
export CONTROL_THEME_READS="$test_dir/theme-reads"
cat > "$test_dir/bin/workstation-theme" <<'FAKE'
#!/usr/bin/env bash
release=release-old
[[ ! -e "$CONTROL_THEME_READS" ]] || release=release-new
printf x >> "$CONTROL_THEME_READS"
jq -cn --arg release "$release" '{schema_version:1,data:{theme_id:"dark",release_id:$release,themes:[]}}'
FAKE
cat > "$test_dir/bin/workstation-wallpaper" <<'FAKE'
#!/usr/bin/env bash
printf '{"schema_version":1,"data":{"theme_id":"dark","release_id":"release-new","wallpaper_id":"0","items":[{"id":"0","label":"New wallpaper"}]}}\n'
FAKE
chmod +x "$test_dir/bin/workstation-wallpaper"
expect '.data.release_id=="release-new" and .data.wallpapers[0].label=="New wallpaper"' run snapshot
[[ "$(cat "$CONTROL_THEME_READS")" == xx ]]
printf 'workstation-controls typed commands, cancellation, stale IDs and atomic private settings tests passed.\n'
