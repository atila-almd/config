#!/usr/bin/env bash
# Exercise the two-boot protocol with disposable fixtures; never touch host state.
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
fixture="$temporary/checkout with spaces"
mkdir -p "$fixture/scripts" "$fixture/profiles" "$temporary/bin" "$temporary/home"
cp "$repo_dir/bootstrap" "$fixture/bootstrap"
cp "$repo_dir/system.yaml" "$fixture/system.yaml"
cp "$repo_dir/scripts/render-system-definition.py" "$fixture/scripts/"
cp "$repo_dir/profiles/"*.yaml "$fixture/profiles/"
printf 'ID=blendos\n' > "$temporary/os-release"
printf 'repo: fixture\n' > "$temporary/system.yaml"
printf 'before\n' > "$temporary/boot-id"
python3 - "$fixture/bootstrap" "$temporary" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]);s=p.read_text();root=sys.argv[2]
for old,new in [('/etc/os-release','/os-release'),('/system.yaml <<','/system.yaml <<'),('/proc/sys/kernel/random/boot_id','/boot-id')]:
    if old == '/system.yaml <<': s=s.replace(old,root+new)
    else: s=s.replace(old,root+new)
p.write_text(s)
PY
cat > "$temporary/bin/id" <<'EOF'
#!/bin/bash
printf '1000\n'
EOF
cat > "$temporary/bin/systemctl" <<'EOF'
#!/bin/bash
printf 'systemctl %s\n' "$*" >> "$BOOTSTRAP_LOG"
[[ "$*" != *is-active* ]]
EOF
cat > "$temporary/bin/sudo" <<'EOF'
#!/bin/bash
[[ "$*" == -v ]] && exit 0
[[ "$1" != -- ]] || shift
exec "$@"
EOF
cat > "$temporary/bin/akshara" <<'EOF'
#!/bin/bash
printf 'rebuild\n' >> "$BOOTSTRAP_LOG"
exit "${BUILD_STATUS:-0}"
EOF
cat > "$fixture/install.sh" <<'EOF'
#!/bin/bash
printf 'install %s %s\n' "$BLENDOS_WORKSTATION_MACHINE_PROFILE" "$*" >> "$BOOTSTRAP_LOG"
EOF
for command in pacman go jq mise zsh; do printf '#!/bin/bash\nexit 0\n' > "$temporary/bin/$command"; done
chmod +x "$temporary/bin/"*
export PATH="$temporary/bin:$PATH" HOME="$temporary/home" XDG_STATE_HOME="$temporary/state" BOOTSTRAP_LOG="$temporary/log"
: > "$BOOTSTRAP_LOG"
state="$XDG_STATE_HOME/blendos-workstation/machine"
expect_failure() { if "$@" > "$temporary/output" 2>&1; then printf 'unexpected bootstrap success\n' >&2; exit 1; fi; }
expect_failure bash "$fixture/bootstrap"
expect_failure bash "$fixture/bootstrap" '../physical'
expect_failure bash "$fixture/bootstrap" unknown
bash "$fixture/bootstrap" physical --dry-run > "$temporary/output"
[[ ! -e "$XDG_STATE_HOME" && ! -s "$BOOTSTRAP_LOG" ]]
grep -Fq 'RustDesk installation and remote-access acceptance are deferred' "$temporary/output"
! grep -Eq 'MISSING PREREQUISITE:.*(RustDesk|rustdesk)' "$temporary/output"
expect_failure bash "$fixture/bootstrap" physical --rustdesk-package /unused/package.pkg.tar.zst
expect_failure env XDG_STATE_HOME="$fixture/local-state" bash "$fixture/bootstrap" vm --dry-run
# A fresh target has no custom artifact, database, publisher or HTTP server.
# Failed builds leave no success receipts and may be retried.
expect_failure env BUILD_STATUS=9 bash "$fixture/bootstrap" physical
[[ ! -e "$state/pending.sha256" && ! -e "$state/completed.sha256" ]]
bash "$fixture/bootstrap" physical > "$temporary/output"
[[ -s "$state/pending.sha256" && "$(cat "$state/profile")" == physical ]]
[[ ! -e "$XDG_STATE_HOME/blendos-workstation/package-repo" && ! -e "$state/package-server.log" ]]
! grep -Eq 'rustdesk|workstation-local|package-repos' "$state/system.yaml"
[[ "$(grep -c '^rebuild$' "$BOOTSTRAP_LOG")" == 2 ]]
! grep -q '^install physical $' "$BOOTSTRAP_LOG"
# Same-boot reruns never deploy or rebuild, including a different requested profile.
bash "$fixture/bootstrap" physical > "$temporary/output"
bash "$fixture/bootstrap" vm > "$temporary/output"
[[ "$(grep -c '^rebuild$' "$BOOTSTRAP_LOG")" == 2 ]]
! grep -q '^install physical $' "$BOOTSTRAP_LOG"
printf 'after\n' > "$temporary/boot-id"
bash "$fixture/bootstrap" physical > "$temporary/output"
[[ -s "$state/completed.sha256" && ! -e "$state/pending.sha256" ]]
grep -q '^install physical $' "$BOOTSTRAP_LOG"
grep -q '^systemctl --user enable blendos-workstation-session.target$' "$BOOTSTRAP_LOG"
bash "$fixture/bootstrap" physical > "$temporary/output"
[[ "$(grep -c '^rebuild$' "$BOOTSTRAP_LOG")" == 2 ]]
# A deliberate profile change triggers another rebuild, then waits for reboot.
bash "$fixture/bootstrap" vm > "$temporary/output"
[[ "$(cat "$state/profile")" == vm && -s "$state/pending.sha256" ]]
[[ "$(grep -c '^rebuild$' "$BOOTSTRAP_LOG")" == 3 ]]
! grep -q '^install vm $' "$BOOTSTRAP_LOG"
printf 'bootstrap protocol tests passed (no custom artifact/server, dry-run, failed rebuild, reboot boundary, rerun, profile switch)\n'
