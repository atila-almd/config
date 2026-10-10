#!/usr/bin/env bash
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
shell_dir="$repo_dir/.config/quickshell/workstation"
mode="${1:---source}"
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
case "$mode" in
  --source)
    (($# <= 1)) || fail 'Unexpected arguments'
    grep -Fxq '//@ pragma UseQApplication' "$shell_dir/shell.qml" || fail 'Native tray menus require QApplication mode'
    for source in shell.qml components/ProjectAgentPanel.qml components/AudioDeviceRow.qml components/MediaControlRow.qml models/AudioLabels.js surfaces/ControlCenter.qml surfaces/Bar.qml surfaces/Projects.qml surfaces/AgentStatus.qml surfaces/Launcher.qml adapters/ElephantLauncher.qml adapters/Controls.qml adapters/Audio.qml adapters/Media.qml adapters/Desktop.qml adapters/WorkstationData.qml ../WorkstationShared/AuthForm.qml ../WorkstationShared/ThemedPane.qml ../WorkstationShared/Contract.js ../WorkstationShared/qmldir; do
      [[ -s "$shell_dir/$source" ]] || fail "Missing shell source: $source"
    done
    for package in quickshell qt6-declarative go; do
      grep -Fxq "  - '$package'" "$repo_dir/system.yaml" || fail "Undeclared package: $package"
    done
    for reference in .config/quickshell/workstation .config/systemd/user/workstation-shell.service .config/systemd/user/workstation-data.service .config/systemd/user/workstation-launcher.service bin/session-workstation-shell bin/workstation-launcher; do
      grep -Fq "'$reference'" "$repo_dir/install.sh" || grep -Fxq "  $reference" "$repo_dir/install.sh" || fail "Undeployed source: $reference"
    done
    for unit in workstation-shell workstation-data workstation-launcher; do
      boundary=blendos-workstation-session.target
      grep -Fxq "PartOf=$boundary" "$repo_dir/.config/systemd/user/$unit.service" || fail "$unit escaped the session boundary"
      ! grep -q '^WantedBy=' "$repo_dir/.config/systemd/user/$unit.service" || fail "$unit unexpectedly starts at login"
    done
    [[ -s "$shell_dir/../workstation-lock/shell.qml" ]] || fail 'Missing independent locker'
    grep -Fq 'config: "workstation-lock"' "$shell_dir/../workstation-lock/shell.qml" || fail 'Locker lost its PAM contract'
    ! grep -Eq 'function (unlock|close)' "$shell_dir/../workstation-lock/shell.qml" || fail 'Locker exposes a release IPC'
    [[ -s "$repo_dir/services/desktop/identity/shell.qml" ]] || fail 'Missing graphical greeter'
    grep -Fq 'Quickshell.Services.Greetd' "$repo_dir/services/desktop/identity/shell.qml" || fail 'Greeter lost the native greetd adapter'
    ! grep -Fq 'PamContext' "$repo_dir/services/desktop/identity/shell.qml" || fail 'Greeter must not own PAM authentication'
    if grep -REn '(^|[[:space:]])(Quickshell|Timer|Process|FileView)[[:space:]]*\{' "$shell_dir/components" "$shell_dir/surfaces" "$shell_dir/../WorkstationShared"; then
      fail 'Presentation components acquired backend or timer ownership'
    fi
    jq -e '.projects.schema_version == 1 and .agent_runs.schema_version == 1 and
      (.projects.data.items | length) > 0 and (.agent_runs.data.items | length) > 0' \
      "$repo_dir/scripts/fixtures/workstation-shell/preview.json" >/dev/null
    printf 'Workstation shell source contract passed.\n'
    ;;
  --lint)
    (($# == 1)) || fail 'Unexpected arguments'
    lint="${QMLLINT:-/usr/lib/qt6/bin/qmllint}"
    [[ -x "$lint" ]] || fail 'Native Qt qmllint is required'
    command -v qs >/dev/null || fail 'Native Quickshell types are required for full lint'
    lint_args=(--max-warnings 0 -I "$shell_dir/..")
    IFS=: read -ra import_paths <<< "${QML_IMPORT_PATH:-}"
    for import_path in "${import_paths[@]}"; do
      [[ -z "$import_path" ]] || lint_args+=(-I "$import_path")
    done
    mapfile -d '' files < <(find "$shell_dir" "$shell_dir/../workstation-lock" "$shell_dir/../WorkstationShared" "$repo_dir/services/desktop/identity" -name '*.qml' -type f -print0)
    "$lint" "${lint_args[@]}" "${files[@]}"
    ;;
  --render)
    shift
    exec bash "$repo_dir/scripts/check-workstation-shell-render.sh" "$@"
    ;;
  --live)
    (($# == 1)) || fail 'Unexpected arguments'
    exec bash "$repo_dir/scripts/check-workstation-shell-live.sh"
    ;;
  *) fail 'Usage: bash scripts/check-workstation-shell.sh [--source|--lint|--live|--render /ABSOLUTE/NEW-REPORT-DIRECTORY]' ;;
esac
