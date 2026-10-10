#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
helper="$repo_dir/bin/git-profile"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

state_dir="$test_dir/state"
global_config="$test_dir/global.gitconfig"
personal_dir="$test_dir/Projects/personal"
work_dir="$test_dir/Projects/work"

mkdir -p -- "$personal_dir" "$work_dir"
git -C "$personal_dir" init -q
git -C "$work_dir" init -q

printf '%s\n' \
  '[include]' \
  "  path = $state_dir/config" \
  > "$global_config"

profile() {
  BLENDOS_WORKSTATION_GIT_STATE_HOME="$state_dir" \
    GIT_CONFIG_GLOBAL="$global_config" \
    bash "$helper" "$@"
}

profile add personal 'Personal User' personal@example.test >/dev/null
profile add work 'Work User' work@example.test >/dev/null
profile map personal "$personal_dir" >/dev/null
profile map work "$work_dir" >/dev/null

personal_email="$(GIT_CONFIG_GLOBAL="$global_config" git -C "$personal_dir" config user.email)"
work_email="$(GIT_CONFIG_GLOBAL="$global_config" git -C "$work_dir" config user.email)"
[[ "$personal_email" == 'personal@example.test' ]] || fail 'personal directory resolved the wrong identity'
[[ "$work_email" == 'work@example.test' ]] || fail 'work directory resolved the wrong identity'

show_output="$(profile show "$personal_dir")"
grep -Fq 'Personal User' <<<"$show_output" || fail 'show did not report the resolved identity'

if profile delete personal >/dev/null 2>&1; then
  fail 'mapped profiles must not be deleted'
fi

profile unmap "$personal_dir" >/dev/null
if GIT_CONFIG_GLOBAL="$global_config" git -C "$personal_dir" config user.email >/dev/null 2>&1; then
  fail 'unmapped directory retained an identity'
fi
profile delete personal >/dev/null

list_output="$(profile list)"
grep -Fq 'work: Work User <work@example.test>' <<<"$list_output" || fail 'list omitted the remaining profile'

printf 'git-profile tests passed.\n'
