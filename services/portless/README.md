# Portless development routing

This document is the operator and maintenance guide for the repository's
Portless integration. General installation and repository verification remain
in the [root operator guide](../../README.md).

Portless assigns each development process a free loopback port and publishes it
at `http://<name>.localhost`. The systemd user service owns loopback port 80, so
projects and rootless containers never need privileged ports.

## Security and compatibility boundary

The managed proxy is HTTP-only and binds to loopback. Do not enable LAN mode
unless development applications are intentionally being exposed to the local
network.

Portless 0.15.6 assumes every port below 1024 requires `sudo`, even when Linux
is configured to allow the bind. The installer applies the repository's narrow
compatibility patch so Portless attempts the bind as the desktop user and lets
the kernel enforce `net.ipv4.ip_unprivileged_port_start=80`. The pinned version
makes an upstream change fail installation instead of silently patching the
wrong code.

## Native projects

Applications must listen on the injected `HOST` and `PORT` values. JavaScript
frameworks recognized by Portless are configured automatically.

```sh
# Spring Boot: set server.port=${PORT:8080} in application.properties
portless intranet ./mvnw spring-boot:run

# FastAPI
portless api sh -c 'exec uvicorn app:app --host "$HOST" --port "$PORT"'

# Django
portless admin sh -c 'exec python manage.py runserver "$HOST:$PORT"'

# Go: make the server read PORT, falling back to its normal development port
portless backend go run .
```

The commands above become `http://intranet.localhost`,
`http://api.localhost`, `http://admin.localhost`, and
`http://backend.localhost`.

## Rootless Podman Compose projects

The setup installs a `portless-compose` helper and globally ignores the
distinctive filenames `compose.portless.yaml` and `compose.portless.yml`. The
local override can therefore live beside the project's original Compose file
without appearing in `git status`.

Initialize a project by providing its Compose service name and fixed container
port:

```sh
portless-compose init app 3000
```

This copies the managed `compose.portless.yaml` template into the current
project and produces:

```yaml
services:
  app:
    ports: !override
      - "127.0.0.1:${PORT:?Run this project through portless-compose}:3000"
```

The `!override` tag replaces the original service's published ports instead of
appending another binding. Start the project with a hostname; `up` is the
default Compose command:

```sh
portless-compose intranet
```

Pass additional Compose arguments after the hostname when needed:

```sh
portless-compose intranet up --build
portless-compose intranet down
```

The helper discovers `compose.yaml`, `compose.yml`, `docker-compose.yaml`, or
`docker-compose.yml`, then explicitly merges it with `compose.portless.yaml`.
Set `PORTLESS_COMPOSE_FILE` when a directory contains multiple base files.

Compose must stay in the foreground because the Portless route exists for the
lifetime of the wrapped command. The helper rejects `-d` and `--detach` to
avoid starting an application whose hostname immediately disappears.

For an already-running service with a known published port, register a
persistent alias instead:

```sh
portless alias intranet 49152
portless alias --remove intranet
```

Inspect the proxy and current routes with:

```sh
systemctl --user status portless.service
portless list
portless doctor
```

## Maintenance

Portless is pinned in `.config/mise/config.toml`. When changing its version,
run both focused checks from the repository root before installing it on the
live account:

```sh
bash scripts/test-portless-patch.sh
bash scripts/test-portless-compose.sh
```

The compatibility patch deliberately fails when the expected upstream source
guard changes. Review the new upstream behavior before adapting or removing the
patch; do not broaden it until the low-port behavior is understood.
