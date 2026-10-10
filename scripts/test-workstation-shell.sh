#!/usr/bin/env bash
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
runner="${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner}"
[[ -x "$runner" ]] || { printf 'Qt Quick Test unavailable: %s\n' "$runner" >&2; exit 1; }
export QT_QUICK_CONTROLS_STYLE=Basic QT_QUICK_BACKEND=software
runtime="$(mktemp -d)"
trap 'rm -rf -- "$runtime"' EXIT
mkdir "$runtime/commands"
printf "vm\n" > "$runtime/oracle-profile"
printf "physical\n" > "$runtime/none-profile"
cat > "$runtime/commands/systemd-detect-virt" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$TEST_VIRT"
EOF
cat > "$runtime/commands/systemctl" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == '--user is-active --quiet workstation-shell.service' ]]; then
  [[ "${TEST_ACTIVE:-0}" == 1 ]]
else
  printf '%s\n' "$*" > "$TEST_RESULT"
fi
EOF
cat > "$runtime/commands/qs" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == '-c workstation ipc call -- island toggle' && -n "${TEST_IPC_FAILURES:-}" ]]; then
  attempts=0
  [[ ! -f "$TEST_RESULT.attempts" ]] || read -r attempts < "$TEST_RESULT.attempts"
  printf '%s\n' "$((attempts + 1))" > "$TEST_RESULT.attempts"
  ((attempts >= TEST_IPC_FAILURES)) || exit 1
fi
printf '%s|%s|%s|%s\n' "${QT_QUICK_BACKEND-unset}" "${LIBGL_ALWAYS_SOFTWARE-unset}" "${GALLIUM_DRIVER-unset}" "$*" > "$TEST_RESULT"
EOF
cat > "$runtime/commands/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$runtime/commands/"*
export TEST_RESULT="$runtime/result"
for virt in oracle none; do
  env -u QT_QUICK_BACKEND -u LIBGL_ALWAYS_SOFTWARE -u GALLIUM_DRIVER \
    PATH="$runtime/commands:$PATH" BLENDOS_WORKSTATION_PROFILE_FILE="$runtime/$virt-profile" \
    bash "$repo_dir/bin/session-workstation-shell" --run
  if [[ "$virt" == oracle ]]; then
    grep -Fxq 'software|true|llvmpipe|-c workstation' "$TEST_RESULT"
  else
    grep -Fxq 'unset|unset|unset|-c workstation' "$TEST_RESULT"
  fi
done
for virt in oracle none; do
  env -u QT_QUICK_BACKEND -u LIBGL_ALWAYS_SOFTWARE -u GALLIUM_DRIVER \
    PATH="$runtime/commands:$PATH" BLENDOS_WORKSTATION_PROFILE_FILE="$runtime/$virt-profile" \
    bash "$repo_dir/bin/session-workstation-lock" --run
  if [[ "$virt" == oracle ]]; then
    grep -Fxq 'software|true|llvmpipe|-c workstation-lock' "$TEST_RESULT"
  else
    grep -Fxq 'unset|unset|unset|-c workstation-lock' "$TEST_RESULT"
  fi
done
PATH="$runtime/commands:$PATH" TEST_ACTIVE=0 bash "$repo_dir/bin/session-workstation-shell"
grep -Fq -- '|-c workstation ipc call -- island toggle' "$TEST_RESULT"
PATH="$runtime/commands:$PATH" TEST_ACTIVE=1 bash "$repo_dir/bin/session-workstation-shell" --controls
grep -Fq -- '|-c workstation ipc call -- controls show' "$TEST_RESULT"
PATH="$runtime/commands:$PATH" TEST_ACTIVE=1 bash "$repo_dir/bin/session-workstation-shell" --controls power
grep -Fq -- '|-c workstation ipc call -- controls section power' "$TEST_RESULT"
PATH="$runtime/commands:$PATH" TEST_ACTIVE=1 bash "$repo_dir/bin/session-workstation-shell" --launcher
grep -Fq -- '|-c workstation ipc call -- island launcher' "$TEST_RESULT"
if PATH="$runtime/commands:$PATH" bash "$repo_dir/bin/session-workstation-shell" --controls invalid 2>/dev/null; then
  printf 'Invalid control section accepted.\n' >&2; exit 1
fi
PATH="$runtime/commands:$PATH" TEST_ACTIVE=1 bash "$repo_dir/bin/session-workstation-shell"
grep -Fq -- '|-c workstation ipc call -- island toggle' "$TEST_RESULT"
PATH="$runtime/commands:$PATH" TEST_ACTIVE=0 TEST_IPC_FAILURES=2 bash "$repo_dir/bin/session-workstation-shell"
[[ "$(cat "$TEST_RESULT.attempts")" == 3 ]]
rm -- "$TEST_RESULT.attempts"
if PATH="$runtime/commands:$PATH" TEST_ACTIVE=1 TEST_IPC_FAILURES=100 bash "$repo_dir/bin/session-workstation-shell" 2> "$runtime/unavailable.log"; then
  printf 'An unavailable IPC endpoint was accepted.\n' >&2; exit 1
fi
[[ "$(cat "$TEST_RESULT.attempts")" == 50 ]]
PATH="$runtime/commands:$PATH" TEST_VIRT=none XDG_RUNTIME_DIR="$runtime" \
  bash "$repo_dir/bin/session-workstation-shell" --preview
grep -Fq -- "|-p $runtime/workstation-preview." "$TEST_RESULT"
[[ -z "$(find "$runtime" -maxdepth 1 -type d -name 'workstation-preview.*' -print -quit)" ]]
PATH="$runtime/commands:$PATH" TEST_VIRT=none XDG_RUNTIME_DIR="$runtime" \
  bash "$repo_dir/bin/session-workstation-shell" --preview-controls
grep -Fq -- "|-p $runtime/workstation-preview." "$TEST_RESULT"
[[ -z "$(find "$runtime" -maxdepth 1 -type d -name 'workstation-preview.*' -print -quit)" ]]
export XDG_RUNTIME_DIR="$runtime"
"$runner" -platform offscreen -import "$repo_dir/.config/quickshell" -input "$repo_dir/scripts/fixtures/workstation-shell" "$@"
