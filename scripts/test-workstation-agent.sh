#!/usr/bin/env bash

set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_dir="$(cd -- "$script_dir/.." && pwd -P)"
helper="$repo_dir/bin/workstation-agent"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
fake_bin="$test_dir/bin"
state="$test_dir/state"
project="$test_dir/project with spaces"
log="$test_dir/systemd-run.argv"
arg_log="$test_dir/command.argv"
mkdir -p -- "$fake_bin" "$project" "$state"

cat > "$fake_bin/workstation-project" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == path && "${2:-}" == demo ]] || exit 2
printf '%s\n' "$AGENT_TEST_PROJECT"
EOF
cat > "$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == --user && "${2:-}" == is-active && "${4:-}" == blendos-workstation-session.target ]]; then
  [[ "${AGENT_TEST_TARGET:-workstation}" == workstation ]]; exit
fi
if [[ "$*" == *' show '* ]]; then
  [[ "${AGENT_TEST_SHOW:-present}" != missing ]] || exit 1
  cat <<'PROPERTIES'
ActiveState=inactive
SubState=dead
Result=success
ExecMainStatus=0
CPUUsageNSec=1234
MemoryCurrent=5678
PROPERTIES
  exit 0
fi
exit 2
EOF
cat > "$fake_bin/systemd-run" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == --help ]]; then
  [[ "${AGENT_TEST_NO_EXPAND:-0}" == 1 ]] && { printf 'scope only\n'; exit 0; }
  printf ' --expand-environment=BOOL\n'
  exit 0
