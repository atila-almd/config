#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
components="$repo_dir/components.tsv"
system_config="$repo_dir/system.yaml"
session_target="$repo_dir/.config/systemd/user/blendos-workstation-session.target"
dunst_config="$repo_dir/.config/dunst/dunstrc"
shell_qml="$repo_dir/.config/quickshell/workstation/shell.qml"
card_qml="$repo_dir/.config/quickshell/workstation/surfaces/IslandCard.qml"
data_protocol="$repo_dir/services/desktop/data/internal/data/protocol.go"
data_adapter="$repo_dir/services/desktop/data/internal/data/notifications.go"
data_test="$repo_dir/services/desktop/data/internal/data/notifications_test.go"
controls="$repo_dir/bin/workstation-controls"
notification_menu="$repo_dir/.config/elephant/menus/workstation-notifications.toml"
errors=0

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  errors=$((errors + 1))
}

expect_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "required notification contract file is missing: $path"
}

expect_text() {
  local path="$1"
  local text="$2"
  grep -Fq -- "$text" "$path" || fail "'$text' is missing from $path"
}

for path in \
  "$repo_dir/AGENTS.md" \
  "$repo_dir/README.md" \
  "$repo_dir/components.tsv" \
  "$repo_dir/docs/plans/README.md" \
  "$repo_dir/docs/plans/009-notifications-and-osd.md" \
  "$repo_dir/services/desktop/README.md" \
  "$repo_dir/services/desktop/API.md" \
  "$repo_dir/services/desktop/ISLAND.md" \
  "$repo_dir/services/desktop/UPSTREAM.md" \
  "$repo_dir/services/desktop/CHECKLIST.md"; do
  expect_file "$path"
done

# Option 1 reuses the current owners. The adapter does not justify a second
# daemon, package, session unit or compositor launch path.
expect_text "$system_config" "  - 'dunst'"
expect_text "$session_target" 'dunst.service'
expect_text "$components" $'notifications\tdunst\tdunst\tsystemd-user:dunst.service'
expect_text "$components" $'notification-history\tquickshell\tsession-workstation-shell\thypr:binding'
expect_text "$components" $'notification-control\tdunst\tdunstctl\thypr:binding'
expect_text "$components" 'Plan 009 Option 1'
expect_text "$repo_dir/.config/systemd/user/workstation-data.service" 'ExecStart=%h/.local/libexec/blendos-workstation/workstation-data serve'
expect_text "$shell_qml" 'notifications'
expect_text "$shell_qml" 'root.surfaceState === "expanded" && root.cardWidget === "notifications"'
expect_text "$card_qml" 'id: notificationsCard'
expect_text "$data_protocol" 'Notifications Topic = "notifications"'
expect_text "$data_adapter" 'NotificationListHistory'
expect_text "$data_test" 'TestDunstLoadsExactBoundedSanitizedContract'
expect_text "$controls" 'notifications.set_dnd'
expect_text "$notification_menu" 'session-workstation-shell --card notifications'
expect_text "$notification_menu" 'dunstctl history-clear'

# The active Dunst configuration supplies the persistence/markup boundaries
# that the adapter preserves.
expect_text "$dunst_config" 'history_length = 50'
expect_text "$dunst_config" 'markup = full'
expect_text "$dunst_config" 'sticky_history = yes'

# The selected option adds no competing notification owner or OSD package.
if grep -Eiq '^[[:space:]]*-[[:space:]]*.(swayosd|wob|mako|fnott|deadd-notification-center).' "$system_config"; then
  fail 'system.yaml declares a competing notification/OSD package'
fi

# Validate the written contract and its audit trail without claiming that
# installed or visual guest acceptance is complete.
plan="$repo_dir/docs/plans/009-notifications-and-osd.md"
api="$repo_dir/services/desktop/API.md"
island="$repo_dir/services/desktop/ISLAND.md"
upstream="$repo_dir/services/desktop/UPSTREAM.md"
checklist="$repo_dir/services/desktop/CHECKLIST.md"

expect_text "$plan" 'Status: IMPLEMENTED IN SOURCE'
expect_text "$plan" 'Selected Option 1'
expect_text "$plan" 'workstation-data'
expect_text "$plan" 'Island attention'
expect_text "$plan" 'guest acceptance pending'
expect_text "$api" 'notifications'
expect_text "$api" 'unread_count'
expect_text "$api" '"actions": []'
expect_text "$api" 'RFC3339'
expect_text "$api" 'history_length = 50'
expect_text "$api" 'workstation-data service'
expect_text "$island" 'Option 1'
expect_text "$island" 'opens the card'
expect_text "$island" 'attention surface'
expect_text "$upstream" 'v1.13.2'
expect_text "$upstream" '312ed56fbcdc84823c99f21008467561394a8eb1'
expect_text "$upstream" 'NotificationListHistory'
expect_text "$upstream" 'NotificationHistoryRemoved'
expect_text "$upstream" 'BSD-3-Clause'
expect_text "$upstream" 'No Dunst source is vendored'
expect_text "$checklist" 'Plan 009 Option 1 source checkpoint'
expect_text "$checklist" 'guest acceptance pending'

# The keybinding now reaches the lazy history card; Dunst still owns live
# popup close/pause operations.
expect_text "$repo_dir/.config/hypr/hyprland.lua" 'session-workstation-shell --card notifications'
expect_text "$repo_dir/README.md" 'lazy Island history card'

if ((errors)); then
  printf '\nNotification contract validation failed with %d error(s).\n' "$errors" >&2
  exit 1
fi

printf 'notification contract valid: Option 1 owners, limits and source wiring are documented.\n'
