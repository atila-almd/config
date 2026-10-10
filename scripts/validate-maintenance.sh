#!/usr/bin/env bash
# Cross-file ownership; no backup destination or hardware access is required.
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
units="$repo_dir/.config/systemd/user"
for unit in blendos-backup.service blendos-backup.timer; do
  [[ -f "$units/$unit" ]]
  grep -Fq ".config/systemd/user/$unit" "$repo_dir/install.sh"
  if grep -Eq 'blendos-workstation-session.target|ConditionEnvironment=WAYLAND_DISPLAY' "$units/$unit"; then
    printf 'Backup must be independent of the graphical session.\n' >&2; exit 1
  fi
done
grep -Fxq 'ExecStart=%h/.local/bin/blend_bin/workstation-backup run scheduled' "$units/blendos-backup.service"
grep -Fxq 'UMask=0077' "$units/blendos-backup.service"
grep -Fxq 'OnCalendar=daily' "$units/blendos-backup.timer"
grep -Fxq 'Persistent=true' "$units/blendos-backup.timer"
if grep -Eq 'enable.*blendos-backup|start.*blendos-backup' "$repo_dir/install.sh" ||
   grep -Fq "  - 'blendos-backup" "$repo_dir/system.yaml"; then
  printf 'Backup must not be enabled by installation or rebuild.\n' >&2; exit 1
fi
for helper in workstation-backup workstation-maintain; do
  grep -Fq "bin/$helper" "$repo_dir/install.sh"
  [[ -f "$repo_dir/bin/$helper" ]]
done
if [[ "${1:-}" == --installed ]]; then
  command -v restic >/dev/null
  command -v fwupdmgr >/dev/null
  systemd-analyze --user verify blendos-backup.service blendos-backup.timer
elif (($#)); then
  printf 'Usage: bash scripts/validate-maintenance.sh [--installed]\n' >&2; exit 2
fi
printf 'Maintenance contract passed; backup destination and recovery acceptance are separate.\n'
