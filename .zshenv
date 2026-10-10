# User executables are available to login, interactive, and script shells.
typeset -U path PATH
path=("$HOME/.local/bin" "$HOME/.local/bin/blend_bin" $path)
export PATH

# Docker-API clients talk to this user's rootless Podman socket.
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR:-/run/user/$UID}/podman/podman.sock"

# Portless is an HTTP-only, loopback development proxy managed by systemd.
export PORTLESS_HTTPS=0
export PORTLESS_PORT=80
export PORTLESS_TLD=localhost
export PORTLESS_SYNC_HOSTS=0
export PORTLESS_ALLOW_UNPRIVILEGED_BIND=1
