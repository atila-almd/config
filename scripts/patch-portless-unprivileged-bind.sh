#!/usr/bin/env bash

set -Eeuo pipefail

portless_executable="${1:-}"
if [[ -z "$portless_executable" ]]; then
  command -v mise >/dev/null 2>&1 || {
    printf 'Mise is required to locate Portless.\n' >&2
    exit 1
  }
  portless_executable="$(mise which portless)"
fi

resolved_portless_executable="$(readlink -f -- "$portless_executable" 2>/dev/null || true)"
[[ -f "$resolved_portless_executable" ]] || {
  printf 'Portless CLI not found: %s\n' "$resolved_portless_executable" >&2
  exit 1
}

original='if (!isWindows && proxyPort < PRIVILEGED_PORT_THRESHOLD && (process.getuid?.() ?? -1) !== 0) {'
patched='if (!process.env.PORTLESS_ALLOW_UNPRIVILEGED_BIND && !isWindows && proxyPort < PRIVILEGED_PORT_THRESHOLD && (process.getuid?.() ?? -1) !== 0) {'

portless_candidates=()
add_candidate() {
  local candidate="$1"
  local existing
  [[ -f "$candidate" ]] || return 0
  for existing in "${portless_candidates[@]}"; do
    [[ "$existing" == "$candidate" ]] && return 0
  done
  portless_candidates+=("$candidate")
}

add_package_cli_root() {
  local package_root="$1"
  local package_manifest="$package_root/package.json"
  local package_name package_bin package_cli
  [[ -f "$package_manifest" ]] || return 0
  package_name="$(jq -er '.name // empty' -- "$package_manifest" 2>/dev/null || true)"
  [[ "$package_name" == 'portless' ]] || return 0
  package_bin="$(jq -er '
    if (.bin | type) == "object" then .bin.portless // empty
    elif (.bin | type) == "string" then .bin
    else empty
    end
  ' -- "$package_manifest" 2>/dev/null || true)"
  [[ -n "$package_bin" && "$package_bin" != /* ]] || return 0
  package_cli="$(readlink -f -- "$package_root/$package_bin" 2>/dev/null || true)"
  add_candidate "$package_cli"
}

add_package_cli() {
  local install_root="$1"
  add_package_cli_root "$install_root"
  add_package_cli_root "$install_root/node_modules/portless"
  add_package_cli_root "$install_root/lib/node_modules/portless"
}

add_candidate "$resolved_portless_executable"
package_root="$(readlink -f -- "$(dirname -- "$resolved_portless_executable")/.." 2>/dev/null || true)"
[[ -n "$package_root" ]] && add_package_cli "$package_root"

if command -v mise >/dev/null 2>&1; then
  mise_package_root="$(mise where npm:portless 2>/dev/null || true)"
  [[ -n "$mise_package_root" ]] && add_package_cli "$mise_package_root"
fi

portless_cli=''
for candidate in "${portless_candidates[@]}"; do
  if grep -Fq -- "$patched" "$candidate" || grep -Fq -- "$original" "$candidate"; then
    portless_cli="$candidate"
    break
  fi
done
[[ -n "$portless_cli" ]] || {
  printf 'Portless elevation guard changed; review the compatibility patch before continuing.\n' >&2
  exit 1
}

if grep -Fq -- "$patched" "$portless_cli"; then
  printf 'Portless unprivileged-bind patch already applied.\n'
elif grep -Fq -- "$original" "$portless_cli"; then
  patched_cli="$(mktemp "${portless_cli}.XXXXXX")"
  awk -v original="$original" -v patched="$patched" '
    {
      position = index($0, original)
      if (position) {
        $0 = substr($0, 1, position - 1) patched substr($0, position + length(original))
      }
      print
    }
  ' "$portless_cli" > "$patched_cli"
  chmod --reference="$portless_cli" "$patched_cli"
  if ! grep -Fq -- "$patched" "$patched_cli" || grep -Fq -- "$original" "$patched_cli"; then
    rm -f -- "$patched_cli"
    printf 'Portless compatibility patch did not produce the expected guard.\n' >&2
    exit 1
  fi
  mv -- "$patched_cli" "$portless_cli"
  printf 'Patched Portless to let the kernel authorize port 80.\n'
else
  printf 'Portless elevation guard changed; review the compatibility patch before continuing.\n' >&2
  exit 1
fi
