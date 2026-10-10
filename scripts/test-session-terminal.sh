#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

printf '%s\n' \
  '#!/usr/bin/env sh' \
  'printf "%s\n" "$TEST_VIRT"' \
  > "$test_dir/systemd-detect-virt"

printf '%s\n' \
  '#!/usr/bin/env sh' \
  'printf "software=%s args=%s\n" "${LIBGL_ALWAYS_SOFTWARE-unset}" "$*"' \
  > "$test_dir/ghostty"

chmod +x "$test_dir/systemd-detect-virt" "$test_dir/ghostty"

printf "vm\n" > "$test_dir/vm-profile"
printf "physical\n" > "$test_dir/physical-profile"
virtualbox_output="$({
  PATH="$test_dir:$PATH" BLENDOS_WORKSTATION_PROFILE_FILE="$test_dir/vm-profile" TEST_VIRT=oracle env -u LIBGL_ALWAYS_SOFTWARE \
    bash "$repo_dir/bin/session-terminal" --virtualbox
})"

bare_metal_output="$({
  PATH="$test_dir:$PATH" BLENDOS_WORKSTATION_PROFILE_FILE="$test_dir/physical-profile" TEST_VIRT=none env -u LIBGL_ALWAYS_SOFTWARE \
    bash "$repo_dir/bin/session-terminal" --bare-metal
})"

[[ "$virtualbox_output" == 'software=1 args=--virtualbox' ]]
[[ "$bare_metal_output" == 'software=unset args=--bare-metal' ]]

printf 'session-terminal tests passed.\n'
