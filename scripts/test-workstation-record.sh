#!/usr/bin/env bash

set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_dir="$(cd -- "$script_dir/.." && pwd -P)"
helper="$repo_dir/bin/workstation-record"
temporary_root="$(mktemp -d)"
trap 'rm -rf -- "$temporary_root"' EXIT
fake_bin="$temporary_root/bin"
mkdir -p -- "$fake_bin"
log="$temporary_root/calls"
mkdir -p -- "$temporary_root/home"

cat > "$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl\t%s\n' "$*" >> "$RECORD_TEST_LOG"
[[ "${1:-}" == --user ]] && shift
case "${1:-}" in
  is-active)
    target="${3:-}"
    if [[ "${RECORD_TEST_ACTIVE_TARGETS:-workstation}" == workstation && "$target" == blendos-workstation-session.target ]]; then exit 0; fi
    exit 3
    ;;
  show)
    [[ "${RECORD_TEST_SHOW_FAIL:-0}" != 1 ]] || exit 1
    printf '%s\n' "${RECORD_TEST_UNIT_STATE:-inactive}"
    ;;
  status)
    printf 'fake status for %s\n' "${2:-unknown}"
    case "${RECORD_TEST_UNIT_STATE:-inactive}" in active|activating|deactivating) exit 0 ;; *) exit 3 ;; esac
    ;;
  stop)
    exit "${RECORD_TEST_STOP_STATUS:-0}"
    ;;
  *)
    exit 0
    ;;
