#!/usr/bin/env bash
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
for prerequisite in go gcc dbus-daemon dbus-run-session jq; do
  command -v "$prerequisite" >/dev/null || { printf 'Missing test prerequisite: %s\n' "$prerequisite" >&2; exit 1; }
done
cd -- "$repo_dir/services/desktop/data"
GOTOOLCHAIN=local go test -mod=readonly -race ./...
GOTOOLCHAIN=local go vet -mod=readonly ./...

# Exercise the shipped CLI, service entrypoint and actual helper JSON together.
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
bash "$repo_dir/scripts/build-workstation-data.sh" "$test_dir/workstation-data"
mkdir -m700 "$test_dir/home" "$test_dir/runtime" "$test_dir/project"
HOME="$test_dir/home" XDG_STATE_HOME="$test_dir/home/state" \
XDG_RUNTIME_DIR="$test_dir/runtime" PATH="$repo_dir/bin:$PATH" \
  dbus-run-session -- bash -s -- "$test_dir" <<'SMOKE'
set -Eeuo pipefail
test_dir="$1"
unset BLENDOS_WORKSTATION_PROJECT_STATE_HOME BLENDOS_WORKSTATION_AGENT_STATE_HOME
# The smoke uses an isolated bus for both transports; no host services are read.
export DBUS_SYSTEM_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS"
service_pid='' watch_pid=''
cleanup() {
  [[ -z "$watch_pid" ]] || kill "$watch_pid" 2>/dev/null || true
  [[ -z "$service_pid" ]] || kill "$service_pid" 2>/dev/null || true
  wait || true
}
trap cleanup EXIT
"$test_dir/workstation-data" serve >"$test_dir/service.log" 2>&1 &
service_pid=$!
for ((attempt=0; attempt<100; attempt++)); do
  [[ ! -S "$XDG_RUNTIME_DIR/blendos-workstation/data.sock" ]] || break
  kill -0 "$service_pid"
  sleep 0.05
done
"$test_dir/workstation-data" get projects | jq -e '.status == "ready" and .data.items == []' >/dev/null
"$test_dir/workstation-data" get agent_runs | jq -e '.status == "ready" and .data.items == []' >/dev/null
[[ ! -e "$XDG_STATE_HOME" ]]
"$test_dir/workstation-data" watch projects >"$test_dir/snapshots.jsonl" &
watch_pid=$!
workstation-project add smoke "$test_dir/project" >/dev/null
observed=false
for ((attempt=0; attempt<100; attempt++)); do
  if jq -se 'any(.[]; any(.data.items[]?; .id == "smoke" and .directory_available))' "$test_dir/snapshots.jsonl" >/dev/null; then
    observed=true
    break
  fi
  sleep 0.05
done
[[ "$observed" == true ]]
SMOKE
printf 'Data CLI and real helper subscription smoke passed.\n'
