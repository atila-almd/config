#!/usr/bin/env bash

set -Eeuo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_dir="$(cd -- "$script_dir/.." && pwd -P)"
helper="$repo_dir/bin/workstation-capture"
temporary_root="$(mktemp -d)"
trap 'rm -rf -- "$temporary_root"' EXIT
fake_bin="$temporary_root/bin"; mkdir -p -- "$fake_bin"
log="$temporary_root/calls"
cat > "$fake_bin/hyprshot" <<'EOF'
#!/usr/bin/env bash
printf 'hyprshot\n' >> "$CAPTURE_TEST_LOG"
printf '%s\n' "$@" >> "$CAPTURE_TEST_LOG"
output=''; filename=''
while (($#)); do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    -f) filename="$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [[ "${CAPTURE_TEST_STATUS:-0}" == 0 && "${CAPTURE_TEST_NO_FILE:-0}" != 1 && -n "$output" && -n "$filename" ]]; then
  mkdir -p -- "$output"
  printf 'PNG' > "$output/$filename"
fi
exit "${CAPTURE_TEST_STATUS:-0}"
EOF
cat > "$fake_bin/hyprpicker" <<'EOF'
#!/usr/bin/env bash
printf 'hyprpicker\n' >> "$CAPTURE_TEST_LOG"
printf '%s\n' "$@" >> "$CAPTURE_TEST_LOG"
EOF
cat > "$fake_bin/wl-copy" <<'EOF'
#!/usr/bin/env bash
printf 'wl-copy\n' >> "$CAPTURE_TEST_LOG"
EOF
cat > "$fake_bin/slurp" <<'EOF'
#!/usr/bin/env bash
printf 'slurp\n' >> "$CAPTURE_TEST_LOG"
[[ "${CAPTURE_TEST_SLURP_STATUS:-0}" == 0 ]] || exit "$CAPTURE_TEST_SLURP_STATUS"
printf '10,20 300x200\n'
EOF
cat > "$fake_bin/grim" <<'EOF'
#!/usr/bin/env bash
printf 'grim\n' >> "$CAPTURE_TEST_LOG"
printf '%s\n' "$@" >> "$CAPTURE_TEST_LOG"
output="${@: -1}"
[[ "${CAPTURE_TEST_GRIM_STATUS:-0}" == 0 ]] || exit "$CAPTURE_TEST_GRIM_STATUS"
printf 'PNG' > "$output"
EOF
chmod +x "$fake_bin"/* "$helper"
run_helper() {
  PATH="$fake_bin:$PATH" CAPTURE_TEST_LOG="$log" CAPTURE_TEST_STATUS="${CAPTURE_TEST_STATUS:-0}" CAPTURE_TEST_NO_FILE="${CAPTURE_TEST_NO_FILE:-0}" XDG_PICTURES_DIR="${CAPTURE_TEST_PICTURES:-$temporary_root/pictures}" HOME="$temporary_root/home" "$helper" "$@"
}
run_helper region
grep -Fqx -- '-m' "$log"; grep -Fqx -- 'region' "$log"; grep -Fqx -- '-o' "$log"; grep -Fqx -- "$temporary_root/pictures/Screenshots" "$log"
rm -rf -- "$temporary_root/pictures"
: > "$log"; run_helper clipboard; grep -Fqx -- '--clipboard-only' "$log"; [[ ! -d "$temporary_root/pictures" ]]
if CAPTURE_TEST_STATUS=1 run_helper clipboard >/dev/null 2>&1; then printf 'clipboard hyprshot failure unexpectedly succeeded\n' >&2; exit 1; fi
if grep -Fqx -- '-o' "$log"; then printf 'clipboard-only capture unexpectedly saved\n' >&2; exit 1; fi
: > "$log"; run_helper color; grep -Fqx -- 'hyprpicker' "$log"; grep -Fqx -- '--autocopy' "$log"
if run_helper window --clipboard-only >/dev/null 2>&1; then printf 'window clipboard-only capture unexpectedly succeeded\n' >&2; exit 1; fi
: > "$log"; CAPTURE_TEST_STATUS=130 run_helper output >/dev/null
if CAPTURE_TEST_STATUS=1 run_helper output >/dev/null 2>&1; then printf 'hyprshot failure unexpectedly succeeded\n' >&2; exit 1; fi
if CAPTURE_TEST_NO_FILE=1 run_helper output >/dev/null 2>&1; then printf 'missing screenshot unexpectedly succeeded\n' >&2; exit 1; fi
: > "$log"; CAPTURE_TEST_PICTURES="$temporary_root/pictures with spaces" run_helper window >/dev/null
grep -Fqx -- "$temporary_root/pictures with spaces/Screenshots" "$log"
region_output="$temporary_root/region.png"
: > "$log"; run_helper region-file "$region_output" >/dev/null
grep -Fqx -- 'grim' "$log"; grep -Fqx -- '10,20 300x200' "$log"; [[ -s "$region_output" ]]
if run_helper region-file "$region_output" >/dev/null 2>&1; then printf 'region capture overwrote an existing file\n' >&2; exit 1; fi
: > "$log"; CAPTURE_TEST_SLURP_STATUS=130 run_helper region-file "$temporary_root/cancelled.png" >/dev/null
[[ ! -e "$temporary_root/cancelled.png" ]] || { printf 'cancelled region capture created a file\n' >&2; exit 1; }
printf 'workstation-capture tests passed\n'
