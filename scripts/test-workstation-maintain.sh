#!/usr/bin/env bash
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
fixture="$temporary/checkout with spaces"
mkdir -p "$temporary/bin" "$fixture/bin" "$fixture/scripts" "$temporary/home"
cp "$repo_dir/bin/workstation-maintain" "$fixture/bin/workstation-maintain"
mkdir -p "$fixture/scripts"
cat > "$fixture/scripts/render-system-definition.py" <<'PY'
import os
if os.environ.get('MAINTAIN_WITH_CUSTOM_REPO') == '1':
    print("package-repos:\n  - name: workstation-local\n    repo-url: http://127.0.0.1:18789")
else:
    print('packages: [git]')
PY
for validator in validate-component-contract.sh validate-desktop-shell.sh validate-user-session.sh; do
  cat > "$fixture/scripts/$validator" <<'EOF'
#!/usr/bin/env bash
printf 'validator %s %s\n' "${0##*/}" "$*" >> "$MAINTAIN_LOG"
exit "${MAINTAIN_VALIDATOR_STATUS:-0}"
EOF
done
cat > "$temporary/bin/awk" <<'EOF'
#!/usr/bin/env bash
case "${*: -1}" in
  /etc/os-release) printf '%s\n' "${MAINTAIN_OS:-blendos}" ;;
  "$MAINTAIN_REPO/system.yaml") printf "http://127.0.0.1:18789\n" ;;
  *) exit 99 ;;
esac
EOF
cat > "$temporary/bin/readlink" <<'EOF'
#!/usr/bin/env bash
if [[ "${*: -1}" == /system.yaml ]]; then printf '%s/blendos-workstation/machine/system.yaml\n' "$XDG_STATE_HOME"; else /usr/bin/readlink "$@"; fi
EOF
cat > "$temporary/bin/cat" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == /proc/sys/kernel/random/boot_id ]]; then printf '%s\n' "${MAINTAIN_BOOT:-before}"; else /usr/bin/cat "$@"; fi
EOF
cat > "$temporary/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >> "$MAINTAIN_LOG"
case "$*" in
  *is-active*akshara-system-update*) exit "${MAINTAIN_UPDATER_STATUS:-3}" ;;
  *is-active*blendos-workstation-session.target) exit 0 ;;
  *--failed*) [[ "${MAINTAIN_FAILED_UNITS:-no}" == no ]] || printf 'broken.service failed\n' ;;
  *show*) printf 'ActiveState=inactive\nUnitFileState=disabled\n' ;;
  *) exit 98 ;;
esac
EOF
cat > "$temporary/bin/workstation-backup" <<'EOF'
#!/usr/bin/env bash
printf 'backup %s\n' "$*" >> "$MAINTAIN_LOG"
exit "${MAINTAIN_BACKUP_STATUS:-0}"
EOF
cat > "$temporary/bin/timeout" <<'EOF'
#!/usr/bin/env bash
printf 'package-repo probe\n' >> "$MAINTAIN_LOG"
case "${MAINTAIN_REPO_STATUS:-ok}" in
  ok) printf 'HTTP/1.0 200 OK\n' ;;
  notfound) printf 'HTTP/1.0 404 Not Found\n' ;;
  *) exit 1 ;;
esac
EOF
cat > "$temporary/bin/sudo" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == '-- akshara update' ]] || exit 97
printf 'sudo %s\n' "$*" >> "$MAINTAIN_LOG"
exit "${MAINTAIN_BUILD_STATUS:-0}"
EOF
for command in df akshara workstation-doctor; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$temporary/bin/$command"
done
chmod +x "$temporary/bin/"*
export PATH="$temporary/bin:$PATH" HOME="$temporary/home" XDG_STATE_HOME="$temporary/state"
export MAINTAIN_LOG="$temporary/log" MAINTAIN_REPO="$fixture"
export MAINTAIN_WITH_CUSTOM_REPO=1
mkdir -p "$XDG_STATE_HOME/blendos-workstation/machine"
printf 'package-repos:\n  - name: workstation-local\n    repo-url: http://127.0.0.1:18789\n' > "$XDG_STATE_HOME/blendos-workstation/machine/system.yaml"
printf 'vm\n' > "$XDG_STATE_HOME/blendos-workstation/machine/profile"
helper="$fixture/bin/workstation-maintain"
pending="$XDG_STATE_HOME/blendos-workstation/maintenance/pending.json"
expect_failure() { if "$@" > "$temporary/out" 2>&1; then printf 'unexpected success\n' >&2; exit 1; fi; }
: > "$MAINTAIN_LOG"
expect_failure env MAINTAIN_OS=ubuntu bash "$helper" update
[[ ! -s "$MAINTAIN_LOG" ]]
expect_failure env MAINTAIN_BACKUP_STATUS=3 bash "$helper" update
! grep -q '^sudo ' "$MAINTAIN_LOG"
expect_failure env MAINTAIN_REPO_STATUS=unavailable bash "$helper" update
! grep -q '^sudo ' "$MAINTAIN_LOG"
expect_failure env MAINTAIN_REPO_STATUS=notfound bash "$helper" update
! grep -q '^sudo ' "$MAINTAIN_LOG"
expect_failure env MAINTAIN_UPDATER_STATUS=0 bash "$helper" update
! grep -q '^sudo ' "$MAINTAIN_LOG"
# Current profiles have no custom repository. A retained database and a stopped
# server must not prevent either update preflight or a checkpointed rebuild.
export MAINTAIN_WITH_CUSTOM_REPO=0
python3 "$fixture/scripts/render-system-definition.py" > "$XDG_STATE_HOME/blendos-workstation/machine/system.yaml"
mkdir -p "$XDG_STATE_HOME/blendos-workstation/package-repo"
printf 'retained database\n' > "$XDG_STATE_HOME/blendos-workstation/package-repo/workstation-local.db"
: > "$MAINTAIN_LOG"
MAINTAIN_REPO_STATUS=unavailable bash "$helper" update > "$temporary/out"
! grep -q '^package-repo probe$' "$MAINTAIN_LOG"
[[ "$(grep -E '^backup|^sudo' "$MAINTAIN_LOG")" == $'backup check\nbackup run pre-update\nsudo -- akshara update' ]]
jq -e '.phase == "awaiting-reboot"' "$pending" >/dev/null
expect_failure bash "$helper" update
expect_failure bash "$helper" verify-update
expect_failure env MAINTAIN_BOOT=after MAINTAIN_VALIDATOR_STATUS=4 bash "$helper" verify-update
[[ -f "$pending" ]]
! grep -q 'backup run post-update' "$MAINTAIN_LOG"
expect_failure env MAINTAIN_BOOT=after MAINTAIN_FAILED_UNITS=yes bash "$helper" verify-update
[[ -f "$pending" ]]
MAINTAIN_BOOT=after bash "$helper" verify-update > "$temporary/out"
[[ ! -e "$pending" ]]
grep -q 'backup run post-update' "$MAINTAIN_LOG"
[[ -s "${pending%/*}/last-verified.json" ]]
expect_failure env MAINTAIN_BUILD_STATUS=7 bash "$helper" update
jq -e '.phase == "build-failed" and .exit_status == 7' "$pending" >/dev/null
bash "$helper" archive-record > "$temporary/out"
[[ ! -e "$pending" ]]
find "${pending%/*}" -name pending.json | grep -q /archived-
if grep -Eq 'sudo .*reboot|systemctl .*reboot|prune|forget' "$MAINTAIN_LOG"; then exit 1; fi
printf 'workstation-maintain tests passed\n'
