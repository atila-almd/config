#!/usr/bin/env bash

set -Eeuo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_dir="$(cd -- "$script_dir/.." && pwd -P)"
helper="$repo_dir/bin/workstation-keybindings"
temporary_root="$(mktemp -d)"
trap 'rm -rf -- "$temporary_root"' EXIT
fake_bin="$temporary_root/bin"; mkdir -p -- "$fake_bin"
log="$temporary_root/walker-input"

cat > "$fake_bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
if [[ "${KEYBINDINGS_HYPRCTL_MODE:-ok}" == fail ]]; then exit 7; fi
if [[ "${KEYBINDINGS_HYPRCTL_MODE:-ok}" == malformed ]]; then printf '{broken'; exit 0; fi
cat <<'JSON'
[{"modmask":68,"key":"Q","dispatcher":"exec","arg":"ghostty","description":"Open terminal"},
 {"modmask":8,"key":"E","dispatcher":"exec","arg":"echo fallback","description":""},
 {"modmask":0,"key":"PRINT","dispatcher":"exec","arg":"workstation-capture region"},
 {"modmask":0,"key":"","keycode":42,"dispatcher":"exec","arg":"echo code","description":"Code binding"},
 {"modmask":0,"key":"","mouse":true,"dispatcher":"exec","arg":"echo mouse","description":"Mouse binding"},
 {"modmask":0,"key":"A","dispatcher":"exec","arg":"echo line","description":"Line\nwrapped"}]
JSON
EOF
cat > "$fake_bin/jq" <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/jq "$@"
EOF
cat > "$fake_bin/walker" <<'EOF'
#!/usr/bin/env bash
cat > "$KEYBINDINGS_WALKER_LOG"
if [[ "${KEYBINDINGS_WALKER_MODE:-ok}" == fail ]]; then exit 9; fi
if [[ "${KEYBINDINGS_WALKER_MODE:-ok}" == cancel ]]; then exit 1; fi
if [[ -n "${KEYBINDINGS_SELECTION:-}" ]]; then printf '%s\n' "$KEYBINDINGS_SELECTION"; fi
EOF
chmod +x "$fake_bin"/* "$helper"
run_helper() { PATH="$fake_bin:$PATH" KEYBINDINGS_WALKER_LOG="$log" "$helper" "$@"; }

run_helper
grep -Fqx 'SUPER + CTRL + Q — Open terminal' "$log"
grep -Fqx 'ALT + E — exec echo fallback' "$log"
grep -Fqx 'PRINT — exec workstation-capture region' "$log"
grep -Fqx 'keycode:42 — Code binding' "$log"
grep -Fqx 'mouse — Mouse binding' "$log"
grep -Fqx 'A — Line wrapped' "$log"

KEYBINDINGS_SELECTION='$(touch /tmp/should-not-run)' run_helper
[[ ! -e /tmp/should-not-run ]] || { rm -f /tmp/should-not-run; exit 1; }
KEYBINDINGS_WALKER_MODE=cancel run_helper
if KEYBINDINGS_WALKER_MODE=fail run_helper; then exit 1; fi
if KEYBINDINGS_HYPRCTL_MODE=fail run_helper; then exit 1; fi
if KEYBINDINGS_HYPRCTL_MODE=malformed run_helper; then exit 1; fi
printf 'workstation-keybindings tests passed\n'
