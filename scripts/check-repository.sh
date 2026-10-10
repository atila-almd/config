#!/usr/bin/env bash
# Repository checks only: never install, rebuild, or contact a graphical session.
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd -- "$repo_dir"
log="$(mktemp)"
trap 'rm -f -- "$log"' EXIT
for source in bootstrap install.sh bin/* scripts/*.sh; do bash -n "$source"; done
count=0
for check in scripts/validate-*.sh scripts/test-*.sh; do
  if bash "$check" >"$log" 2>&1; then
    printf 'PASS %s\n' "$check"
  else
    cat -- "$log" >&2
    printf 'FAIL %s\n' "$check" >&2
    exit 1
  fi
  count=$((count + 1))
done
git diff --check
printf '%s repository checks passed; installed/visual acceptance is separate.\n' "$count"
