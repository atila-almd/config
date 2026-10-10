# Desktop acceptance

## Plan 010 graphical identity/login source checkpoint

The selected login stack is now implemented in source: greetd is the sole
display-manager owner, its dedicated `greeter` account hosts an isolated
Hyprland/Quickshell pre-login process, and the authenticated handoff uses the
sole UWSM `workstation.desktop` entry. Public identity assets are installed
outside private home/theme state by the normal installer. Guest login, keyring,
portal, TTY and visual evidence remain open because this Windows checkout has
no rebuilt blendOS guest attached.

| Check | Current status |
| --- | --- |
| Source integration | Pass: greetd package/service/config, Ly removal, component rows, public asset projection and installer publication are validated |
| Greeter/controller | Pass: native Quickshell Greetd controller, account/password/error/retry/cancel states, UWSM handoff and isolated compositor host are present |
| Shared presentation | Pass: locker and greeter use the same `WorkstationShared/AuthForm.qml`; keyboard, focus and 200% source fixtures pass |
| Native lint/render | Shared/greeter view lint and Qt presentation tests pass in WSL; native Quickshell lint and inspected renders require blendOS/Quickshell |
| Installed login/lifecycle | Pending guest: successful/failed login, logout/relogin, keyring unlock, no-home/share assets, TTY access, one display manager/locker and portal file selection/screen sharing |

## Plan 009 Option 1 source checkpoint

Option 1 is selected: Dunst remains the notification owner, the existing
workstation-data service is the structured snapshot adapter, and the existing
Island attention surface is the volume/microphone OSD presentation. Source
implementation is present; installed and visual guest acceptance remains
open.

| Check | Current status |
| --- | --- |
| Ownership and contract | Pass: focused repository validator covers Dunst configuration, v1.13.2 audit facts, bounded history fields, plain-text/action limits, existing data/attention owners and no competing package |
| Source implementation | Pass: Go Dunst adapter, lazy Island history presentation, mutation intents and volume/microphone event feed are present |
| Source behavior/QML | Pass: bounded D-Bus/history tests, contract tests and QML notification-card fixtures are present; guest Dunst restart/keyboard evidence remains open |
| Installed and visual | guest acceptance pending: Dunst restart/DND/actions, volume/microphone keys, failure journeys and inspected Island/OSD renders |

## Plan 008 launcher checkpoint

The selected implementation is the Quickshell Island launcher over the
Elephant provider/index family. Source acceptance covers the framed JSON
bridge, request cancellation and bounded rows; installed acceptance must
exercise Super+R/Super+Space, application launch through UWSM, literal file
paths, calculator copy, missing Elephant behavior, Escape/focus and scaled
text. Walker remains the selected utility presentation for clipboard, symbols,
windows, menus/capture and shortcut selection. AI answers remain deferred
until an owner-selected provider and credential/lifecycle contract exists.

Island replaced the prior bar/panel surface after the last recorded Plan 006
receipt. The historical evidence below does not establish Island visual or
runtime acceptance; this implementation pass intentionally stopped before
running validation, so a fresh receipt is still required.

## Plan 007 implementation checkpoint

