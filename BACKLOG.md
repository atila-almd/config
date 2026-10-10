# Ordered workstation work

Priority 1 delivery and remaining acceptance steps: [STATE.md](STATE.md) and
[the desktop checklist](services/desktop/CHECKLIST.md).

| Priority | Tracked work | Status |
| --- | --- | --- |
| 2 | Window management, development layouts, project/agent launching, runtime/container tools and generated shortcuts | Source complete; next-login smoke tests in services/development remain |
| 3 | Theme pipeline, typography/scaling, integrated advanced audio/network/display/power controls | Source complete; native appearance/control smoke tests remain |
| 4 | Clipboard history, capture/recording, OCR/QR, conversion, reminders and sharing | Source complete; graphical capture/paste/reminder acceptance remains |
| 5 | Real agent status/usage, project instructions and explicit-action diagnosis | Source complete; native interactive scope acceptance remains |
| 6 | Updates, recovery improvements, customization ownership, firmware and diagnostics beyond Priority 1 foundations | Available source work complete; backup destination, target restore/boot recovery and physical storage acceptance remain |
| 7 | Optional dictation/auth, services, extra widgets/apps, local models, gaming/VMs, sync and hardware tuning | Deferred at the owner's latest request; do no Priority 7 work now |

The owner authorized priorities 2–7 in order on 2026-09-07. Source completion
and installed/visual acceptance are separate. Keep the VM off while repository
checks can establish the change; retain specific live checks for the final
deployment. Optional hardware and services still require a concrete workflow
and target rather than automatic installation of every category.

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
- Remaining physical and owner-interaction acceptance belongs to the desktop
  checklist, including audio/mic, Wi-Fi/Bluetooth, sharing/clipboard, lid/dock
  and suspend/resume. Do not add hardware services for devices the VM lacks.
- Priority 6 pins Node to a reviewed LTS release. OS/AUR repositories still roll;
  full dependency versions are not locked, so reinstall behavior is not
  bit-for-bit reproducible.
