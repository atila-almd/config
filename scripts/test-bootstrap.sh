#!/usr/bin/env bash
# Exercise the two-boot protocol with disposable fixtures; never touch host state.
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
temporary="$(mktemp -d)"
server_pid=''
trap '[[ -z "$server_pid" ]] || kill "$server_pid" 2>/dev/null || true; rm -rf -- "$temporary"' EXIT
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
expect_failure env XDG_STATE_HOME="$fixture/local-state" bash "$fixture/bootstrap" vm --dry-run
# Supply a reviewed-repository fixture and reuse a test-owned loopback server.
package_repo="$XDG_STATE_HOME/blendos-workstation/package-repo"
mkdir -p "$package_repo"
printf 'fixture database\n' > "$package_repo/workstation-local.db"
port="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
sed -i "s/127.0.0.1:18789/127.0.0.1:$port/g" "$fixture/bootstrap"
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$package_repo" > "$temporary/http.log" 2>&1 &
server_pid=$!
for ((attempt=0;attempt<50;attempt++)); do
  python3 - "$port" <<'PY' >/dev/null 2>&1 && break
import sys,urllib.request
urllib.request.urlopen('http://127.0.0.1:'+sys.argv[1]+'/workstation-local.db',timeout=.1)
PY
  sleep .05
done
# Failed builds leave no success receipts and may be retried.
expect_failure env BUILD_STATUS=9 bash "$fixture/bootstrap" physical
[[ ! -e "$state/pending.sha256" && ! -e "$state/completed.sha256" ]]
bash "$fixture/bootstrap" physical > "$temporary/output"
[[ -s "$state/pending.sha256" && "$(cat "$state/profile")" == physical ]]
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
printf 'bootstrap protocol tests passed (dry-run, failed rebuild, reboot boundary, rerun, profile switch)\n'
