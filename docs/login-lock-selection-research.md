# Login and lock decision record

Checked 2026-09-11 against the primary sources linked below. This record keeps
the decisions that are still relevant to the login and lock work; implementation
status belongs to [Plan 006](plans/006-quickshell-desktop-session.md) and
[Plan 010](plans/010-desktop-identity-and-login.md).

## Selected design

- Plan 006 keeps Hyprland and UWSM, with an independent Quickshell locker using
  `WlSessionLock` and native `PamContext`. The supported VM desktop and lock
  acceptance is complete; physical and remote limits remain open.
- Plan 010 will use `greetd` with an original Quickshell greeter in an isolated
  Hyprland host. `greetd` owns authentication and session creation; the greeter
  must hand off to the sole `workstation.desktop` UWSM session.
- The greeter and locker may share pure Qt Quick Controls presentation, palette,
  typography and public assets. Their authentication and lifecycle controllers
  stay separate. The login surface cannot read the private theme release or a
  Windows-backed home share.
- No SDDM, ReGreet, Noctalia Greeter, second locker, custom PAM engine or
  compositor-free Quickshell embedding is selected. Cage remains a possible
  future host only if a later implementation decision reopens that boundary.

Plan 010 is still TODO. It must prove login/logout, failed authentication,
keyring unlock, keyboard/focus/scaling behavior, public assets without private
home state, and the single display-manager/locker ownership boundary.

## Why this stack

| Candidate | Decision | Reason |
| --- | --- | --- |
| SDDM plus a Qt theme | Rejected | Adds a second login/display-server configuration and does not solve the locked Hyprland remote journey. |
| greetd plus ReGreet | Rejected | Reduces project UI code but constrains the deliberately custom presentation. |
| greetd plus Noctalia Greeter | Rejected | Bundles another compositor and native shell surface whose lifecycle and packaging would be separate from the selected stack. |
| greetd plus Quickshell | Selected | Reuses the declared Qt/Quickshell toolchain and permits a small shared presentation while keeping authentication ownership upstream. |
| Cage as the greeter host | Deferred | It is focused, but the current VirtualBox output override and existing Hyprland profile make a second host an additional integration surface. |

These are architectural judgments, not benchmark results. No candidate's login
latency, memory use or physical-device behavior was measured here.

## RustDesk boundary

The repository selects the pinned `rustdesk-unattended-wayland` Arch package
with the upstream DRM/KMS and display-wake features described in
[Plan 006](plans/006-quickshell-desktop-session.md#rustdesk-production-package)
and [its service guide](../services/rustdesk/README.md). A running root service
and a successful unlocked connection do not prove capture or input on a lock
surface or before login.

Required remote journeys are separate acceptance checks:

| Journey | Required evidence |
| --- | --- |
| Boot greeter | Fresh connection, visible greeter, remote keyboard input and login without a local approval prompt. |
| Existing lock | Fresh connection while already locked, visible lock surface and remote authentication input. |
| Lock transition | Disconnect/reconnect after locking, display-off wake and preserved compositor protection. |
| Failure handling | Capture/input failure remains explicit and never weakens lock or suspend protection. |

The installed VM currently has a known DRM capture failure: a fresh Windows
connection authenticates while locked but receives no image. Diagnosis and
remote tests are deferred by the owner until the remaining non-RustDesk
workstation plans are ready. This record does not treat the package or daemon
as accepted functionality.

## Appearance boundary

The session theme renderer writes private releases under
`${XDG_STATE_HOME:-$HOME/.local/state}/blendos-workstation/theme/`. Login runs
before that private state is available. Plan 010 therefore publishes only
approved public palette, font and static assets during normal system
provisioning. A private theme or wallpaper selection is not copied to the
greeter automatically, and no runtime privileged publisher is selected.

## Sources

- [greetd manual](https://man.archlinux.org/man/greetd.1.en)
- [Quickshell documentation](https://quickshell.org/docs/v0.3.0/types/)
- [RustDesk Linux guidance](https://rustdesk.com/docs/en/client/linux/)
- [RustDesk DRM capture change](https://github.com/rustdesk/rustdesk/pull/15420)
- [Hyprland lock-notify protocol](https://github.com/hyprwm/hyprland-protocols/blob/main/protocols/hyprland-lock-notify-v1.xml)
- [ReGreet host examples](https://github.com/rharish101/ReGreet/blob/0.5.0/README.md#usage)
