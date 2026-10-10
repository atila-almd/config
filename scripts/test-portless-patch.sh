#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

fixture="$test_dir/cli.js"
original='if (!isWindows && proxyPort < PRIVILEGED_PORT_THRESHOLD && (process.getuid?.() ?? -1) !== 0) {'
patched='if (!process.env.PORTLESS_ALLOW_UNPRIVILEGED_BIND && !isWindows && proxyPort < PRIVILEGED_PORT_THRESHOLD && (process.getuid?.() ?? -1) !== 0) {'

printf '%s\n' '#!/usr/bin/env node' "$original" '  startProxy();' '}' > "$fixture"

bash "$repo_dir/scripts/patch-portless-unprivileged-bind.sh" "$fixture" >/dev/null
grep -Fqx -- "$patched" "$fixture"

# Applying the patch again must be harmless.
bash "$repo_dir/scripts/patch-portless-unprivileged-bind.sh" "$fixture" >/dev/null
[[ "$(grep -Fc -- 'PORTLESS_ALLOW_UNPRIVILEGED_BIND' "$fixture")" == '1' ]]

# Mise may expose an npm launcher whose actual CLI lives in a sibling bundle.
# The patch must follow that package layout without weakening its guard check.
package_root="$test_dir/portless-package"
wrapper="$package_root/bin/portless"
bundle="$package_root/dist/cli.js"
mkdir -p -- "$(dirname -- "$wrapper")" "$(dirname -- "$bundle")"
printf '%s\n' '{"name":"portless","bin":{"portless":"./dist/cli.js"}}' > "$package_root/package.json"
printf '%s\n' '#!/usr/bin/env node' 'import "../dist/cli.js"' > "$wrapper"
printf '%s\n' "$original" > "$bundle"
chmod u+x -- "$wrapper"

bash "$repo_dir/scripts/patch-portless-unprivileged-bind.sh" "$wrapper" >/dev/null
grep -Fqx -- "$patched" "$bundle"

# Mise's npm backend may expose the launcher from an install root while the
# package itself lives under node_modules/portless.
install_root="$test_dir/portless-install"
nested_wrapper="$install_root/bin/portless"
nested_bundle="$install_root/node_modules/portless/dist/cli.js"
mkdir -p -- "$(dirname -- "$nested_wrapper")" "$(dirname -- "$nested_bundle")"
printf '%s\n' '{"name":"portless","bin":{"portless":"./dist/cli.js"}}' > "$install_root/node_modules/portless/package.json"
printf '%s\n' '#!/usr/bin/env node' 'import "../node_modules/portless/dist/cli.js"' > "$nested_wrapper"
printf '%s\n' "$original" > "$nested_bundle"
chmod u+x -- "$nested_wrapper"

bash "$repo_dir/scripts/patch-portless-unprivileged-bind.sh" "$nested_wrapper" >/dev/null
grep -Fqx -- "$patched" "$nested_bundle"

changed_fixture="$test_dir/changed-cli.js"
printf '%s\n' 'if (!isWindows && proxyPort < PRIVILEGED_PORT_THRESHOLD && process.getuid?.() !== 0) {' > "$changed_fixture"
if output="$(bash "$repo_dir/scripts/patch-portless-unprivileged-bind.sh" "$changed_fixture" 2>&1)"; then
  printf 'patch accepted an unknown Portless guard\n' >&2
  exit 1
fi
grep -Fqx -- 'Portless elevation guard changed; review the compatibility patch before continuing.' <<<"$output"

printf 'Portless compatibility patch tests passed.\n'
