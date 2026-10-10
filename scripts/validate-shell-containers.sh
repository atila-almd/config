#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
system_config="$repo_dir/system.yaml"
zshenv="$repo_dir/.zshenv"
zprofile="$repo_dir/.zprofile"
zshrc="$repo_dir/.zshrc"
installer="$repo_dir/install.sh"
mise_config="$repo_dir/.config/mise/config.toml"
portless_unit="$repo_dir/.config/systemd/user/portless.service"
portless_docs="$repo_dir/services/portless/README.md"
portless_template="$repo_dir/services/portless/compose.portless.yaml"
portless_compose="$repo_dir/bin/portless-compose"
git_profile="$repo_dir/bin/git-profile"
git_config="$repo_dir/.gitconfig"
git_ignore="$repo_dir/.config/git/ignore"
repo_git_ignore="$repo_dir/.gitignore"
check_installed=false
errors=0

if [[ "${1:-}" == '--installed' ]]; then
  check_installed=true
elif (($#)); then
  printf 'Usage: bash scripts/validate-shell-containers.sh [--installed]\n' >&2
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
  grep -Eq "^[[:space:]]+- '$1'[[:space:]]*$" "$system_config"
}

for package in zsh mise starship zoxide podman podman-compose; do
  package_declared "$package" || fail "system.yaml does not declare package '$package'"
done

for unwanted in docker-compose podman-docker; do
  if package_declared "$unwanted"; then
    fail "system.yaml retains compatibility package '$unwanted'"
  fi
done

expect_line "$mise_config" '"npm:portless" = "0.15.6"'
grep -Eq '^node = "[0-9]+\.[0-9]+\.[0-9]+"$' "$mise_config" ||
  fail 'workstation Node must use an explicit reviewed version'
expect_line "$portless_unit" 'Environment=PORTLESS_PORT=80'
expect_line "$portless_unit" 'Environment=PORTLESS_ALLOW_UNPRIVILEGED_BIND=1'
expect_line "$portless_unit" 'ExecStart=/usr/bin/mise exec -- portless proxy start --foreground --no-tls'
grep -Fq 'net.ipv4.ip_unprivileged_port_start=80' "$system_config" ||
  fail 'system.yaml does not allow the Portless user service to bind port 80'
grep -Fq 'mise install' "$installer" ||
  fail 'installer does not install the configured Mise tools'
grep -Fq 'patch-portless-unprivileged-bind.sh' "$installer" ||
  fail 'installer does not apply the Portless low-port compatibility patch'
grep -Fq 'enable --now portless.service' "$installer" ||
  fail 'installer does not enable the Portless user service'
grep -Fq '127.0.0.1:${PORT:?Run this project through portless-compose}:3000' "$portless_docs" ||
  fail 'Portless documentation is missing the rootless Compose pattern'
expect_line "$git_ignore" 'compose.portless.yaml'
expect_line "$git_ignore" 'compose.portless.yml'
expect_line "$repo_git_ignore" '!services/portless/compose.portless.yaml'
grep -Fq 'excludesFile = ~/.config/git/ignore' "$git_config" ||
  fail '.gitconfig does not enable the managed global ignore file'
grep -Fq 'path = ~/.local/state/blendos-workstation/git/config' "$git_config" ||
  fail '.gitconfig does not include the local Git identity mappings'
if grep -Eq '^\[user\]|^\[includeIf ' "$git_config"; then
  fail '.gitconfig must not contain tracked identities or directory mappings'
fi
if find "$repo_dir/.config/git" -type f -name '*.gitconfig' -print -quit | grep -q .; then
  fail 'tracked identity-specific Git config remains under .config/git'
fi
grep -Fq 'bin/git-profile' "$installer" ||
  fail 'installer does not expose the Git identity helper'
[[ -f "$git_profile" ]] || fail 'Git identity helper is missing'
grep -Fq 'zsh_path="$(resolved_path "$zsh_command")"' "$installer" ||
  fail 'installer does not canonicalize Zsh before configuring the login shell'
grep -Fq 'grep -Fxq -- "$zsh_path" /etc/shells' "$installer" ||
  fail 'installer does not require canonical Zsh to be registered in /etc/shells'
grep -Fq "getent passwd 'gnome-initial-setup'" "$installer" ||
  fail 'installer does not detect the transient GNOME initial-setup account'
grep -Fq "run_privileged userdel -- 'gnome-initial-setup'" "$installer" ||
  fail 'installer does not remove the transient GNOME initial-setup account'
grep -Fq 'ports: !override' "$portless_template" ||
  fail 'Portless Compose template does not replace the original ports'
grep -Fq 'portless-compose init app 3000' "$portless_docs" ||
  fail 'Portless documentation does not explain project initialization'
grep -Fq 'bin/portless-compose' "$installer" ||
  fail 'installer does not expose the Portless Compose helper'
[[ -f "$portless_compose" ]] || fail 'Portless Compose helper is missing'

expect_line "$zshenv" 'export DOCKER_HOST="unix://${XDG_RUNTIME_DIR:-/run/user/$UID}/podman/podman.sock"'
expect_line "$zshenv" 'export PORTLESS_ALLOW_UNPRIVILEGED_BIND=1'
expect_line "$zprofile" '  eval "$(mise activate zsh --shims)"'
expect_line "$zshrc" '[[ -o interactive ]] || return'
expect_line "$zshrc" '  eval "$(mise activate zsh)"'
expect_line "$zshrc" '  eval "$(zoxide init zsh)"'
expect_line "$zshrc" '  eval "$(starship init zsh)"'

mise_line="$(grep -nF 'mise activate zsh)' "$zshrc" | cut -d: -f1)"
zoxide_line="$(grep -nF 'zoxide init zsh)' "$zshrc" | cut -d: -f1)"
starship_line="$(grep -nF 'starship init zsh)' "$zshrc" | cut -d: -f1)"
if [[ -z "$mise_line" || -z "$zoxide_line" || -z "$starship_line" ]] ||
   ((mise_line >= zoxide_line || zoxide_line >= starship_line)); then
  fail 'interactive initialization order must be Mise, Zoxide, then Starship'
fi

grep -Eq "^[[:space:]]+- 'podman.socket'[[:space:]]*$" "$system_config" ||
  fail 'system.yaml does not enable podman.socket as a user service'
grep -Fq "podman_socket='/usr/lib/systemd/user/podman.socket'" "$installer" ||
  fail 'installer does not use the Podman user socket unit'
grep -Fq 'sockets.target.wants/podman.socket' "$installer" ||
  fail 'installer does not enable Podman through sockets.target'
if grep -Fq '/usr/lib/systemd/user/podman.service' "$installer"; then
  fail 'installer still enables the Podman service directly'
fi

if [[ "$check_installed" == true ]]; then
  for executable in zsh mise starship zoxide portless portless-compose podman podman-compose; do
    command -v -- "$executable" >/dev/null 2>&1 || fail "executable is not installed: $executable"
  done

  login_user="$(id -un)"
  configured_shell="$(getent passwd "$login_user" | cut -d: -f7)"
  zsh_command="$(command -v zsh || true)"
  zsh_path="$(readlink -f -- "$zsh_command" 2>/dev/null || true)"
  if [[ -z "$zsh_path" || "$configured_shell" != "$zsh_path" ]]; then
    fail "$login_user login shell is '$configured_shell', expected '$zsh_path'"
  fi
  grep -Fxq -- "$zsh_path" /etc/shells ||
    fail "canonical Zsh login shell is not registered in /etc/shells: $zsh_path"

  shell_state="$(zsh -lic 'printf "%s|%s|%s\n" "${MISE_SHELL:-}" "${STARSHIP_SHELL:-}" "$(whence -w z 2>/dev/null)"' 2>/dev/null | tail -n 1)"
  [[ "$shell_state" == 'zsh|zsh|z: function' ]] ||
    fail "Zsh integrations did not initialize correctly: $shell_state"

  expected_host="unix://${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock"
  actual_host="$(zsh -lic 'printf "%s\n" "$DOCKER_HOST"' 2>/dev/null | tail -n 1)"
  [[ "$actual_host" == "$expected_host" ]] ||
    fail "DOCKER_HOST is '$actual_host', expected '$expected_host'"

  systemctl --user is-enabled --quiet podman.socket || fail 'podman.socket is not enabled'
  systemctl --user is-active --quiet podman.socket || fail 'podman.socket is not active'
  systemctl --user is-enabled --quiet portless.service || fail 'portless.service is not enabled'
  systemctl --user is-active --quiet portless.service || fail 'portless.service is not active'

  unprivileged_port_start="$(sysctl -n net.ipv4.ip_unprivileged_port_start 2>/dev/null || true)"
  [[ "$unprivileged_port_start" == '80' ]] ||
    fail "lowest unprivileged port is '${unprivileged_port_start:-unknown}', expected 80"

  rootless="$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null || true)"
  [[ "$rootless" == 'true' ]] || fail "Podman did not report rootless mode: ${rootless:-no result}"
fi

if ((errors)); then
  printf '\nShell/container contract failed with %d error(s).\n' "$errors" >&2
  exit 1
fi

printf 'Shell/container contract valid'
if [[ "$check_installed" == true ]]; then
  printf ' against the installed user account'
fi
printf '.\n'