esac
EOF
cat > "$fake_bin/systemd-run" <<'EOF'
#!/usr/bin/env bash
printf 'systemd-run\n' >> "$RECORD_TEST_LOG"
printf '%s\n' "$@" >> "$RECORD_TEST_LOG"
exit "${RECORD_TEST_RUN_STATUS:-0}"
EOF
cat > "$fake_bin/slurp" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${RECORD_TEST_GEOMETRY:-11,22 333x444}"
exit "${RECORD_TEST_SLURP_STATUS:-0}"
EOF
cat > "$fake_bin/wf-recorder" <<'EOF'
#!/usr/bin/env bash
printf 'wf-recorder\n' >> "$RECORD_TEST_LOG"
EOF
cat > "$fake_bin/ffprobe" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${RECORD_TEST_FFPROBE_CODEC:-h264}"
exit "${RECORD_TEST_FFPROBE_STATUS:-0}"
EOF
chmod +x "$fake_bin"/* "$helper"

run_helper() {
  PATH="$fake_bin:$PATH" \
    RECORD_TEST_LOG="$log" \
    HOME="$temporary_root/home" \
    XDG_RUNTIME_DIR="$temporary_root/runtime" \
    WAYLAND_DISPLAY="wayland-1" \
    XDG_VIDEOS_DIR="$temporary_root/videos with spaces" \
    XDG_STATE_HOME="${XDG_STATE_HOME:-$temporary_root/state}" \
    "$helper" "$@"
}

assert_failure() {
  if "$@" >/dev/null 2>&1; then
    printf 'command unexpectedly succeeded: %s\n' "$*" >&2
    exit 1
  fi
}

: > "$log"
run_helper start --audio > "$temporary_root/start.out"
grep -Fq 'recording started; final output: '"$temporary_root/videos with spaces/Recordings/recording-" "$temporary_root/start.out"
grep -Fqx -- 'systemd-run' "$log"
grep -Fqx -- '--user' "$log"
grep -Fqx -- '--unit=blendos-recording' "$log"
grep -Fqx -- '--collect' "$log"
grep -Fqx -- '--expand-environment=no' "$log"
grep -Fqx -- '--setenv=WAYLAND_DISPLAY=wayland-1' "$log"
grep -Fq -- '--setenv=XDG_RUNTIME_DIR=' "$log"
grep -Fqx -- '--property=KillSignal=SIGINT' "$log"
grep -Fqx -- '--property=TimeoutStopSec=30' "$log"
grep -Fqx -- '--property=RuntimeMaxSec=2h' "$log"
grep -Fqx -- '--property=PartOf=blendos-workstation-session.target' "$log"
grep -Fqx -- '--property=After=blendos-workstation-session.target' "$log"
grep -Fqx -- '-g' "$log"
grep -Fqx -- '11,22 333x444' "$log"
grep -Fqx -- '--audio' "$log"
if grep -Fqx -- 'pkill' "$log"; then
  printf 'recording start used process-wide kill\n' >&2
  exit 1
fi
[[ -f "$temporary_root/state/blendos-workstation/recording/current" ]]
mapfile -t metadata < "$temporary_root/state/blendos-workstation/recording/current"
[[ "${metadata[0]}" == blendos-workstation-session.target ]]
saved_output="${metadata[1]}"
recording_directory="${metadata[2]}"
[[ "$saved_output" == "$temporary_root/videos with spaces/Recordings/recording-"*/recording.mp4 ]]
[[ "$recording_directory" == "$temporary_root/videos with spaces/Recordings/recording-"* ]]
[[ "$saved_output" != */.recording-*/* ]]
[[ -d "$recording_directory" ]]
[[ "${#metadata[@]}" -eq 3 ]]
grep -Fqx -- "$saved_output" "$log"

printf 'partial capture' > "$saved_output"
: > "$log"
run_helper stop > "$temporary_root/stop.out"
grep -Fqx $'systemctl\t--user stop blendos-recording.service' "$log"
grep -Fq 'recording stop requested; final output: ' "$temporary_root/stop.out"
[[ -s "$saved_output" ]]

: > "$log"
assert_failure env PATH="$fake_bin:$PATH" RECORD_TEST_LOG="$log" HOME="$temporary_root/home" \
  XDG_RUNTIME_DIR="$temporary_root/runtime" WAYLAND_DISPLAY="wayland-1" \
  XDG_VIDEOS_DIR="$temporary_root/videos with spaces" XDG_STATE_HOME="$temporary_root/state-both" \
  RECORD_TEST_ACTIVE_TARGETS=both "$helper" start
if grep -Fqx -- 'systemd-run' "$log"; then
  printf 'ambiguous session started a recorder\n' >&2
  exit 1
fi

: > "$log"
assert_failure env PATH="$fake_bin:$PATH" RECORD_TEST_LOG="$log" HOME="$temporary_root/home" \
  XDG_RUNTIME_DIR="$temporary_root/runtime" WAYLAND_DISPLAY="wayland-1" \
  XDG_VIDEOS_DIR="$temporary_root/videos with spaces" XDG_STATE_HOME="$temporary_root/state-none" \
  RECORD_TEST_ACTIVE_TARGETS=none "$helper" start
if grep -Fqx -- 'systemd-run' "$log"; then
  printf 'missing session target started a recorder\n' >&2
  exit 1
fi

: > "$log"
assert_failure env PATH="$fake_bin:$PATH" RECORD_TEST_LOG="$log" HOME="$temporary_root/home" \
  XDG_RUNTIME_DIR="$temporary_root/runtime" WAYLAND_DISPLAY="wayland-1" \
  XDG_VIDEOS_DIR="$temporary_root/videos with spaces" XDG_STATE_HOME="$temporary_root/state-cancel" \
  RECORD_TEST_SLURP_STATUS=130 "$helper" start
if grep -Fqx -- 'systemd-run' "$log"; then
  printf 'cancelled selection started a recorder\n' >&2
  exit 1
fi

: > "$log"
assert_failure env PATH="$fake_bin:$PATH" RECORD_TEST_LOG="$log" HOME="$temporary_root/home" \
  XDG_RUNTIME_DIR="$temporary_root/runtime" WAYLAND_DISPLAY="wayland-1" \
  XDG_VIDEOS_DIR="$temporary_root/videos with spaces" XDG_STATE_HOME="$temporary_root/state-duplicate" \
  RECORD_TEST_UNIT_STATE=activating "$helper" start
if grep -Fqx -- 'systemd-run' "$log"; then
  printf 'duplicate recording started a second recorder\n' >&2
  exit 1
fi

status_state="$temporary_root/status-state"
recording_state="$status_state/recording-test"
mkdir -p -- "$status_state/blendos-workstation/recording" "$recording_state"
printf 'valid video' > "$recording_state/recording.mp4"
printf '%s\n%s\n%s\n' blendos-workstation-session.target "$recording_state/recording.mp4" "$recording_state" > "$status_state/blendos-workstation/recording/current"
status_output="$temporary_root/status.out"
RECORD_TEST_UNIT_STATE=activating XDG_STATE_HOME="$status_state" run_helper status > "$status_output" 2>&1 || true
grep -Fqx 'recording is still running; output is currently non-empty: '"$recording_state/recording.mp4" "$status_output"
RECORD_TEST_UNIT_STATE=inactive XDG_STATE_HOME="$status_state" run_helper status > "$status_output" 2>&1
grep -Fqx 'recording completed with a readable video stream: '"$recording_state/recording.mp4" "$status_output"
grep -Fq $'systemctl\t--user status blendos-recording.service --no-pager' "$log"
: > "$temporary_root/empty.mp4"
printf '%s\n%s\n%s\n' blendos-workstation-session.target "$temporary_root/empty.mp4" "$status_state/missing-recording" > "$status_state/blendos-workstation/recording/current"
if RECORD_TEST_UNIT_STATE=inactive XDG_STATE_HOME="$status_state" run_helper status > "$status_output" 2>&1; then
  printf 'empty recording was reported as complete\n' >&2
  exit 1
fi
grep -Fqx 'recording output is empty or missing; no completed recording: '"$temporary_root/empty.mp4" "$status_output"

snapshot_state="$temporary_root/snapshot-state"
XDG_STATE_HOME="$snapshot_state" run_helper snapshot | jq -e '.schema_version==1 and .data=={run_id:null,state:"idle",can_stop:false}' >/dev/null
[[ ! -e "$snapshot_state" ]]
snapshot_directory="$temporary_root/recording-public"
mkdir -p "$snapshot_state/blendos-workstation/recording" "$snapshot_directory"
printf 'video' > "$snapshot_directory/recording.mp4"
printf '%s\n%s\n%s\n' blendos-workstation-session.target "$snapshot_directory/recording.mp4" "$snapshot_directory" > "$snapshot_state/blendos-workstation/recording/current"
RECORD_TEST_UNIT_STATE=active XDG_STATE_HOME="$snapshot_state" run_helper snapshot > "$temporary_root/snapshot.json"
jq -e '.data=={run_id:"recording-public",state:"recording",can_stop:true}' "$temporary_root/snapshot.json" >/dev/null
! grep -Fq "$temporary_root" "$temporary_root/snapshot.json"
RECORD_TEST_UNIT_STATE=deactivating XDG_STATE_HOME="$snapshot_state" run_helper snapshot | jq -e '.data.state=="stopping" and (.data.can_stop|not)' >/dev/null
XDG_STATE_HOME="$snapshot_state" run_helper snapshot | jq -e '.data.state=="completed"' >/dev/null
RECORD_TEST_FFPROBE_STATUS=1 XDG_STATE_HOME="$snapshot_state" run_helper snapshot | jq -e '.data.state=="failed"' >/dev/null
assert_failure env PATH="$fake_bin:$PATH" RECORD_TEST_LOG="$log" HOME="$temporary_root/home" XDG_STATE_HOME="$snapshot_state" RECORD_TEST_SHOW_FAIL=1 "$helper" snapshot
: > "$log"
if XDG_STATE_HOME="$snapshot_state" run_helper stop --expect-run recording-old; then exit 1; else [[ $? == 75 ]]; fi
! grep -Fq -- '--user stop' "$log"
XDG_STATE_HOME="$snapshot_state" run_helper stop --expect-run recording-public >/dev/null
grep -Fq -- '--user stop blendos-recording.service' "$log"
printf 'workstation-record lifecycle, public snapshots and stale stop tests passed\n'
