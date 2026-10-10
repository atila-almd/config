#!/usr/bin/env bash
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
export BLENDOS_WORKSTATION_TARGET_HOME="$test_dir/home"
export BLENDOS_WORKSTATION_TARGET_STATE_HOME="$test_dir/state"
export BLENDOS_WORKSTATION_IDENTITY_ROOT="$test_dir/system-share/identity"
mkdir -p "$test_dir/home/.config/ghostty"
printf 'personal terminal settings\n' > "$test_dir/home/.config/ghostty/config.ghostty"
printf 'unmanaged terminal notes\n' > "$test_dir/home/.config/ghostty/original"
printf 'existing system definition\n' > "$test_dir/system.yaml"
ln -s "$test_dir/system.yaml" "$test_dir/home/system.yaml"
bash "$repo_dir/install.sh" --home-only > "$test_dir/first.log"
data_binary="$test_dir/home/.local/libexec/blendos-workstation/workstation-data"
[[ -x "$data_binary" && ! -L "$data_binary" ]]
[[ "$(stat -c %a "$data_binary")" == 755 ]]
[[ "$("$data_binary" version)" == 'workstation-data protocol 1' ]]
launcher_binary="$test_dir/home/.local/libexec/blendos-workstation/workstation-launcher"
[[ -x "$launcher_binary" && ! -L "$launcher_binary" ]]
[[ "$("$launcher_binary" version)" == 'workstation-launcher protocol 1' ]]
[[ "$(stat -c %a "$test_dir/home/.config/systemd/user/workstation-data.service")" == 644 ]]
[[ "$(stat -c %a "$test_dir/home/.config/systemd/user/workstation-shell.service")" == 644 ]]
[[ -L "$test_dir/home/.config/quickshell/workstation" ]]
[[ -L "$test_dir/home/.config/quickshell/workstation-lock" ]]
[[ -L "$test_dir/home/.config/quickshell/WorkstationShared" ]]
[[ -L "$test_dir/home/.config/autostart/vboxclient.desktop" ]]
grep -Fxq 'Hidden=true' "$test_dir/home/.config/autostart/vboxclient.desktop"
[[ "$(stat -c %a "$test_dir/home/.config/systemd/user/vboxclient-vmsvga.service")" == 644 ]]
[[ -x "$test_dir/home/.local/libexec/blendos-workstation/workstation-lock-guard" ]]
[[ -L "$test_dir/home/.local/share/wayland-sessions/workstation.desktop" ]]
[[ "$(readlink -f "$test_dir/home/.config/systemd/user/wayland-session@workstation.desktop.target.wants/blendos-workstation-session.target")" == "$test_dir/home/.config/systemd/user/blendos-workstation-session.target" ]]
[[ -L "$test_dir/home/.local/bin/blend_bin/session-workstation-shell" ]]
[[ "$(readlink "$test_dir/home/system.yaml")" == "$test_dir/system.yaml" ]]
grep -Fxq 'existing system definition' "$test_dir/system.yaml"
backup="$(find "$test_dir/state" -path '*/backups/*' -type f -name config.ghostty)"
[[ -n "$backup" ]]
grep -Fxq 'personal terminal settings' "$backup"
[[ -d "$test_dir/home/.config/ghostty" && ! -L "$test_dir/home/.config/ghostty" ]]
[[ -L "$test_dir/home/.config/ghostty/config.ghostty" ]]
grep -Fxq 'unmanaged terminal notes' "$test_dir/home/.config/ghostty/original"
unit="$test_dir/home/.config/systemd/user/blendos-workstation-session.target"
[[ -f "$unit" && ! -L "$unit" ]]
[[ "$(stat -c %a "$unit")" == 644 ]]
find "$test_dir/state" -path '*/backups/*' -type f | sort > "$test_dir/before"
bash "$repo_dir/install.sh" --home-only > "$test_dir/second.log"
find "$test_dir/state" -path '*/backups/*' -type f | sort > "$test_dir/after"
cmp "$test_dir/before" "$test_dir/after"
if grep -q 'Backed up' "$test_dir/second.log"; then
  printf 'ERROR: unchanged rerun displaced files\n' >&2
  exit 1
fi
if grep -Eq 'systemctl .* (restart|stop|kill|isolate) ' "$repo_dir/install.sh"; then
  printf 'ERROR: installer can interrupt an active session\n' >&2
  exit 1
