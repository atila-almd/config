#!/usr/bin/env bash

set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_dir="$(cd -- "$script_dir/.." && pwd -P)"
helper="$repo_dir/bin/workstation-project"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

fake_bin="$test_dir/bin"
minimal_bin="$test_dir/minimal-bin"
state="$test_dir/local-state"
project_root="$test_dir/projects with spaces"
project_one="$project_root/one"
project_two="$project_root/two"
log="$test_dir/terminal-argv"
mkdir -p -- "$fake_bin" "$minimal_bin" "$project_one" "$project_two"
ln -s -- "$(command -v readlink)" "$minimal_bin/readlink"
ln -s -- "$(command -v bash)" "$minimal_bin/bash"

cat > "$fake_bin/session-terminal" <<'EOF'
#!/usr/bin/env bash
printf '<%s>\n' "$@" >> "$PROJECT_TEST_LOG"
exit "${PROJECT_TEST_STATUS:-0}"
EOF
cat > "$fake_bin/walker" <<'EOF'
#!/usr/bin/env bash
if [[ "${PROJECT_TEST_ERROR:-0}" == 1 ]]; then
  exit 7
fi
if [[ "${PROJECT_TEST_CANCEL:-0}" == 1 ]]; then
  exit 1
fi
IFS= read -r choice || exit 1
printf '%s\n' "$choice"
EOF
cat > "$fake_bin/nvim" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$fake_bin/test-shell" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$fake_bin/agent-tool" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$fake_bin/workstation-agent" <<'EOF'
#!/usr/bin/env bash
printf '<agent-wrapper:%s>\n' "$*" >> "$PROJECT_TEST_LOG"
exit "${PROJECT_TEST_STATUS:-0}"
EOF
cat > "$fake_bin/argv-tool" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$fake_bin/systemd-run" <<'EOF'
#!/usr/bin/env bash
printf '<%s>\n' "$@" >> "$PROJECT_TEST_LOG"
exit "${PROJECT_TEST_STATUS:-0}"
EOF
chmod +x "$fake_bin"/*
mkdir -p -- "$project_one/scripts"
cat > "$project_one/scripts/dev" <<'EOF'
#!/usr/bin/env sh
exit 0
EOF
chmod +x "$project_one/scripts/dev"

run_helper() {
  PATH="$fake_bin:$PATH" \
    BLENDOS_WORKSTATION_PROJECT_STATE_HOME="$state" \
    PROJECT_TEST_LOG="$log" \
    PROJECT_TEST_ERROR="${PROJECT_TEST_ERROR:-0}" \
    SHELL="$fake_bin/test-shell" \
    bash "$helper" "$@"
}

empty_snapshot="$(run_helper list)"
jq -e '.schema_version == 1 and .data.items == [] and .data.selected_id == null' <<< "$empty_snapshot" >/dev/null ||
  fail 'empty snapshot has the wrong schema'
[[ ! -e "$state" ]] || fail 'read-only list created Local State'

if run_helper add '../escape' "$project_one" >/dev/null 2>&1; then
  fail 'path traversal project ID was accepted'
fi
if run_helper add missing "$test_dir/does-not-exist" >/dev/null 2>&1; then
  fail 'missing project directory was accepted'
fi
run_helper add one "$project_one" >/dev/null
run_helper add two "$project_two" >/dev/null
[[ "$(run_helper path one)" == "$project_one" ]] || fail 'path did not return canonical project directory'
run_helper instructions one --init >/dev/null
[[ -f "$project_one/AGENTS.md" ]] || fail 'instructions did not initialize AGENTS.md'
grep -Fq 'never executed automatically' "$project_one/AGENTS.md" || fail 'instructions template was not deployed'
if run_helper instructions one --init >/dev/null 2>&1; then
  fail 'instructions replaced an existing AGENTS.md'
fi
ln -s -- "$test_dir/missing-instructions" "$project_two/AGENTS.md"
if run_helper instructions two --init >/dev/null 2>&1; then
  fail 'instructions replaced a dangling AGENTS.md symlink'
fi
rm -- "$project_two/AGENTS.md"
if run_helper add one "$project_two" >/dev/null 2>&1; then
  fail 'duplicate project ID was accepted'
fi

list_output="$(run_helper list)"
jq -e '.data.items | length == 2 and all(.[]; .directory_available)' <<< "$list_output" >/dev/null ||
  fail 'list lost available projects'
jq -e '[.data.items[].id] == ["one","two"]' <<< "$list_output" >/dev/null || fail 'list lost project IDs'
if grep -Fq "$project_root" <<< "$list_output"; then fail 'snapshot exposed private project paths'; fi

run_helper choose one >/dev/null
grep -Fxq one "$state/selected" || fail 'explicit choose did not save Local State'
jq -e '.data.selected_id == "one"' <<< "$(run_helper list)" >/dev/null || fail 'snapshot omitted selection'

: > "$log"
run_helper open >/dev/null
grep -Fqx -- "<--working-directory=$project_one>" "$log" || fail 'open did not preserve the spaced directory'
grep -Fqx -- '<-e>' "$log" || fail 'open did not use Ghostty exec mode'
grep -Fqx -- "<$fake_bin/test-shell>" "$log" || fail 'open did not use the selected shell'

: > "$log"
run_helper open two editor >/dev/null
grep -Fqx -- "<--working-directory=$project_two>" "$log" || fail 'editor used the wrong directory'
grep -Fqx -- "<$fake_bin/nvim>" "$log" || fail 'editor did not launch nvim'

: > "$log"
marker="$test_dir/argv-injection-marker"
run_helper run one -- argv-tool 'arg with spaces' "\$(touch '$marker')" >/dev/null
grep -Fqx -- "<$fake_bin/argv-tool>" "$log" || fail 'run lost the command argv'
grep -Fqx -- '<arg with spaces>' "$log" || fail 'run split an argument containing spaces'
grep -Fqx -- "<\$(touch '$marker')>" "$log" || fail 'run changed an unsafe argument'
[[ ! -e "$marker" ]] || fail 'run evaluated an argument through a shell'

: > "$log"
run_helper dispatch agent one -- argv-tool 'arg with spaces' "\$(touch '$marker')"
grep -Fqx -- '<--property=PartOf=graphical-session.target>' "$log" || fail 'dispatch lost session lifecycle'
grep -Fqx -- "<$fake_bin/session-terminal>" "$log" || fail 'dispatch bypassed terminal wrapper'
grep -Fqx -- "<$fake_bin/workstation-agent>" "$log" || fail 'dispatch bypassed agent owner'
grep -Fqx -- "<\$(touch '$marker')>" "$log" || fail 'dispatch changed literal argv'
[[ ! -e "$marker" ]] || fail 'dispatch evaluated argv'
: > "$log"
if run_helper dispatch run one -- missing-workstation-executable >/dev/null 2>&1; then
  fail 'dispatch accepted unavailable command'
fi
[[ ! -s "$log" ]] || fail 'dispatch started a unit before command validation'

: > "$log"
run_helper run one -- ./scripts/dev --watch >/dev/null
grep -Fqx -- "<$project_one/scripts/dev>" "$log" || fail 'run did not resolve a project-relative command'

if run_helper run one -- command >/dev/null 2>&1; then
  fail 'run accepted a shell builtin as an executable'
else
  status=$?
fi
[[ "${status:-0}" == 127 ]] || fail 'builtin-only command did not return 127'

: > "$log"
PROJECT_TEST_STATUS=23 run_helper agent two -- agent-tool --flag 'value with spaces' >/dev/null || status=$?
[[ "${status:-0}" == 23 ]] || fail 'agent did not propagate terminal exit status'
grep -Fqx -- "<$fake_bin/workstation-agent>" "$log" || fail 'agent did not use workstation-agent'
grep -Fqx -- '<run>' "$log" || fail 'agent did not preserve wrapper action'
grep -Fqx -- '<two>' "$log" || fail 'agent did not preserve project ID'
grep -Fqx -- '<-->' "$log" || fail 'agent did not preserve wrapper delimiter'
grep -Fqx -- "<$fake_bin/agent-tool>" "$log" || fail 'agent lost the command executable'
grep -Fqx -- '<--flag>' "$log" || fail 'agent lost an option argv'

run_helper choose two >/dev/null
selection_before="$(<"$state/selected")"
if PROJECT_TEST_ERROR=1 run_helper choose >/dev/null 2>&1; then
  fail 'chooser error unexpectedly succeeded'
else
  status=$?
fi
[[ "${status:-0}" == 7 ]] || fail 'chooser error status was swallowed'
PROJECT_TEST_CANCEL=1 run_helper choose >/dev/null
[[ "$(<"$state/selected")" == "$selection_before" ]] || fail 'chooser cancellation changed selection'

if run_helper run ../escape -- true >/dev/null 2>&1; then
  fail 'run accepted a traversal ID'
fi
if run_helper run one true >/dev/null 2>&1; then
  fail 'run accepted a command without the argv delimiter'
fi

mv "$fake_bin/session-terminal" "$fake_bin/session-terminal.disabled"
if run_helper open two >/dev/null 2>&1; then
  fail 'open succeeded without session-terminal'
else
  status=$?
fi
[[ "${status:-0}" == 127 ]] || fail 'missing session-terminal did not return 127'
mv "$fake_bin/session-terminal.disabled" "$fake_bin/session-terminal"
rm -- "$fake_bin/nvim"
: > "$log"
if PATH="$minimal_bin:$fake_bin" \
    BLENDOS_WORKSTATION_PROJECT_STATE_HOME="$state" \
    PROJECT_TEST_LOG="$log" SHELL="$fake_bin/test-shell" \
    bash "$helper" open two editor >/dev/null 2>&1; then
  fail 'editor succeeded without nvim'
else
  status=$?
fi
[[ "$status" == 127 && ! -s "$log" ]] || fail 'missing editor launched a terminal or lost its failure status'

rm -rf -- "$project_two"
stale_list="$(run_helper list 2>"$test_dir/list-warning")"
jq -e '.data.items | map(select(.id == "one")) | .[0].directory_available == true' <<< "$stale_list" >/dev/null ||
  fail 'stale project hid a valid registration'
jq -e '.data.items | map(select(.id == "two")) | .[0].directory_available == false' <<< "$stale_list" >/dev/null ||
  fail 'list omitted stale registration state'
if run_helper open two >/dev/null 2>&1; then
  fail 'open accepted a missing project directory'
fi

run_helper remove two >/dev/null
if [[ -e "$state/entries/two" || -e "$state/selected" ]]; then
  fail 'remove did not clear the selected project state'
fi

printf 'workstation-project tests passed.\n'
