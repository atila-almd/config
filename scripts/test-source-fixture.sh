#!/usr/bin/env bash
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
mkdir -p "$temporary/source/bin" "$temporary/source/.git"
printf '#!/bin/sh\nexit 0\n' > "$temporary/source/bin/public-helper"
printf 'public contributor instructions\n' > "$temporary/source/AGENTS.md"
# These are newly created sentinels, never the owner's private files.
printf 'do not copy\n' > "$temporary/source/.private-bootstrap.sh"
printf 'do not copy\n' > "$temporary/source/private-root-sentinel"
printf 'do not copy\n' > "$temporary/source/.git/config"
bash "$repo_dir/scripts/copy-source-fixture.sh" "$temporary/source" "$temporary/destination"
[[ -f "$temporary/destination/bin/public-helper" ]]
[[ -f "$temporary/destination/AGENTS.md" ]]
[[ ! -e "$temporary/destination/.private-bootstrap.sh" ]]
[[ ! -e "$temporary/destination/private-root-sentinel" ]]
[[ ! -e "$temporary/destination/.git" ]]
printf 'Public source fixture excludes private root sentinels and Git metadata.\n'
