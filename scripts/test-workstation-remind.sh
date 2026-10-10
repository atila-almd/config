#!/usr/bin/env bash
set -Eeuo pipefail
repo="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
mkdir "$test_dir/bin"
export REMIND_LOG="$test_dir/argv"
cat > "$test_dir/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == '--user is-active --quiet blendos-workstation-session.target' ]]; then
  exit "${REMIND_INACTIVE:-0}"
fi
printf '%s\n' "$@" > "$REMIND_LOG"
exit "${REMIND_FAILURE:-0}"
EOF
cat > "$test_dir/bin/systemd-run" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$REMIND_LOG"
exit "${REMIND_FAILURE:-0}"
EOF
printf '#!/bin/sh\nexit 0\n' > "$test_dir/bin/notify-send"
chmod +x "$test_dir/bin/"*
export PATH="$test_dir/bin:$PATH"
run() { bash "$repo/bin/workstation-remind" "$@"; }
id="$(run after 5m 'literal $HOME; message with spaces %u')"
[[ "$id" =~ ^[0-9]+-[0-9]+-[0-9]+$ ]]
grep -Fxq -- '--on-active=300s' "$REMIND_LOG"
grep -Fxq -- '--expand-environment=no' "$REMIND_LOG"
grep -Fxq -- '--timer-property=PartOf=blendos-workstation-session.target' "$REMIND_LOG"
grep -Fxq -- 'literal $HOME; message with spaces %u' "$REMIND_LOG"
run cancel "$id"
grep -Fxq -- "blendos-reminder-$id.timer" "$REMIND_LOG"
grep -Fxq -- "blendos-reminder-$id.service" "$REMIND_LOG"
run list
grep -Fxq -- 'blendos-reminder-*.timer' "$REMIND_LOG"
for delay in 0s -1m 25h 999999999999h '1m;echo' 1.5h; do
  : > "$REMIND_LOG"
  if run after "$delay" test >/dev/null 2>&1; then exit 1; fi
  [[ ! -s "$REMIND_LOG" ]]
done
if run cancel '../unrelated' >/dev/null 2>&1; then exit 1; fi
: > "$REMIND_LOG"
if REMIND_INACTIVE=3 run after 1m test >/dev/null 2>&1; then exit 1; fi
[[ ! -s "$REMIND_LOG" ]]
if REMIND_FAILURE=17 run after 1m test >/dev/null 2>&1; then exit 1; else status=$?; fi
[[ "$status" == 17 ]]
printf 'Reminder scope, literal argv, cancellation and failure tests passed.\n'
