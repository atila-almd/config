# Plan 006: Replace the old shells with one usable desktop

Status: DONE (supported VM, 2026-09-12). Dependencies: 005. Outcome: login to a bar and use terminal,
applications, workspaces, tray, project window, lock and ordinary utilities.

RustDesk runtime acceptance follows the owner's
[deferred sequencing](README.md#owner-directed-rustdesk-sequencing-2026-09-12).
It does not block this plan's completion; other required acceptance still does.
Native workspace focus, urgency and activation now pass in the supported VM,
completing its remaining acceptance. The
[desktop checklist](../../services/desktop/CHECKLIST.md) owns the exact evidence
and later utility/physical limitations; physical hardware is not yet accepted.

## Scope

Make Quickshell the sole managed shell: basic bar, workspace navigation, clock,
tray and entry points. Delete Noctalia/Waybar integration instead of adding a
third profile. Keep compositor, UWSM, terminal, portals and workstation backends.
Out: custom device/launcher/notification panels, greeter change, hardware
profiles, benchmarks and old-install conversion/cleanup machinery.

Grounding: Noctalia supplies bundled lock/idle/notifications/wallpaper/volume.
Installer deploys two targets and generated native palettes. Agent, record,
reminder, maintain and doctor detect those targets. Cutover must update this
whole chain together; deleting the package alone leaves a broken system.

## Selected production decisions

On 2026-09-11 the owner authorized defining the production stack directly,
without a separate proof of concept. The following choices resolve this plan's
tool/donor decisions and bind later plans. They define the intended production
design, now implemented and accepted for the supported VM under the revised scope.
The [research record](../login-lock-selection-research.md) preserves the evidence
and alternatives. Plan 010 owns the selected login implementation.

- Keep Hyprland and UWSM; deliver the sole Workstation session below.
- Build the bar and workspace/tray/button presentation as original Qt Quick
  Controls composition. Use native Quickshell compositor/tray adapters with
  explicit presentation contracts; no donor shell or copied QML is selected.
- Use an independent Quickshell locker process with `WlSessionLock` for
  compositor protection and native `PamContext` for unlock authentication.
  Share pure Qt Quick Controls presentation source with Plan 010's greeter,
  using separate window/authentication controllers. The locker is independent
  of the bar process; PAM remains upstream, and no custom password verifier or
  PAM engine is introduced.
- Use hypridle for idle/logind integration, retaining ten-minute lock and
  eleven-minute screen-off behavior. Set explicit sleep-inhibition mode 3 to
  consume Hyprland lock acknowledgement with the Quickshell locker; do not rely
  on automatic detection of a `hyprlock` executable name. Existing session-lock
  and power-control integration owns lock request -> confirmed secure state ->
  suspend, refusing suspension when locking fails. An independent logind block
  inhibitor guard keeps external suspend requests fail-closed while unlocked,
  in addition to hypridle's bounded delay notification. The guard owns only
  lock state, never credentials; unknown/lost acknowledgement must not release
  protection. Implement and test every release/failure path rather than treating
  mode 3 or a delay inhibitor alone as a failed-lock guarantee.
- Keep Awww and the existing wallpaper/theme helpers as the single wallpaper
  backend. Retain Walker/Elephant selection, Dunst notifications, WirePlumber
  volume commands and Pavucontrol until their delivering plans replace or
  extend the relevant presentation; these are sole utilities, not fallback shells.
- Keep native Quickshell command IPC and Plan 005's shared Unix-socket/JSON
  data service. Retain Basic Qt Controls and process-scoped VirtualBox renderer
  configuration; do not introduce a second data transport or session-wide override.
- Use the pinned upstream RustDesk DRM/KMS build defined below for the required
  locked-session remote-access path, packaged through blendOS. Plan 010 extends
  acceptance to the boot greeter; stock `rustdesk-bin` is not assumed to supply
  this feature.

Production implementation proceeds without an optional preselection prototype
or benchmark gate. Required source, render, authentication and installed-system
checks still apply; unsuccessful non-deferred acceptance leaves the plan incomplete.

### RustDesk production package

Select upstream RustDesk source revision
`e82dd12350479b848630d1e500c2f6870609a884` (development version 1.5.0), with
its recursive submodule revisions and Cargo lockfile, and the upstream-pinned
libdrmtap revision `5da68a3a368db569716d0d0f11cefacbb11b2290` (v0.5.4).
Build the native package with `flutter`, `drm` and `drm-wake`; retain the pinned
build chain, including Flutter 3.24.5 and vcpkg revision
`9e593bb18ea69cc5095e012465dcd675a822ed0d`. The private capture library belongs
under `/usr/lib/rustdesk/`. These are source pins, not floating nightly assets.
[Source/build features](https://github.com/rustdesk/rustdesk/blob/e82dd12350479b848630d1e500c2f6870609a884/Cargo.toml),
[upstream build integration](https://github.com/rustdesk/rustdesk/blob/e82dd12350479b848630d1e500c2f6870609a884/build.py).

Upstream's inspected DRM packaging supports its Debian path and rejects its
Pacman path. Deliver a project-owned native Arch package recipe and integrate
its artifact into the blendOS package source/System Definition and Akshara
rebuild, replacing `rustdesk-bin` and providing the RustDesk executable/service
without competing packages. No upstream Arch DRM package is assumed to exist.
Package permissions, capture/input access and display wake are part of this
delivery. Keep the existing network/security ownership and authenticated remote
access; enable only the selected documented DRM capture/wake path. Credentials
and remote authorization remain Local State, not package or repository content.

This selects preview-derived upstream functionality for production integration;
it does not assert stability or installed acceptance. Deferred remote acceptance covers
fresh connection while locked, remote authenticated input, disconnect/reconnect,
the eleven-minute screen-off state and wake, failure to initialize capture/input,
and lock/suspend protection. Plan 010 owns fresh boot-greeter access using the
same package after the remaining non-RustDesk work is ready. Remote failures
remain recorded; they authorize neither a fallback session nor a weakened lock.
The independent local lock/suspend checks remain required for this delivery.

## Interfaces

- Sole identity: `workstation.desktop`, inner `Exec=Hyprland`;
  `.config/systemd/user/blendos-workstation-session.target` bound to its UWSM
  target. No shell-selector environment variable or legacy targets.
- `workstation-shell.service` starts `session-workstation-shell` in foreground.
  All graphical services share the sole target; preview uses the same components
  with fixtures, not a second live backend implementation.
- API.md gains workspace/output/tray snapshots and typed intents. IDs come from
  backends. Subscribe to compositor/tray events. Upstream protocols stay native;
  adapters expose stable JSON-compatible snapshots at the presentation boundary.
- Shell open/toggle/close commands report errors using the chosen IPC. Exact
  endpoints/signatures follow the choice, not this planning document.
- Independent locker/idle lifecycle survives UI crash. Suspend waits on actual
  lock acknowledgement, not a successful process launch or IPC request.
- Shared authentication views take explicit prompts, palette and state inputs
  and emit intents. Credentials stay ephemeral in the appropriate controller,
  never in workstation-data, logs, workflow records or exported settings.
- Theme activation from 005 reaches one chosen wallpaper/backend and reports
  failure explicitly. No old-shell dispatch remains.

## Deliverables

- `surfaces/Bar.qml`, focused components/adapters, updated shell wrapper/entry.
- `.local/share/wayland-sessions/workstation.desktop`, the two named user units,
  chosen lock/idle/wallpaper configuration and rebuild-time session entry.
- Independent locker/idle/lock-state guard units and focused helper tests;
  native RustDesk package recipe, pinned inputs and blendOS rebuild integration
  under the existing service/package owners.
- Simplified installer, UWSM env, Hyprland bindings, controls/theme/wallpaper and
  agent/record/reminder/maintain/doctor integration; system/component declarations.
- Delete Noctalia/Waybar managed configs, their units/drop-ins, both old targets,
  Noctalia desktop entry/wrapper, obsolete templates and Waybar-only helpers/tests.
  Delete replaced Hyprlock integration and its unused template/package/tests
  when the independent Quickshell locker is delivered. Remove unused package
  declarations and runtime selector branches.
- `scripts/validate-user-session.sh`, affected behavioral tests, current
  desktop guide/CHECKLIST, root README, AGENTS and STATE updates.

## Checks

Search tracked owners for removed target/executable references: historical
research may name them, active code/operator docs may not. Test fresh installation
and unchanged rerun, copied unit mode 0644, component contract and affected
agent/record/reminder/theme behavior. Run the updated complete source suite.

Run QML checks and bar render fixtures. In rebuilt blendOS test login/logout,
no orphan services/scopes, one bar/notification/wallpaper/lock owner including
D-Bus/autostart, tray, workspace/terminal/project launch, clipboard after source
exit and notifications. Test manual/idle lock, screen off/on, suspend/resume,
slow/failed locker and shell crash. Inspect pixels/focus and renderer environment
isolation. No shell measurements or old-shell recovery acceptance.

For the deferred RustDesk acceptance, disconnect, lock, establish a
fresh authenticated remote connection, and unlock with remote input without a
local approval prompt. Preserve lock coverage and authentication; an existing
connection surviving lock is insufficient. See the
[login/lock compatibility research](../login-lock-selection-research.md).
Run this remote journey at the owner-directed point linked above.

## Done criteria

- Sole managed session renders a usable bar and supplies essential duties.
- Replaced configs/targets/branches and unused dependencies are deleted.
- Guest lifecycle/locking tests, source suite, QML and installer checks pass.
- Launch/login instructions and ownership match code; one completion commit.

## Assumptions

- Preserve binding intent and ten-minute lock/eleven-minute screen-off behavior,
  including pre-suspend lock; no automatic suspend policy is added.
- Fresh VM/account provisioning is the target. Missing guest access is pending
  acceptance, never a reason to implement fallback or migration paths.
