# Public Workstation identity

This directory owns the pre-login identity sources used by Plan 010. The
greeter is a project-owned Quickshell presentation/controller hosted by the
isolated Hyprland process launched from `greeter-host` through
`/usr/bin/start-hyprland`. The host passes its isolated Lua config after
`start-hyprland`'s `--` separator and owns the compositor lifetime. These
pre-login configs suppress only Hyprland's splash and unused guiutils check;
the greeter does not invoke Hyprland dialogs and does not add that package.
Hyprland selects a free Wayland server socket, so `greeter-host` records
pre-existing sockets and discovers the newly-created one before starting the
Quickshell client.

`public-theme.jq` projects the existing bundled theme manifest into the small
semantic palette contract consumed before login. It is deliberately a filter,
not a second palette source. `mark-dark.svg` and `mark-light.svg` are the
system-readable identity variants. The normal installer copies these files,
the isolated compositor configs, the greeter host/UI wrappers and the shared
`WorkstationShared` module to `/etc/blendos-workstation/identity`. The target is
under `/etc` because blendOS keeps `/usr` immutable at runtime; it is still
system-readable and is guarded by the greetd service condition.

The host may select the VirtualBox monitor profile and renderer workaround only
from its DMI check. Keep authentication/session ownership in greetd and the
greeter controller; do not add PAM, desktop user services, private theme
release reads, compositor `exec-once` paths or fallback login sessions here.

Operational commands and installed acceptance belong in the parent
[desktop guide](../README.md#graphical-login). The source contract and focused
fixtures are `scripts/validate-desktop-identity.sh` and
`scripts/test-desktop-identity.sh`.
