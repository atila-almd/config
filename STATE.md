# Workstation implementation state

## Release reconciliation (2026-10-10)

The sanitized `main` contains the current working implementation, including all
37 managed dirty/untracked changes retained in its fresh root. The
[working-change audit](docs/audits/working-change-retention.md) records each
path; the original checkout and its uncommitted work remain intact. VM files
moved to the explicit `vm` profile and Local State stays outside source.

The release source checks passed all 40 repository scripts in WSL and again
from a clean Linux clone. The prior notification-test blocker below was an
invalid NUL-containing D-Bus mock reply; the fixture now uses wire-valid input
and tests NUL/invalid UTF-8 at the sanitizer seam. This later source evidence
supersedes the older source-suite failure and untested-source statements below,
while preserving every installed/visual/hardware acceptance limit.

The working-change audit also found a stale locker identity-mark default under
immutable `/usr/share`; it now consumes the same `/etc` identity bundle as the
greeter/installer, and identity validation includes the locker. Installed
branding inspection remains pending. The existing native RustDesk artifact on
the preparation machine was rechecked against its accepted SHA-256; deployment
requires copying/publishing it into the target account. The current remote
remains private, with old history retained on `quickshell-shell` and in an
external verified bundle.

[BACKLOG.md](BACKLOG.md#current-pending-work-2026-10-10) owns the current ordered
acceptance/setup/recovery list. No current physical installation, native current
Island/greeter render or installed completion is claimed by these source checks.

## Plan 010 source checkpoint (2026-09-13)

The source now replaces Ly with greetd as the sole graphical-login owner. Its
dedicated `greeter` account launches an isolated Hyprland host and the native
Quickshell Greetd controller; successful authentication hands off through the
sole UWSM `workstation.desktop` entry. The shared `AuthForm` presentation is
used by both the greeter and independent locker. Public marks and a semantic
palette projection are installed under `/etc/blendos-workstation/identity`
by normal system provisioning, while the private theme release remains
private. The first guest install trace exposed that `/usr/share` is immutable;
the bundle target is now explicitly kept under mutable `/etc` and guarded by
the source validator.

Focused source evidence from this Windows/WSL takeover:

- `validate-desktop-identity.sh`, `validate-component-contract.sh`,
  `validate-user-session.sh` and `check-workstation-shell.sh --source` pass;
- `test-desktop-identity.sh` passes 11 Qt cases plus disposable system-only
  identity publication/idempotence checks; `test-component-contract.sh` and
  `test-vm-rendering.sh` pass;
- shared/greeter view `qmllint` passes with the available Qt 6.2.4 toolchain;
  native Quickshell lint and inspected greeter PNGs require the blendOS
  Quickshell package and are not claimed here.

At the Plan 010 checkpoint, the complete repository suite was not yet green.
The later release reconciliation above records the resolved source blocker.
With temporary Go
1.27.1 and resvg 0.48.1 toolchains, all checks through
`test-workstation-controls.sh` pass; `test-workstation-data.sh` then stops at
the existing D-Bus mock because its `NotificationListHistory` reply contains
a NUL character and the client reports `backend_unavailable`. No Plan 010
data files changed. No rebuilt blendOS guest is attached, so installed
greetd/PAM/keyring, successful and failed login, logout/relogin, portal, TTY,
lock/login pixel and physical acceptance remain open. Plan 010 is therefore
source-implemented, not complete.

## Plan 007 implementation checkpoint (2026-09-12)

The current branch delivers the lazy control center, native audio/media/output
observations, shared desktop topics, typed commands, private control-center layout
settings and exact theme-release acknowledgement with rollback. The selected
three MIT label functions and their update boundary are in
[UPSTREAM.md](services/desktop/UPSTREAM.md). Plan 007 remains **IN PROGRESS**:
the owner [stopped further verification and authorized this checkpoint](docs/plans/README.md#owner-directed-plan-007-verification-stop-2026-09-12).

Evidence is outside the repository under
`%LOCALAPPDATA%\blendos-workstation\validation\plan007\`.
`repository-checks.log`, `backend-evidence.md` and `final-source-receipt.json`
record the completed 35-check suite, including 27 existing Qt cases and 17 control
cases. Pure Qt 6.2.4 fixtures emitted the documented QQmlContext warnings;
native warning-free lint and smoke checks also passed. The full-suite manifest
is `d8cb8ec8d286ad272ab1510441a45dcdd134f93a0e7d9c2e2a416da3cb349978`.

That full run predates the two guest corrections: success text now says
“Change requested,” and output focus uses the canonical native focused-monitor
identity. The latter also adds native fixture assertions. Guest audio volume/mute
and fresh output-focus observations support these changes; the latest bytes have
**not** had another complete suite at this checkpoint. Later release source
checks are recorded above; no installed acceptance is added by that rerun.
Remaining installed acceptance is unverified, not passed; the
[Plan 007 checklist](services/desktop/CHECKLIST.md#plan-007-implementation-checkpoint)
records that boundary. Plan 006 stays complete, and RustDesk stays deferred.

The guest receipt is `%LOCALAPPDATA%\blendos-workstation\validation\plan007-installed\RESULTS.md`
(SHA-256 `c36ff957aa2b7e986a1707b403ce480db7af63f8615b18bc181ef0822d821ad4`).
It records installed component/session/desktop checks, audio controls, synthetic
MPRIS transport/removal, wired reconnection/editor and corrected output focus.
The disposable account's shell/container check failed on absent Portless setup;
not all installed validators passed. Remaining journeys are listed in the
checklist. Audio/NIC state was restored, temporary observers/media fixtures
removed, the disposable session logged out and normal ACPI shutdown left the
VM powered off. Cleanup does not pass the untested power UI.

## Plan 006 complete for the supported VM (2026-09-12)

### Takeover verification (2026-09-12)

The takeover stayed on `quickshell-shell` and corrected operator documentation
for the sole session, inactive-session installation and the required RustDesk
package server during every Akshara rebuild. Focused shell/QML, package, lock
guard, desktop and installer checks passed, followed by all 34 repository
checks, Bash syntax validation and `git diff --check`.

The fresh suite ran in Ubuntu 22.04 WSL2 with Go 1.27.1, resvg 0.48.1 and
Qt 6.2.4. All 27 Qt presentation cases passed, with three QQmlContext fixture
warnings; this is not a native lint result. The first focused installer attempt
lacked resvg on PATH; rerunning with the existing binary passed all subcases.
The complete suite log and focused logs are outside the repository under
`%LOCALAPPDATA%\blendos-workstation\validation\takeover-20260912-verify\`,
with the complete result in `repository-checks.log`. Matching source manifests
before and after that run have SHA-256
`2494f85a8bfbd24e9759947c88e8e3bd102117d2960ac4afb68c73f397a80939`;
only documentation changed afterward.

During the source rerun, the blendOS VM was off; that phase reran no installed
checks, native lint, graphical review, PAM or sleep tests. A later native
workspace check is recorded below; other guest results remain prior evidence.
The owner subsequently authorized committing the current work and
[deferred RustDesk functionality until the remaining workstation work is ready](docs/plans/README.md#owner-directed-rustdesk-sequencing-2026-09-12).
The remote capture failure remains unresolved but no longer gates Plan 006.

### Plan 006 installed completion (2026-09-12)

The remaining native workspace acceptance passed in the rebuilt blendOS
disposable account. The deployed shell hashes matched checkpoint `aa9334f`;
no production source change was needed. Super+1/Super+2 roundtrips and clicks on
the actual managed bar matched both its native active/focused snapshots and
`hyprctl` state. A real Wayland GTK client requested activation from workspace 1
while workspace 2 was focused: the native snapshot reported `urgent:true` and
the actual bar displayed workspace 1's red border. Clicking that bar button
focused workspace 1 and cleared both urgency and its red border. The before/after
screenshots were inspected independently.

Sanitized native records and screenshots are outside the repository under
`%LOCALAPPDATA%\blendos-workstation\validation\takeover-20260912-workspaces\`,
including `urgent-one-on-two.png` and `bar-urgent-one-cleared.png`.
`RESULTS.md` records all seven asserted live JSON/screenshot pairs, deployed
source provenance and cleanup; its SHA-256 is
`4a03cd6346bee47c0ac6134896b462e754dabe188e9ab0b187e8c497a83deb01`.
Temporary windows, probe and guest files were removed. `uwsm stop` returned
the disposable account to Ly, no owner graphical session was running, and a
normal ACPI shutdown left the VM powered off.
Together with the unchanged source suite and prior installed evidence in the
[desktop checklist](services/desktop/CHECKLIST.md), this completes Plan 006 for
the supported VM. RustDesk remains failed and deferred under the owner's
sequencing; physical hotplug/NVIDIA/device acceptance remains unperformed.
No RustDesk diagnosis or remote tests were part of this completion check.

### Existing implementation and acceptance record

The owner authorized production implementation of the selected Plan 006 stack
on the current branch. Source now supplies the sole Workstation session, original
Quickshell bar/tray, persistent shell with on-demand project panel, independent
PAM/Wayland locker, Hypridle, and compositor-confirmed sleep guard. Replaced
Noctalia/Waybar/Hyprlock owners are removed from active configuration. Walker,
Dunst, Awww and existing controls remain the selected utilities. Plan 010 owns
the later greeter; only pure authentication presentation is shared now.

Temporary guest SSH was restored with the original pinned host key. The public
recovery script was corrected to find that existing key in its original Local
State directory when `/etc/ssh` has no host key; console fingerprint verification
and four key-location/refusal fixtures passed. No key, sudo policy or host-key
verification was replaced. The verified RustDesk archive has been published to
the guest's loopback-only package repository. Akshara completed the declared
system rebuild with exit status 0; its log is
`~/.cache/blendos-workstation/plan006/akshara-update.log`.
The old desktop has been logged out. Sixteen replaced managed home leaves were
backed up with a receipt, and the config-only installer completed successfully.
The prepared root includes the Workstation UWSM entry, locker PAM configuration,
Quickshell, Hypridle and the native RustDesk build. The owner logged into the
Workstation session. Installed validation found competing upstream VirtualBox
autostart; a managed override and separate VMSVGA service now remove that race.
The updated configuration is deployed to the owner and disposable test account.

Native acceptance now passes the 79-component check, the 13-service session
check, QML lint, live socket/panel lifecycle and atomic theme reload, and native
dark/light render checks. In the disposable account, incorrect-password refusal,
keyboard retry/cancel, correct-password unlock and manual compositor lock pass.
The bar and guard restart after deliberate main-process crashes without ending
the locker; stored block inhibitors survive guard crashes both unlocked and
while a locked session retains a prepared inhibitor. External suspend is refused
while unlocked. Sanitized reports are under the test account's
`.cache/plan006-acceptance`; screenshots are in the Windows validation directory.

Installed testing found and fixed stale Caps Lock presentation when a button
held keyboard focus: modifier refresh now belongs to the shared form, with four
focus regression cases and native confirmation of Caps Lock on/off and layout
changes. The real ten-minute idle lock passed; eleven-minute display-off exposed
legacy Hyprland dispatcher syntax. Hypridle now uses Lua DPMS expressions;
the repeated real idle test locks at 601.79 seconds and turns the display off at
660.47 seconds. Keyboard wake returns to the locked password screen.
Failed and slow frontend tests each refused managed and external suspend for
thirty seconds while retaining the blocker. Managed suspend/resume then passed
with an ACPI wake signal and a temporary normal-user `handle-power-key`
inhibitor preventing a second shutdown action: the kernel success counter rose
from zero to one, failure counters stayed zero, and locker PID 14358 survived
until password authentication. Keyboard-only wake is not established for this
VM. VirtualBox Guest Control stopped accepting new sessions after resume;
the authenticated desktop terminal remained usable.
Further native acceptance verified project terminal/editor launches in the
selected directory and an explicit sleep agent in a session-bound scope with
measured CPU, memory and task counts. Panel hiding unloads subscriptions without
ending clients; logout ends the launched terminals/editor, agent scope, shell
and data service. A fresh login succeeds. A second headless output receives one
bar, with a readable 125% render; the visible locker is readable at 150%.
Light/dark bar, panel and locker palettes were inspected. A malformed initial
locker theme still acquires the secure compositor lock using its emergency
palette, and the valid theme can reload while locked.

Native notification inspection found two defects: Dunst 1.13.2 interpreted
`height=0` as a zero-height notification, and unquoted hexadecimal theme colors
were parsed as comments. The base height now uses `(0, 300)` and every generated
color is quoted. A parser regression failed before the fix and passes afterward;
regenerated native notifications visibly use the semantic palette. Walker opens
from Apps, and clipboard content survives the original source process exiting.

Tools, power and capture menu entry points now request an explicit Walker menu
provider, including on its first invocation. The Tools button uses the same
input-transparent native hint surface as other bar controls; its hover/click
regression passes. The audio mixer also needed a VirtualBox-only Cairo renderer,
verified against its failing default renderer and covered for physical-machine
isolation and explicit overrides. Integrated audio, network and display controls
render in the guest. Native D-Bus tray fixtures with duplicate application IDs
pass primary/middle activation, both scroll directions, menu selection and
removal/restart routing. The fixture reports are `tray-A.log` and `tray-B.log`
in the external validation directory; their temporary services have ended.

Installed desktop validation also exposed two incorrect assumptions: services
owned by the session target need not be individually enabled, and Elephant
reports managed menus as named `menus:*` providers. The validator now checks
loaded target dependencies and each managed menu, with negative regressions
for a missing service dependency and missing menu provider.
The corrected script's SHA-256 matches between Windows and the test account;
`validate-desktop-shell.sh --installed` passes in the graphical blendOS account.
Its native terminal evidence is `installed-desktop-contract-final.png` in the
external validation directory.

The current-source suite, rerun after the native controls and installed-validator fixes,
passes all 34 scripts (9 validators and 25 tests) plus `git diff --check`,
including real Go/resvg installer checks and Qt fixtures.
Its preserved log is
`%LOCALAPPDATA%\blendos-workstation\validation\plan006\source-suite-installed-contract-final.log`.
All 27 Qt presentation cases pass with Qt 6.2.4 and native blendOS Qt 6.11.2.
Quickshell 0.3.1
lint passes. Actual Quickshell source-loader checks on private headless Weston
load both roots/shared module, reject missing/invalid initial shell themes and
explicitly reject unavailable locking. A native Process fixture verifies guard
success, nonzero exit, failed startup and retry. These are isolated source checks,
not guest authentication or lock/suspend acceptance.

Inspected offscreen render evidence is retained outside the repository at
`%LOCALAPPDATA%\blendos-workstation\validation\plan006\`: normal and
narrow/150%-text bars, normal dark and enlarged light/error authentication, and
`bar-default-dark.png` at the delivered 48px height and 1920px width. Persistent
Arch originals and runtime logs are at
`/root/.cache/workstation-tools/arch-plan006/root.x86_64/root/workstation-views-7/`
in WSL. Independent review of all five images found legible text and no clipped
controls.

The native Arch `rustdesk-unattended-wayland` package
`1.5.0.dev.e82dd123-1` built successfully with the selected DRM/wake, hardware
codec and file clipboard features, Flutter 3.24.5, and libdrmtap 0.5.4. The
upstream EGL/runtime ABI gates and actual archive checks pass. All 13 dynamic
ELF files resolve; all 70 runtime library owners are covered by the package's
declared transitive dependencies. An isolated network-namespace test published
a real pacman database and fetched it and a byte-identical package over loopback.
The archive, full build log, closure report, publish/serve receipt, validation
receipt and SHA256SUMS are preserved at
`%LOCALAPPDATA%\blendos-workstation\validation\plan006\rustdesk\`.
Archive SHA-256:
`75f40062a075d3ca96ddf392c42e8f60658107123b18eb199836cf6ae7102395`.
Guest publication and Akshara installation are complete. Locked-session remote
capture/input/display-wake acceptance remains pending.

An isolated Arch systemd 261.3 manager in WSL verified the guard's actual
dependency behavior. After killing the synthetic guard, `RestartMode=direct`
changed its PID from 31 to 51 while shell PID 33 and locker PID 32 survived and
the session target stayed active. An explicit guard restart also restarted both
clients, as documented. The disposable overlay left its source root unchanged;
the manager, mount namespace and private cgroups were removed. This is native
systemd lifecycle evidence, not guest PAM, compositor or suspend acceptance.
The preserved result is
`%LOCALAPPDATA%\blendos-workstation\validation\plan006\systemd-crash-isolation.log`.

The rebuilt guest is accessible through the authenticated disposable account;
the installed results above establish only their named checks.
[Plan 006](docs/plans/006-quickshell-desktop-session.md) records the completed
supported-VM delivery; [desktop checklist](services/desktop/CHECKLIST.md) owns
acceptance and its remaining physical/deferred limits.

During source testing, a preexisting theme fixture's whole-repository copy
accidentally copied an excluded private root bootstrap into a disposable
directory. Its contents were not inspected or exposed; the fixture trap removed
the temporary tree. The test now uses the explicit public-root copy helper and
an exclusion sentinel check. The owner was informed. No private contents belong
in this record or delivered artifacts.
