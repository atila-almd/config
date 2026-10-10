# Workstation desktop

Plan 006 delivers one Quickshell desktop session, the Island shell and an
independent locker. Island owns the persistent per-output bar, activity state,
cards and dashboard; the locker remains independent.
[CHECKLIST.md](CHECKLIST.md) tracks evidence; [STATE.md](../../STATE.md) records
progress. [AGENTS.md](../../AGENTS.md) owns architecture boundaries,
[components.tsv](../../components.tsv) owns wiring and [API.md](API.md) owns
frontend contracts.

## Installation and lifecycle

Use the root [installation procedure](../../README.md) to rebuild blendOS,
reboot and deploy home configuration from an inactive graphical session.
The sole managed identity is `workstation.desktop`, retaining inner
`Exec=Hyprland` for UWSM's compositor plugin. This targets fresh provisioning;
no shell selector, old-shell session or old-install conversion is supplied.

`blendos-workstation-session.target` starts the shell, data and launcher
adapters, lock guard, Hypridle, Walker/Elephant, Dunst, Awww/wallpaper
restoration, clipboard services and policy agent. The independent locker starts
on request.

```sh
systemctl --user status blendos-workstation-session.target
systemctl --user list-dependencies blendos-workstation-session.target
journalctl --user -b -u workstation-shell.service -u workstation-lock.service \
  -u workstation-lock-guard.service -u hypridle.service --no-pager
```

## Graphical login

`greetd.service` is the sole display-manager owner. It runs the dedicated
`greeter` account through `/etc/blendos-workstation/identity/greeter-host`.
That host starts a separate Hyprland process through `/usr/bin/start-hyprland`,
passing its own minimal config after the watchdog separator, and then starts
the original Quickshell greeter after discovering the newly-created Wayland
socket. The greeter speaks the native greetd
conversation, hands the authenticated account to
`uwsm start -e -D Hyprland -- workstation.desktop`, and exits with its
compositor after handoff. Logout returns to greetd; no second desktop session
or old Ly route exists.

The identity bundle is system-readable and includes the shared auth
presentation, public semantic palette projection, mark variants and isolated
compositor configs. It never reads the owner's home, private theme release or
Windows share. `system.yaml` installs the greetd config, GNOME Keyring PAM
hooks and an asset-existence condition; the normal full `install.sh` run
publishes the bundle before enabling/restarting greetd. A fresh rebuild can
therefore be recovered from another TTY until that provisioning step is done;
there is no fallback greeter.

The host selects `hyprland-vm.lua` only when the explicit Machine Profile marker is `vm`, and
applies software rendering only to that pre-login process. Physical displays
use the preferred-mode config and receive no renderer override. Inspect the
source contract with:

```sh
bash scripts/validate-desktop-identity.sh
bash scripts/test-desktop-identity.sh
bash scripts/check-workstation-greeter-views.sh "$HOME/.cache/workstation-greeter-render"
```

After a rebuild and full installation, run
`bash scripts/validate-desktop-identity.sh --installed` and exercise successful
and failed login, retry/cancel, logout/relogin, TTY recovery, keyring unlock,
portal file selection and screen sharing. Repository and offscreen checks do
not establish those guest or visual results.

## Island shell

Island is the single Quickshell surface for the bar, activity island, cards,
dashboard, projects, timer, recorder and power actions. It follows every native
output and shares one state machine across them; an expanded card is the island
growing in place, not a second popup. The native tray remains owned by
`Desktop.qml`, and stale tray identity/revision tuples are still rejected.

The operator guide for the shell's states, live configuration, commands,
available sources and intentionally skipped widgets is [ISLAND.md](ISLAND.md).
The structured backend and lifecycle contracts remain in [API.md](API.md).

The existing Dunst, Walker and capture helpers remain their own session-owned
services. Island opens its Quickshell launcher over the Elephant index for
applications, files, calculations and web search. Walker remains the selected
presentation for clipboard, symbols, windows, utility menus/capture and
shortcut selection; it does not duplicate the Island application surface.
Optional Wi-Fi/Bluetooth hardware remains disabled.

## Plan 009 notification boundary

Option 1 keeps Dunst as the sole notification owner. The existing
workstation-data service exposes a bounded `notifications` snapshot by reading
Dunst over the session bus only while the Island history card is open; it does
not create a second daemon, persistence store, socket or QML D-Bus owner.
Volume and microphone feedback reuse Island's existing attention surface and
single deadline owner rather than adding an OSD package or widget timer.

