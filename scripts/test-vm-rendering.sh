#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

fake_bin="$test_dir/bin"
state_home="$test_dir/state"
release="$state_home/blendos-workstation/theme/releases/release-test"
mkdir -p -- "$fake_bin" "$release"
ln -s -- "$release" "$state_home/blendos-workstation/theme/current"


cat > "$fake_bin/systemd-detect-virt" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$TEST_VIRT"
EOF

cat > "$fake_bin/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF

cat > "$fake_bin/qs" <<'EOF'
#!/usr/bin/env bash
printf 'software=%s driver=%s args=%s\n' \
  "${LIBGL_ALWAYS_SOFTWARE-unset}" \
  "${GALLIUM_DRIVER-unset}" \
  "$*"
EOF

cat > "$fake_bin/walker" <<'EOF'
#!/usr/bin/env bash
printf 'renderer=%s args=%s\n' "${GSK_RENDERER-unset}" "$*"
EOF

chmod u+x -- "$fake_bin"/*

run_lock() (
  export TEST_VIRT="$1"
  export BLENDOS_WORKSTATION_PROFILE_FILE="$test_dir/$1-profile"
  export HOME="$test_dir/home"
  export BLENDOS_WORKSTATION_THEME_STATE_HOME="$state_home"
  export PATH="$fake_bin:/usr/bin:/bin"
  env -u LIBGL_ALWAYS_SOFTWARE -u GALLIUM_DRIVER \
    bash "$repo_dir/bin/session-workstation-lock" --run
)

run_walker() (
  export TEST_VIRT="$1"
  export BLENDOS_WORKSTATION_PROFILE_FILE="$test_dir/$1-profile"
  export PATH="$fake_bin:/usr/bin:/bin"
  env -u GSK_RENDERER bash "$repo_dir/bin/session-walker" --gapplication-service
)

printf "vm\n" > "$test_dir/oracle-profile"
printf "physical\n" > "$test_dir/none-profile"
virtualbox_lock="$(run_lock oracle)"
bare_metal_lock="$(run_lock none)"
[[ "$virtualbox_lock" == "software=true driver=llvmpipe args=-c workstation-lock" ]] || {
  printf 'VirtualBox Quickshell locker fallback is missing: %s\n' "$virtualbox_lock" >&2
  exit 1
}
[[ "$bare_metal_lock" == "software=unset driver=unset args=-c workstation-lock" ]] || {
  printf 'bare-metal Quickshell locker environment was changed: %s\n' "$bare_metal_lock" >&2
  exit 1
}

virtualbox_walker="$(run_walker oracle)"
bare_metal_walker="$(run_walker none)"
[[ "$virtualbox_walker" == 'renderer=cairo args=--gapplication-service' ]] || {
  printf 'VirtualBox Walker fallback is missing: %s\n' "$virtualbox_walker" >&2
  exit 1
}
[[ "$bare_metal_walker" == 'renderer=unset args=--gapplication-service' ]] || {
  printf 'bare-metal Walker environment was changed: %s\n' "$bare_metal_walker" >&2
  exit 1
}

printf 'VirtualBox rendering fallback tests passed.\n'