fi
printf '<%s>\n' "$@" >> "$AGENT_TEST_RUN_LOG"
while (($#)) && [[ "$1" != -- ]]; do shift; done
[[ "${1:-}" == -- ]] || exit 2
shift
"$@"
EOF
cat > "$fake_bin/time" <<'EOF'
#!/usr/bin/env bash
while (($#)); do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    --) shift; break ;;
    *) shift ;;
  esac
done
printf '0.01 0.02 0.03 4 0\n' > "$output"
"$@"
EOF
cat > "$fake_bin/argv-tool" <<'EOF'
#!/usr/bin/env bash
printf '<%s>\n' "$@" > "$AGENT_TEST_ARG_LOG"
exit "${AGENT_TEST_COMMAND_STATUS:-0}"
EOF
chmod +x "$fake_bin"/*

run_helper() {
  PATH="$fake_bin:$PATH" \
    BLENDOS_WORKSTATION_AGENT_STATE_HOME="$state" \
    BLENDOS_WORKSTATION_PROJECT_HELPER=workstation-project \
    BLENDOS_WORKSTATION_AGENT_TIME="$fake_bin/time" \
    AGENT_TEST_PROJECT="$project" AGENT_TEST_RUN_LOG="$log" AGENT_TEST_ARG_LOG="$arg_log" \
    AGENT_TEST_TARGET="${AGENT_TEST_TARGET:-workstation}" AGENT_TEST_SHOW="${AGENT_TEST_SHOW:-present}" \
    AGENT_TEST_NO_EXPAND="${AGENT_TEST_NO_EXPAND:-0}" AGENT_TEST_COMMAND_STATUS="${AGENT_TEST_COMMAND_STATUS:-0}" \
    bash "$helper" "$@"
}

output="$(run_helper run demo -- argv-tool 'arg with spaces' '$literal' '100%')"
run_id="$(printf '%s\n' "$output" | sed -n 's/^Run \(run-[^ ]*\) started.*/\1/p')"
[[ -n "$run_id" ]] || fail 'run did not print a stable ID'
grep -Fqx '<arg with spaces>' "$arg_log" || fail 'argv spaces were changed'
grep -Fqx '<$literal>' "$arg_log" || fail 'dollar argv was expanded'
grep -Fqx '<100%>' "$arg_log" || fail 'percent argv was changed'
grep -Fq -- '<--expand-environment=no>' "$log" || fail 'literal argv protection was not requested'
grep -Fq -- '<--property=PartOf=blendos-workstation-session.target>' "$log" || fail 'wrong session ownership'
grep -Fq -- '<--property=CPUAccounting=yes>' "$log" || fail 'CPU accounting was not requested'
grep -Fq -- '<--property=MemoryAccounting=yes>' "$log" || fail 'memory accounting was not requested'
record="$state/runs/$run_id/record.json"
jq -e '.state == "succeeded" and .rawstatus == "0" and .executable == "argv-tool" and .project_id == "demo" and has("project") and has("started_at") and has("ended_at")' "$record" >/dev/null || fail 'record fields are incorrect'
if jq -e 'has("argv") or has("prompt") or has("environment")' "$record" >/dev/null; then fail 'private record contains forbidden input data'; fi
[[ "$(stat -c '%a' "$state/runs/$run_id")" == 700 ]] || fail 'run directory is not private'

status_output="$(run_helper status "$run_id")"
jq -e '.schema_version == 1 and .data.items[0].cpu_usage_ns == "1234" and .data.items[0].memory_bytes == "5678" and .data.items[0].max_rss_kib == "4" and .data.items[0].provider_usage == null' <<< "$status_output" >/dev/null || fail 'JSON status omitted measured metrics'
if grep -Fq "$project" <<< "$status_output"; then fail 'status exposed private paths'; fi
jq -e '.data.items[0].project_id == "demo" and .data.items[0].state == "succeeded"' <<< "$(run_helper list)" >/dev/null || fail 'list did not return stored facts'
if ! AGENT_TEST_SHOW=missing run_helper status "$run_id" >/dev/null; then fail 'completed run became stale when its scope disappeared'; fi
[[ "$(jq -r .state "$record")" == succeeded ]] || fail 'completed record was rewritten after scope disappearance'

if AGENT_TEST_TARGET=none run_helper run demo -- argv-tool >/dev/null 2>&1; then fail 'missing target was accepted'; fi
if AGENT_TEST_NO_EXPAND=1 run_helper run demo -- argv-tool >/dev/null 2>&1; then fail 'unsupported systemd-run was accepted'; fi

tmp_record="$test_dir/running.json"
jq '.state = "running"' "$record" > "$tmp_record"
mv -- "$tmp_record" "$record"
record_before="$(sha256sum "$record")"
if AGENT_TEST_SHOW=missing run_helper status "$run_id" >/dev/null 2>"$test_dir/stale.err"; then fail 'missing running unit was accepted'; fi
grep -Fq 'state-lost' "$test_dir/stale.err" || fail 'missing unit was not state-lost'
[[ "$(sha256sum "$record")" == "$record_before" ]] || fail 'stale status rewrote metadata'
jq -e '.data.items[0].state == "running"' <<< "$(AGENT_TEST_SHOW=missing run_helper list)" >/dev/null ||
  fail 'stored list inferred process state'

# Metric strings preserve values beyond JavaScript integer precision.
jq '.cpu_usage_ns = "9007199254740993" | .memory_current = "18446744073709551615"' "$record" > "$tmp_record"
mv -- "$tmp_record" "$record"
jq -e '.data.items[0].cpu_usage_ns == "9007199254740993" and .data.items[0].memory_bytes == null' <<< "$(run_helper list)" >/dev/null ||
  fail 'snapshot rounded a counter or represented unavailable memory as a number'

AGENT_TEST_COMMAND_STATUS=7 run_helper run demo -- argv-tool >/dev/null || failed_status=$?
[[ "${failed_status:-0}" == 7 ]] || fail 'failed status was not propagated'
failed_id="$(jq -r 'select(.state == "failed") | .id' "$state"/runs/*/record.json | tail -n 1)"
failed_record="$state/runs/$failed_id/record.json"
[[ -n "$failed_record" ]] || fail 'failed run was not recorded'
jq -e '.rawstatus == "7"' "$failed_record" >/dev/null || fail 'failed run did not preserve launcher status'

AGENT_TEST_COMMAND_STATUS=130 run_helper run demo -- argv-tool >/dev/null || interrupted_status=$?
[[ "${interrupted_status:-0}" == 130 ]] || fail 'interrupted status was not propagated'
interrupted_id="$(jq -r 'select(.state == "interrupted") | .id' "$state"/runs/*/record.json | tail -n 1)"
[[ -n "$interrupted_id" ]] || fail 'interrupted run was not recorded'

printf 'workstation-agent tests passed.\n'
