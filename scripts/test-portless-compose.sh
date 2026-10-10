#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
helper="$repo_dir/bin/portless-compose"
temporary_root="$(mktemp -d)"
project="$temporary_root/project"
fake_bin="$temporary_root/bin"
capture="$temporary_root/arguments"

cleanup() {
  rm -rf -- "$temporary_root"
}
trap cleanup EXIT

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

mkdir -p -- "$project" "$fake_bin"

cat > "$project/compose.yaml" <<'EOF'
services:
  app:
    image: example/app
    ports:
      - "8080:8080"
EOF

cat > "$fake_bin/portless" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$PORTLESS_TEST_CAPTURE"
EOF

cat > "$fake_bin/podman" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod u+x -- "$fake_bin/portless" "$fake_bin/podman"

(
  cd -- "$project"
  "$helper" init app 8080 >/dev/null
)

override="$project/compose.portless.yaml"
[[ -f "$override" ]] || fail 'init did not create compose.portless.yaml'
grep -Fq '  app:' "$override" || fail 'init did not substitute the service name'
grep -Fq 'ports: !override' "$override" || fail 'init did not replace original ports'
grep -Fq ':8080"' "$override" || fail 'init did not substitute the container port'
if grep -Eq '__PORTLESS_(SERVICE|CONTAINER_PORT)__' "$override"; then
  fail 'init left template placeholders in the generated override'
fi

if (
  cd -- "$project"
  "$helper" init app 8080 >/dev/null 2>&1
); then
  fail 'init overwrote an existing local override'
fi

PORTLESS_TEST_CAPTURE="$capture" PATH="$fake_bin:$PATH" "$helper" --help >/dev/null
(
  cd -- "$project"
  export PATH="$fake_bin:$PATH"
  export PORTLESS_TEST_CAPTURE="$capture"
  "$helper" intranet up --build
)

mapfile -t arguments < "$capture"
[[ "${arguments[0]:-}" == 'intranet' ]] || fail 'hostname was not passed to Portless'
[[ "${arguments[1]:-}" == 'podman' ]] || fail 'Podman command was not wrapped'
[[ "${arguments[2]:-}" == 'compose' ]] || fail 'Compose command was not wrapped'
[[ "${arguments[3]:-}" == '-f' ]] || fail 'base Compose -f flag is missing'
[[ "${arguments[4]:-}" == "$project/compose.yaml" ]] || fail 'wrong base Compose path'
[[ "${arguments[5]:-}" == '-f' ]] || fail 'override Compose -f flag is missing'
[[ "${arguments[6]:-}" == "$override" ]] || fail 'wrong override Compose path'
[[ "${arguments[7]:-}" == 'up' && "${arguments[8]:-}" == '--build' ]] ||
  fail 'Compose arguments were not preserved'

if (
  cd -- "$project"
  PATH="$fake_bin:$PATH" PORTLESS_TEST_CAPTURE="$capture" "$helper" intranet up -d
) >/dev/null 2>&1; then
  fail 'detached Compose mode was not rejected'
fi

git -C "$project" init -q
ignored_by="$(
  cd -- "$project"
  git -c core.excludesFile="$repo_dir/.config/git/ignore" \
    check-ignore --no-index -- compose.portless.yaml || true
)"
[[ "$ignored_by" == 'compose.portless.yaml' ]] ||
  fail 'the global ignore does not hide compose.portless.yaml'

if git -c core.excludesFile="$repo_dir/.config/git/ignore" -C "$repo_dir" \
  check-ignore --no-index -- services/portless/compose.portless.yaml >/dev/null 2>&1; then
  fail 'the global ignore also hides the managed source template'
fi

printf 'portless-compose tests passed.\n'