fi
export BLENDOS_WORKSTATION_SYSTEM_PATH="$test_dir/root-system.yaml"
export BLENDOS_WORKSTATION_TEST_NO_SUDO=1
bash "$repo_dir/install.sh" --system-only > "$test_dir/system-first.log"
[[ "$(readlink -f "$test_dir/root-system.yaml")" == "$repo_dir/system.yaml" ]]
bash "$repo_dir/install.sh" --system-only > "$test_dir/system-second.log"
if grep -q 'Backed up' "$test_dir/system-second.log"; then
  printf 'ERROR: unchanged system-only rerun displaced files\n' >&2
  exit 1
fi
if bash "$repo_dir/install.sh" --home-only --system-only > /dev/null 2>&1; then
  printf 'ERROR: contradictory modes were accepted\n' >&2
  exit 1
fi
mkdir "$test_dir/mock-bin"
printf '#!/bin/sh\nexit 0\n' > "$test_dir/mock-bin/systemctl"
chmod +x "$test_dir/mock-bin/systemctl"
if HOME="$BLENDOS_WORKSTATION_TARGET_HOME" PATH="$test_dir/mock-bin:$PATH" \
    bash "$repo_dir/install.sh" --home-only > "$test_dir/active.log" 2>&1; then
  printf 'ERROR: active graphical session was accepted\n' >&2
  exit 1
fi
grep -q 'inactive graphical session' "$test_dir/active.log"
if grep -Eq 'Linked|Installed|Backed up' "$test_dir/active.log"; then
  printf 'ERROR: active-session rejection occurred after deployment\n' >&2
  exit 1
fi
printf 'Installer rerun, backups, unit permissions and home-only isolation passed.\n'

# Exercise the real-home branch while forbidding runtime/system operations.
cat > "$test_dir/mock-bin/systemctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  '--user is-active --quiet graphical-session.target') exit 3 ;;
  '--user daemon-reload') exit 0 ;;
  *) printf 'Unexpected service mutation: %s\n' "$*" >&2; exit 99 ;;
esac
EOF
for forbidden in sudo mise sysctl usermod ufw; do
  printf '#!/bin/sh\necho "Forbidden configuration-only operation" >&2\nexit 99\n' > "$test_dir/mock-bin/$forbidden"
done
chmod +x "$test_dir/mock-bin/"*
HOME="$BLENDOS_WORKSTATION_TARGET_HOME" PATH="$test_dir/mock-bin:$PATH" \
  bash "$repo_dir/install.sh" --config-only > "$test_dir/config-first.log"
HOME="$BLENDOS_WORKSTATION_TARGET_HOME" PATH="$test_dir/mock-bin:$PATH" \
  bash "$repo_dir/install.sh" --config-only > "$test_dir/config-second.log"
if grep -q 'Backed up' "$test_dir/config-second.log"; then
  printf 'ERROR: config-only rerun displaced unchanged files\n' >&2; exit 1
fi
if bash "$repo_dir/install.sh" --config-only --system-only >/dev/null 2>&1; then exit 1; fi
printf 'Configuration-only real-home branch skips runtime/account/system setup.\n'

for unit in blendos-backup.service blendos-backup.timer; do
  installed_unit="$test_dir/home/.config/systemd/user/$unit"
  [[ -f "$installed_unit" && ! -L "$installed_unit" ]]
  [[ "$(stat -c %a "$installed_unit")" == 644 ]]
done
[[ ! -e "$test_dir/home/.config/systemd/user/timers.target.wants/blendos-backup.timer" ]]
printf 'Backup units are copied with safe permissions and remain disabled.\n'

# Exercise the documented scoped restore in the disposable home. Preserve the
# managed link for diagnosis, then restore the displaced regular file itself.
mv -- "$test_dir/home/.config/ghostty/config.ghostty" "$test_dir/managed-ghostty-link"
cp -a -- "$backup" "$test_dir/home/.config/ghostty/config.ghostty"
[[ -f "$test_dir/home/.config/ghostty/config.ghostty" && ! -L "$test_dir/home/.config/ghostty/config.ghostty" ]]
grep -Fxq 'personal terminal settings' "$test_dir/home/.config/ghostty/config.ghostty"
grep -Fxq 'unmanaged terminal notes' "$test_dir/home/.config/ghostty/original"
[[ -L "$test_dir/managed-ghostty-link" ]]
printf 'Scoped backup restore passed; unrelated files and managed link preserved.\n'
