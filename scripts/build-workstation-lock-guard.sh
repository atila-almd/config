#!/usr/bin/env bash
# Build into caller-owned staging; installation owns deployment and backups.
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
[[ $# == 1 && "$1" == /* ]] || { printf 'Usage: bash scripts/build-workstation-lock-guard.sh /absolute/output\n' >&2; exit 2; }
command -v go >/dev/null || { printf 'Missing Go; rebuild blendOS with the declared go package.\n' >&2; exit 1; }
cd -- "$repo_dir/services/desktop/data"
GOTOOLCHAIN=local CGO_ENABLED=0 go build -mod=readonly -trimpath -buildvcs=false -o "$1" ./cmd/workstation-lock-guard
