# Ordered workstation work

## Current pending work (2026-10-10)

The current Island, control center, launcher, notification/OSD and greetd/lock
implementations are in `main`. The release source suite passes all 40 checks;
installed and visual acceptance remains open. Historical Plan 005/006 VM
completion does not accept later Island/UI replacements or either newly composed
Machine Profile. The [desktop checklist](services/desktop/CHECKLIST.md) owns the
exact acceptance journeys; service guides own their commands.

The ordered list below tracks decisions and acceptance, rather than treating
unverified source as an absent implementation.

| Order | Gap / pending item | Kind | Completion evidence / next action | Owner |
| --- | --- | --- | --- | --- |
| 1 | Physical SSD install and selected-profile rebuild/deployment | Provisioning / unverified on hardware | Install blendOS v4 on the selected SSD, check Secure Boot requirements, copy/publish the reviewed RustDesk artifact, run physical bootstrap through rebuild/reboot/deployment; confirm installed package/session contracts | [Bootstrap and profiles](README.md#requirements-and-bootstrap) |
| 2 | Current Island and control-center acceptance (Plan 007 plus later Island replacement) | Installed / visual acceptance | Native Quickshell lint and inspected bar/card/scaled/keyboard renders; actual per-output/bar/tray/workspace lifecycle; audio/mic/default-device switching, media, Ethernet, themes/wallpaper with an active locker, settings reset/export, recording and deliberate power journeys | [Desktop checklist](services/desktop/CHECKLIST.md#plan-007-implementation-checkpoint) |
| 3 | Launcher, notification history/DND and OSD (Plans 008/009) | Installed / visual acceptance | Super+R/Super+Space, UWSM application launch, literal file paths, calculator copy, Escape/focus and missing backend; Dunst restart/DND/actions and volume/microphone feedback | [Desktop checklist](services/desktop/CHECKLIST.md#plan-008-launcher-checkpoint) |
| 4 | greetd/shared authentication and portals (Plan 010) | Installed / visual acceptance | Successful/failed login and unlock, logout/relogin, keyring unlock, TTY recovery, assets with home/share unavailable, file selection/screen sharing, matching login/lock/desktop pixels and 200% keyboard use | [Desktop checklist](services/desktop/CHECKLIST.md#plan-010-graphical-identitylogin-source-checkpoint) |
| 5 | Physical NVIDIA/outputs, wired Ethernet, audio/mic and secure sleep | Hardware acceptance | Driver/module and display/hotplug checks, real audio routing, Ethernet, lock coverage on every output, guarded suspend/resume; VM results do not pass these | [Profiles](README.md#machine-profiles), [desktop checklist](services/desktop/CHECKLIST.md) |
| 6 | Personal state and daily workflows | Owner setup / installed acceptance | Configure Git identities/mappings, register real projects/agents, complete launch/container/Portless and capture/paste/record/OCR/reminder/sharing journeys; authenticate Tailscale and configure requested applications | [Development](services/development/README.md), [productivity](services/productivity/README.md), [Local State](README.md#local-state-and-reruns) |
| 7 | Backup and whole-machine recovery | Owner decision / unresolved recovery contract | Choose actual backup storage/sources/credentials, verify representative restore and opt-in timer, rehearse update/off-device restoration; inspect the secondary SSD filesystem/boot layout before defining boot recovery | [Recovery guide](services/recovery/README.md#verification-still-required-on-the-target) |
| 8 | RustDesk locked/boot-greeter access | Known defect / owner-directed deferral | Existing native artifact is built and verified; recorded locked capture/input/wake failure remains. Resume diagnostics/acceptance after non-RustDesk Plans 005–010 are ready | [Recorded failure](services/rustdesk/README.md#known-capture-failure--deferred-by-owner-2026-09-12), [sequencing](docs/plans/README.md#owner-directed-rustdesk-sequencing-2026-09-12) |
| 9 | Public visibility | Owner decision | `main` is sanitized; the retained legacy `quickshell-shell` branch still carries personal metadata. Decide its custody/removal before changing the current private visibility | [History and recovery](README.md#history-and-recovery) |

The 33 MB native RustDesk archive already exists on the preparation machine;
its SHA-256 matches the accepted artifact recorded in [STATE.md](STATE.md).
Bootstrap needs that artifact published on the target, rather than another
build when the existing reviewed archive is reused. Copy instructions and
validation belong to the [package guide](services/rustdesk/README.md#build-and-publish).
Remote acceptance remains deferred even when the package is installed.

## Implementation and deferral boundaries

The locker identity-mark path mismatch was found during the working-change
audit and corrected to the installer's `/etc/blendos-workstation/identity`
location; the validator now covers the locker and rejects the stale path.
That source fix still needs visual inspection on the installed target.

The complete working-change comparison found all 37 managed dirty/untracked
changes already included in the sanitized root. See the
[retention audit](docs/audits/working-change-retention.md). The original checkout
remains dirty by design; it is an archive of the pre-release working state.

AI answers remain outside Plan 008 until a provider and credential/lifecycle
contract is selected. The future Rust/Smithay greeter compositor remains deferred
until current plans pass installed acceptance. Priority 7 dictation/auth,
additional services/widgets/apps, local models, gaming/VMs, sync and optional
hardware tuning remain deferred; this list authorizes no new implementation.
Minor lock-transition polish and VM performance tuning remain deferred.

Priorities 2–6 have source implementations; their real development, productivity,
agent, backup/update and physical workflows still need acceptance as listed
above. OS/AUR packages roll, so the repository does not reproduce identical
previous OS binaries. Keep the VM off while source checks can establish work.

## Deferred greeter compositor

Plan 010 now supplies the selected greetd/native-Quickshell identity source
stack and its public system-readable assets. Guest login, logout/relogin,
keyring, portal, TTY and visual acceptance remain the active prerequisite for
this plan; source completion does not authorize the deferred compositor work.

The owner designated a small, Cage-like compositor built with Rust/Smithay as
the next major project after [Plans 005–010](docs/plans/README.md) are complete,
including their installed acceptance. Its scope is the greeter/kiosk host:
replace the temporary login compositor while retaining the shared UI and
greetd boundary, not the workstation's desktop Hyprland compositor.

This work is deferred, not a dependency or completion gate for the current
plans. Add no Smithay dependencies or compositor implementation now. The
[current login design](docs/plans/010-desktop-identity-and-login.md#selected-production-decisions)
continues with the existing isolated Hyprland host until that later delivery.

## Discovery follow-ups

- Minor lock-transition appearance polish is Deferred at the owner's request.
  Blur-off reduced native lock acknowledgement to 171 ms; password/coverage passed.
- VM performance tuning is Deferred: high CPU/I/O wait and Hyper-V/NEM timing
  anomalies remain. Clocksource and compositor-blur experiments did not help;
  measured results and limits are recorded in the desktop checklist. Do not
  change host security/Hyper-V settings without an explicit request.
- Physical acceptance for the selected desktop covers NVIDIA/outputs, wired
  Ethernet, audio/mic and suspend/resume, plus the documented user workflows.
  Optional hardware needs a real device and owner-approved profile change.
- Priority 6 pins Node to a reviewed LTS release. OS/AUR repositories still roll;
  full dependency versions are not locked, so reinstall behavior is not
  bit-for-bit reproducible.