Plan 007 remains **IN PROGRESS** after the owner stopped additional verification
and authorized committing the implementation. [STATE.md](../../STATE.md#plan-007-implementation-checkpoint-2026-09-12)
owns the evidence paths, source-test boundary and guest receipt. This does not
change Plan 006's completed acceptance below.

| Check | Current status |
| --- | --- |
| Source and native fixtures | Prior 35-check suite, 17 control Qt cases and native lint/smoke passed; two later guest fixes and added native assertions were not fully retested |
| Guest observations | Audio volume/mute, synthetic MPRIS transport/removal, wired reconnection/editor and corrected startup output focus passed. Disposable shell/container check failed on absent Portless setup; not all installed validators passed |
| Remaining installed journeys | Second-device/default switching, active-locker exact-release theme and wallpaper changes, actual 200% keyboard/settings/reset/export, recording and Island power journeys remain unverified |
| Physical and remote limits | Physical devices remain unaccepted; RustDesk retains its owner-directed deferral |

## Plan 006 supported-VM acceptance

Plan 006 is **complete for the supported VM**. The takeover source rerun and
final native workspace checks supplement the prior installed evidence below.
[STATE.md](../../STATE.md#plan-006-installed-completion-2026-09-12) records the
final workspace evidence; its preceding source-verification record includes
the environment, warnings and external logs. Physical hardware remains unaccepted.
Earlier Noctalia evidence belongs to a replaced implementation.
RustDesk follows the owner's [deferred sequencing](../../docs/plans/README.md#owner-directed-rustdesk-sequencing-2026-09-12)
and is not this plan's completion gate.

| Check | Required evidence | Current status |
| --- | --- | --- |
| Source integration | Complete suite, installer fresh/rerun, component and sole-session contracts | Takeover rerun passes all 34 checks and 27 Qt cases on Qt 6.2.4. Prior guest evidence: 27 Qt cases pass on Qt 6.11.2; native component contract passes all 79 capabilities; corrected desktop validator passes installed |
| Native QML | Warning-free native lint; real source roots; live socket fixture and inspected renders | Arch native loader and bar/auth renders pass; guest lint, live socket/panel lifecycle and light/dark renders pass |
| Login/logout | Fresh sole greetd/Workstation login; single owners; no orphan graphical services/scopes | Prior Ly evidence is retired by Plan 010; greetd login, authenticated TTY recovery, relogin and scope teardown remain pending guest acceptance |
| Bar | Outputs, workspace focus/urgency/activation, narrow/scaled layouts | Native Virtual-1 and added headless output each have one bar; 125% output render passes. Keyboard/bar workspace activation matches native active/focused state; real Wayland urgency shows the red bar border and clears on bar activation. Physical hotplug remains unaccepted |
| Tray | Real activation/menu/middle/scroll; remove/restart and duplicate app IDs | Native RustDesk menu opens; real D-Bus fixtures with duplicate IDs pass primary/middle activation, both scroll directions, menu selection and removal/restart routing |
| Projects/launch | Terminal/editor/agent launch; hidden views unsubscribe; bar survives panel close | Native terminal/editor open the selected directory; explicit sleep agent runs in the session-bound scope with measured resources; hiding unloads subscriptions and retains clients; logout ends clients/scope |
| Theme | Atomic light/dark reload on bar/panel/locker; invalid theme still locks | Native light/dark bar, panel and locker inspected; malformed initial theme acquires secure lock with emergency palette; restored theme reloads while locked |
| Essential utilities | Launcher/audio/network/display/notification/wallpaper/clipboard interaction | Island launcher searches apps/files/calculations over Elephant; utility menus and clipboard remain Walker; audio/network/display controls render, with a VirtualBox-only Cairo fix for audio; clipboard survives source exit; Dunst height/colors fixed and inspected; theme activation restores Awww wallpaper. Broader portal file-selection/screen-sharing journeys belong to Plan 010; physical device checks await that hardware |
| Authentication | Correct/incorrect password, retry/cancel, keyboard-only use, changing prompts, Caps Lock/layout, scaling | Disposable-account PAM refusal/success, keyboard retry/cancel and Caps Lock/layout changes pass; visible locker inspected at 150%; physical scaling/output checks pending |
| Manual/idle lock | All outputs secure; ten-minute lock; eleven-minute screen-off and wake | Virtual-1 passes manual lock, idle lock at 601.79s, screen-off at 660.47s and keyboard wake to the locked form; compositor acknowledges secure lock with a second headless output; physical outputs pending |
| Suspend/resume | Guarded suspend; external sleep refused while unlocked; failed/slow locker stays protected | Failed/slow frontend and external-refusal tests pass. ACPI wake with temporary power-key handler passes kernel suspend/resume and locker survival; VM keyboard-only wake unconfirmed, Guest Control channel fails after resume |
| Failure handling | Bar crash while locked; protected locker crash; guard crash retains inhibitor | Native bar/guard faults pass. Locker PID 2142 killed; compositor crash surface remains protected, bar/guard survive; separately authenticated TTY3 ends only affected session and cleans its services/inhibitor |
| Remote locked access | Selected RustDesk artifact, fresh locked connection, remote unlock/reconnect, screen-off/wake and capture/input failure | Deferred until the remaining non-RustDesk workstation work is ready; acceptance incomplete. [Recorded capture failure](../rustdesk/README.md#known-capture-failure--deferred-by-owner-2026-09-12) |
| Physical hardware | NVIDIA, physical scaling/hotplug, microphone/device switching and selected lid behavior | Pending actual machine; VM evidence cannot pass |

Follow [README.md](README.md). Record exact versions, identity, outcomes and
artifact locations outside the repository. Use test accounts for automated PAM
checks; credentials and private content must not enter logs or fixtures.
No benchmark or old-shell recovery gate applies.
