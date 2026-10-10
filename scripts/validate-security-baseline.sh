#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
system_config="$repo_dir/system.yaml"
installer="$repo_dir/install.sh"
contract="$repo_dir/components.tsv"
portless_unit="$repo_dir/.config/systemd/user/portless.service"
check_installed=false
errors=0

if [[ "${1:-}" == '--installed' ]]; then
  check_installed=true
elif (($#)); then
  printf 'Usage: bash scripts/validate-security-baseline.sh [--installed]\n' >&2
  exit 2
fi

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  errors=$((errors + 1))
}

expect_line() {
  local file="$1"
  local expected="$2"
  grep -Fqx -- "$expected" "$file" || fail "$file is missing: $expected"
}

package_declared() {
  local package="$1"
  awk -v expected="  - '$package'" '
    /^(packages|aur-packages):$/ { in_packages = 1; next }
    in_packages && /^[^[:space:]#]/ { in_packages = 0 }
    in_packages && $0 == expected { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$system_config"
}

service_declared() {
  local unit="$1"
  awk -v expected="  - '$unit'" '
    /^services:$/ { in_services = 1; next }
    in_services && /^[^[:space:]#]/ { in_services = 0 }
    in_services && $0 == expected { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$system_config"
}

package_declared ufw || fail "system.yaml does not declare package 'ufw'"
for service in ufw tailscaled; do
  service_declared "$service" || fail "system.yaml does not declare service '$service'"
done

expect_line "$portless_unit" 'Environment=PORTLESS_PORT=80'
expect_line "$portless_unit" 'Environment=PORTLESS_TLD=localhost'
expect_line "$portless_unit" 'Environment=PORTLESS_SYNC_HOSTS=0'

for command in \
  "run_privileged ufw default deny incoming" \
  "run_privileged ufw default allow outgoing" \
  "run_privileged ufw default deny routed" \
  "run_privileged ufw allow in on tailscale0 comment 'Authenticated Tailscale peers'" \
  "run_privileged ufw --force enable"; do
  grep -Fq -- "$command" "$installer" || fail "installer is missing firewall command: $command"
done

for capability in host-firewall remote-overlay-network remote-desktop; do
  grep -Eq "^${capability}[[:space:]]" "$contract" || fail "component contract is missing '$capability'"
done

if [[ "$check_installed" == true ]]; then
  command -v ufw >/dev/null 2>&1 || fail 'ufw is not installed'
  systemctl is-enabled --quiet ufw || fail 'ufw is not enabled'
  systemctl is-active --quiet ufw || fail 'ufw is not active'

  if sudo -n true >/dev/null 2>&1; then
    firewall_status="$(sudo -n ufw status verbose 2>/dev/null || true)"
    grep -Fq 'Status: active' <<<"$firewall_status" || fail 'ufw does not report active status'
    grep -Eq 'Default:[[:space:]]+deny \(incoming\), allow \(outgoing\), deny \(routed\)' <<<"$firewall_status" ||
      fail 'ufw default policies do not match the managed baseline'
    grep -Eq 'Anywhere on tailscale0[[:space:]]+ALLOW IN' <<<"$firewall_status" ||
      fail 'ufw does not allow authenticated tailnet ingress on tailscale0'
  else
    printf 'NOTE: run `sudo ufw status verbose` to inspect live rules; passwordless sudo is unavailable.\n'
  fi

  printf 'Listening sockets (review unexpected non-loopback listeners):\n'
  ss -H -lntup 2>/dev/null || fail 'unable to inspect listening sockets with ss'

  root_source="$(findmnt -no SOURCE / 2>/dev/null || true)"
  if [[ "$root_source" == /dev/mapper/* ]] ||
    { [[ -n "$root_source" ]] && lsblk -sno TYPE "$root_source" 2>/dev/null | grep -Fxq crypt; }; then
    printf 'Root storage encryption detected.\n'
  else
    printf 'WARNING: root storage encryption was not detected for %s. Verify the bare-metal installation manually.\n' "${root_source:-unknown root source}" >&2
  fi
fi

if ((errors)); then
  printf '\nSecurity baseline failed with %d error(s).\n' "$errors" >&2
  exit 1
fi

printf 'Security baseline valid'
if [[ "$check_installed" == true ]]; then
  printf ' against the installed system'
fi
printf '.\n'