The card's Pause/Resume, Clear history, Show and Dismiss actions use the
validated `workstation-controls` boundary. Dunst retains live popup actions
and persistence; closed history rows expose no action labels because Dunst
invalidates them on close. The source contract, limits, audit and remaining
guest checks are recorded in [Plan 009](../../docs/plans/009-notifications-and-osd.md),
[API.md](API.md#plan-009-option-1-notification-contract), and
[UPSTREAM.md](UPSTREAM.md#plan-009-option-1-dunst-audit).

## Lock and sleep

`session-lock` starts `workstation-lock.service`. Its independent Quickshell
configuration acquires a Wayland session lock on every output before accepting
PAM responses through `/etc/pam.d/workstation-lock`. The shared authentication
view does not verify passwords or create login sessions. Responses clear on
submit, prompt changes, cancellation and result. Cancel leaves the session
locked. Invalid themes use a neutral emergency palette.

Authoritative layout/Caps Lock state comes from Hyprland's JSON device snapshot
on start/focus, layout/config events and modifier key release. Failed reads
show keyboard state as unavailable. Locale is not treated as keyboard state;
typed text never leaves the authentication response path.

Hypridle retains ten-minute lock and eleven-minute screen-off behavior, restores
screen power on activity and uses explicit inhibition mode 3. No automatic
suspend timeout is added. `workstation-suspend` requests lock and waits up to
thirty seconds for compositor confirmation before requesting logind suspend.
The independent guard
holds a block inhibitor while unlocked or acknowledgement is unknown, refusing
external unprivileged sleep requests after a failed locker start.

After PAM success, the locker waits for the guard's `prepare-unlock` command to
reacquire/store that block inhibitor before releasing compositor protection.
Failure keeps the workstation locked. A PID or locker status response is never
proof of secure coverage. Privileged inhibitor overrides are outside this
unprivileged desktop contract.

Compositor acknowledgement proves protection, which may be a compositor crash
surface rather than a rendered password form. Usable authentication pixels
require separate visual acceptance. Denied/unacknowledged acquisition exits
with failure. Abandoned locker recovery is not transparent: the compositor's
default refusal to restore an abandoned lock is retained.

```sh
session-lock
qs -c workstation-lock ipc call -- lock status
workstation-suspend
```

There is no unlock IPC. Locker death leaves a protected compositor crash surface.
Do not clear it as routine recovery. Authenticate locally on another TTY,
inspect locker/guard journals and end the affected graphical login to recover
through normal authentication. Do not restart the desktop target for theme reload.

The guard requires systemd 254 or newer for its descriptor-store environment,
preservation policy and direct restart mode. It stores the block inhibitor in
systemd's descriptor store and verifies the notification barrier and store count
before treating it as retained. Its automatic restart policy,
`FileDescriptorStorePreserve=restart` and `RestartMode=direct` preserve the
block across a guard crash without propagating a transient dependency failure;
normal session stop releases the stored descriptor. Do not stop or disable the
guard independently in an active desktop session. If a crash leaves an
inherited block while the compositor is initially locked, authenticate and
unlock once, then lock again to restore normal locked-session suspend behavior.

Unprivileged external logind suspend requests while unlocked are refused before
`PrepareForSleep`; use `workstation-suspend`, or lock first and then request
suspend. After PAM success, `prepare-unlock` reacquires and stores the inhibitor
and synchronously checks logind's `PreparingForSleep`; managed sleep remains
latched until `PrepareForSleep(false)` after resume or cancellation. The native
guard endpoint is `org.blendos.WorkstationLockGuard` at
`/org/blendos/WorkstationLockGuard`, with `Suspend` and `PrepareUnlock` methods.
It neither authenticates users nor unlocks the compositor, and passwords never
pass through it.

For lock-guard source checks, run:

```sh
cd services/desktop/data
go test -mod=readonly -race ./internal/lockguard ./cmd/workstation-lock-guard
go vet -mod=readonly ./internal/lockguard ./cmd/workstation-lock-guard
```

These tests cover lock transitions, malformed or missing native protocol events,
descriptor passing and barrier acknowledgement, pending-sleep races,
external-sleep state queries and failure refusal. Installed acceptance still
requires PAM success/failure, multiple outputs, shell and guard crashes,
external and managed suspend, delay-inhibitor timeout, resume, display wake and
normal session teardown; WSL source checks cannot establish those graphical or
systemd lifecycle results. Protocol references include [Hyprland lock
notifications](https://github.com/hyprwm/hyprland-protocols/blob/main/protocols/hyprland-lock-notify-v1.xml),
[systemd descriptor notifications](https://man.archlinux.org/man/sd_notify.3.en),
[systemd descriptor-store lifecycle](https://man.archlinux.org/man/systemd.service.5.en)
and [logind sleep scheduling](https://github.com/systemd/systemd/blob/main/src/login/logind-dbus.c).

## Appearance and VirtualBox

The atomic theme release supplies `workstation-shell.json` to Island's bar,
cards and dashboard, plus the independent locker. Activation reloads active
consumers through native IPC; Awww remains
the wallpaper owner. Geometry and behavior stay in managed QML. See the root
[theme guide](../../README.md#themes-and-wallpapers).

`session-workstation-shell` and `session-workstation-lock` select llvmpipe and
Qt's software backend only with the explicitly selected `vm` profile. Ghostty and Walker retain their own
scoped adapters; `workstation-controls audio-mixer` selects GTK's Cairo renderer for
the mixer with the selected `vm` profile and preserves an explicit `GSK_RENDERER`. Never export
these overrides session-wide or apply them to
physical NVIDIA hardware. VM 1920×1080 scale 1 does not replace physical
preferred-mode/automatic-scale policy.

## Verification

Run `bash scripts/check-repository.sh` in Linux/WSL. Inside the rebuilt blendOS
graphical account:

```sh
bash scripts/validate-user-session.sh --installed
bash scripts/validate-component-contract.sh --installed
bash scripts/check-workstation-shell.sh --lint
bash scripts/check-workstation-shell.sh --live
bash scripts/check-workstation-shell.sh --render "$HOME/.cache/workstation-render-check"
```

Optional native source-loader and offscreen-view checks are documented in
[API.md](API.md#checks). Their private test compositor is not part of the desktop.

The live fixture isolates project state and disables bar/tray ownership.
Inspect render PNGs and focus/scaling. Exercise login/logout, native tray,
manual/idle lock, screen-off/wake, failed/slow lock, bar/locker/guard failure and
suspend/resume with a locally accessible test login. Process success is not
visual acceptance.

The selected RustDesk DRM/KMS package's deferred acceptance requires a fresh authenticated
connection while already locked, remote input/unlock, reconnection, screen-off
wake and capture/input failure checks. An existing connection surviving lock
is insufficient. The [plan execution contract](../../docs/plans/README.md#owner-directed-rustdesk-sequencing-2026-09-12)
owns when this deferred work resumes. Package pins/build integration belong to
its service and Plan 006; credentials remain Local State.
