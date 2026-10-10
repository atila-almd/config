#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

fixture="$test_dir/repository"
bash "$repo_dir/scripts/copy-source-fixture.sh" "$repo_dir" "$fixture"

run_validator() {
  (
    cd -- "$fixture"
    bash scripts/validate-shell-containers.sh
  )
}

run_validator >/dev/null

sed -i '/zsh_path="$(resolved_path "$zsh_command")"/d' "$fixture/install.sh"
if output="$(run_validator 2>&1)"; then
  printf 'validator accepted non-canonical login-shell wiring\n' >&2
  exit 1
fi
grep -Fq 'installer does not canonicalize Zsh before configuring the login shell' <<<"$output"

cp -- "$repo_dir/install.sh" "$fixture/install.sh"
sed -i "/run_privileged userdel -- 'gnome-initial-setup'/d" "$fixture/install.sh"
if output="$(run_validator 2>&1)"; then
  printf 'validator accepted missing GNOME transient-account cleanup\n' >&2
  exit 1
fi
grep -Fq 'installer does not remove the transient GNOME initial-setup account' <<<"$output"

printf 'shell/container tests passed.\n'
