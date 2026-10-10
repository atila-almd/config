# blendOS Workstation Environment

A personal, portable blendOS workstation built around Hyprland. The project
aims for the cohesion of Omarchy while selecting only the workflows and
components its owner needs. Omarchy is a reference, not the system's package
list or dependency boundary.

This repository is the source of Managed Configuration. It currently defines a
custom blendOS environment; it does not yet build or release a standalone
distribution.

## Documentation map

Each document has one audience and one responsibility:

- [README.md](./README.md) is the operator guide: layout, installation,
  verification, and current runtime behavior.
- [AGENTS.md](./AGENTS.md) tells contributors and coding agents how to evaluate
  components and make coherent changes.
- [CONTEXT.md](./CONTEXT.md) is only the canonical project glossary.
- [STATE.md](./STATE.md) records the current implementation checkpoint;
  [BACKLOG.md](./BACKLOG.md) tracks the ordered priorities.
- [Development workflows](services/development/README.md) owns project and
  agent launching, measured run status, project instructions, window arrangement
  and runtime/container entry points.
- [Productivity tools](services/productivity/README.md) owns recording, OCR/QR,
  conversions, clipboard sharing and reminders.
- [Recovery and maintenance](services/recovery/README.md) owns opt-in file backups,
  update checkpoints, restore procedures, runtime updates and hardware inspection.
- [Desktop guide](./services/desktop/README.md) owns the Quickshell session,
  lock/sleep behavior and guest acceptance procedure.
- [Workstation data API](services/desktop/API.md) owns the project/agent socket,
  backend build and launch commands consumed by Island cards.
- [services/portless/README.md](./services/portless/README.md) owns Portless and
  rootless Podman Compose usage, constraints, and troubleshooting.

When information belongs to another document, link to it instead of copying
it.

## Repository map

| Responsibility | Managed path |
| --- | --- |
| Common packages/services and explicit hardware additions | `system.yaml`, `profiles/` |
| Desktop Component Contract | `components.tsv` |
| Hyprland behavior and keybindings | `.config/hypr/hyprland.lua` |
| Ghostty terminal preferences | `.config/ghostty/config.ghostty` |
| Graphical and background user services | `.config/systemd/user/` |
| Default application associations | `.config/mimeapps.list` |
| Shell and development environment | `.zshenv`, `.zprofile`, `.zshrc`, `.config/mise/`, `.config/uwsm/`, `.gitconfig` |
| Project-owned command wrappers | `bin/` |
| Validation and compatibility scripts | `scripts/` |
| Service-specific assets and documentation | `services/` |
| Fresh bootstrap and lower-level deployment | `bootstrap`, `install.sh` |

The installer manages individual paths. It does not replace the target home
directory.

## Requirements and bootstrap

This is a personal workstation configuration, not a Linux distribution or an
Omarchy clone. Use a fresh **blendOS v4 x86_64** installation, a normal account
with sudo access, working Internet and sufficient rebuild storage. Python 3 and
PyYAML (Akshara's YAML dependency), Bash, Git, coreutils, systemd, flock and Akshara must be
available. The v5 alpha System Definition format is not supported by this entry
point. Install blendOS onto the selected secondary SSD yourself; bootstrap does
not select, partition or format a disk.

The existing RustDesk integration requires a reviewed native Arch package.
Follow [its build/publish guide](services/rustdesk/README.md#build-and-publish)
or supply an existing artifact with `--rustdesk-package`. This is an explicit
bootstrap prerequisite; the repository contains no binary package or private
RustDesk credentials. An unconfigured fresh clone can still run dry-run.

```sh
git clone --single-branch --branch main https://github.com/atila-almd/config.git "$HOME/workstation"
cd "$HOME/workstation"
./bootstrap physical --dry-run
# From a TTY after logging out of the graphical session:
./bootstrap physical --rustdesk-package /absolute/path/to/rustdesk.pkg.tar.zst
# Reboot deliberately after a successful rebuild, then:
./bootstrap physical
```

The repository is currently private at the owner’s request; cloning requires
GitHub access. `--single-branch` selects the sanitized `main` history. For a
VirtualBox guest, choose `vm` instead. A profile is always required; hardware detection never
selects one. Keep the checkout at its installation path because ordinary
Managed Configuration is linked to it.

Bootstrap validates prerequisites and the profile before staging the composed
System Definition in Local State. It preserves displaced `/system.yaml` and
home files, serves the reviewed loopback package repository during
`sudo akshara update`, and records success only when the rebuild succeeds.
It requests a reboot without performing one. The next invocation on another
boot verifies packages, deploys Managed Configuration, publishes the public
greeter identity bundle, and enables Session Components for the next deliberate
Workstation login. A matching completed definition skips rebuilding. Changed
definitions repeat the rebuild/reboot sequence. Deployment never restarts an
active desktop; log out before rerunning.

`--dry-run` validates and prints the intended actions and missing prerequisites.
It performs no writes, sudo commands, downloads or rebuilds. It can run in WSL
when Python/PyYAML are available; apply mode requires blendOS. A successful
source check or rebuild does not establish installed or visual acceptance.

## Machine Profiles

| Profile | Target | Profile-specific configuration |
| --- | --- | --- |
| `vm` | VirtualBox with VMSVGA graphics | Guest utilities/service, clipboard and VMSVGA session units, explicit 1920x1080 scale 1, client-scoped software renderers |
| `physical` | AMD Ryzen 7 5800X, NVIDIA RTX 4060, ASUS TUF GAMING B550M-PLUS desktop; wired Realtek RTL8125 | AMD microcode, Mesa/EGL and NVIDIA open DKMS driver; normal preferred display mode and native rendering |

The physical target is the owner's existing machine with blendOS on a secondary
SSD. Wi-Fi/Bluetooth hardware was not detected and is not enabled by this
profile. Secure Boot state and any needed module-signing setup remain manual
verification items. Common `linux-firmware` supplies firmware; the physical
profile declares `amd-ucode`. RTX 4060 uses `nvidia-open-dkms` following the
[current Arch driver package transition](https://archlinux.org/news/nvidia-590-driver-drops-pascal-support-main-packages-switch-to-open-kernel-modules/).
Driver build, outputs, Ethernet, firmware and sleep are **unverified on hardware**.

`system.yaml` owns common packages/services; `profiles/<name>.yaml` owns hardware
additions. `scripts/render-system-definition.py` composes them without modifying
source. `profiles/physical.yaml.example` shows the contract for an owner-reviewed
new target. Local selection is recorded under the machine state directory and
published as `/etc/blendos-workstation/machine-profile` for runtime consumers.
Only an explicitly selected `vm` profile installs guest units or rendering
fallbacks. Switching profiles requires bootstrap and its rebuild/reboot cycle;
configuration-only installation is not a hardware migration path.

## Local State and reruns

Local State lives outside the checkout, normally under
`${XDG_STATE_HOME:-$HOME/.local/state}/blendos-workstation/`. The installer creates
private state directories; neither bootstrap nor deployment imports personal
values from the development machine.

| State | Created by / setup |
| --- | --- |
| `machine/` | Bootstrap: selected profile, rendered System Definition, rebuild/reboot receipts and package server log |
| `backups/` | Installer: timestamped copies of displaced configuration |
| `git/` | `git-profile`: personal identities and directory mappings; see [Git identity profiles](#git-identity-profiles) |
| `theme/` | Theme activation: generated releases, selection and wallpaper indexes |
| `projects/`, `agents/` | Explicit project registration and agent runs; [development guide](services/development/README.md) |
| Backup and maintenance records | Explicit configuration/operations; [recovery guide](services/recovery/README.md) |
| `package-repo/` | Reviewed native RustDesk artifact publication; [RustDesk guide](services/rustdesk/README.md) |
| Application credentials, SSH/GPG keys, tailnet/RustDesk identity | Upstream application configuration and key stores; create/authenticate locally, never copy into managed source |

The ignored `local/` directory is optional operator input, not automatically
loaded. Committed `*.example` files show Git identity, backup and optional
bootstrap inputs. Copy an example to a name without `.example`, review and
supply values yourself. Keep actual passwords/key material outside the checkout.
`.gitignore` is a guardrail; review staged changes before publishing.

The active definition chain is:

```text
/system.yaml -> ~/system.yaml -> ~/.local/state/blendos-workstation/machine/system.yaml
```

Use `readlink -f /system.yaml` to inspect the actual path when XDG state is
customized. Ordinary managed paths are symlinked; user systemd units are copied
with mode `0644` so VirtualBox shared-folder masks do not invalidate them.
Rerun deployment after unit edits. UWSM loads `.config/uwsm/env` for project
helpers. A full install publishes the public identity bundle before enabling
greetd; if the first rebuilt boot remains on a TTY, rerun bootstrap there.

`install.sh` is the lower-level deployment helper. After bootstrap has selected
a profile, `bash install.sh --config-only` updates home paths/units without
runtime/account/system provisioning, preserving backups. `--home-only` still
provisions account runtimes; `--system-only` only stages the definition. See
[desktop lifecycle](services/desktop/README.md#installation-and-lifecycle).

Remaining manual work includes installed validators, display/GPU and Ethernet
checks, audio/microphone, login/keyring/portals, lock/sleep and visual acceptance;
Git identities; Tailscale authentication; RustDesk pairing; and optional backup
storage, credentials and timer activation. No backup timer is enabled until the
owner explicitly configures it.

## Capability status

Status comes from `components.tsv`, the Component Contracts: **Planned** means
there is no accepted installed evidence for this profile; **Installed** means
observed installation still lacks full integration acceptance; **Integrated**
requires installed, reachable, lifecycle-aware and default-consistent behavior
under [CONTEXT.md](CONTEXT.md); **Blocked** identifies a concrete impediment.
Source implementation can exist while its capability is Planned.

Status is deliberately conservative for both newly composed profiles. No capability
is currently marked Integrated: prior VM evidence is retained in notes, while
installation and lifecycle under the explicit profile still need acceptance.
Physical status is deliberately conservative. VM evidence does not establish
hardware acceptance, and earlier desktop evidence does not accept the new
Quickshell launcher, controls, notification history or greeter. Notes link to
owning evidence. Compatibility Shims include their justification; there are no
Project Forks currently declared. The status values/evidence are maintained by
hand in the contract, while these tables are generated. After changing accepted
evidence, run `python3 scripts/capability-status.py --write`; repository checks
reject a stale table.

<details open>
<summary>Physical machine</summary>

<!-- capabilities:physical:start -->
| Capability | Workflow(s) | Component | Integration Point | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| desktop-data | Work on projects and run coding agents | go → workstation-data | helper:workstation-data | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/development/README.md) |
| island-projects-card | Work on projects and run coding agents | quickshell → session-workstation-shell | helper:session-workstation-shell | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; unverified on hardware; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/development/README.md) |
| island-card-surface | Navigate the desktop and open applications | quickshell → session-workstation-shell | hypr:binding | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; unverified on hardware; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| terminal | Navigate the desktop and open applications | ghostty → session-terminal | hypr:var:terminal | Planned | Component observed in VM; complete current workflow and explicit-profile deployment need verification; unverified on hardware; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| file-manager | Navigate the desktop and open applications | nemo → nemo | hypr:var:fileManager | Planned | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| launcher | Navigate the desktop and open applications | quickshell → session-workstation-shell | hypr:binding | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; unverified on hardware; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| launcher-service | Navigate the desktop and open applications | go → workstation-launcher | systemd-user:workstation-launcher.service | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| launcher-backend | Navigate the desktop and open applications | elephant → elephant | systemd-user:elephant.service | Planned | Component observed in VM; complete current workflow and explicit-profile deployment need verification; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| audio-control | Adjust audio and control playback | wireplumber → wpctl | hypr:binding | Planned | Component observed in VM; complete current workflow and explicit-profile deployment need verification; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| audio-mixer | Adjust audio and control playback | pavucontrol → workstation-controls | helper:workstation-controls | Planned | Component observed in VM; complete current workflow and explicit-profile deployment need verification; unverified on hardware; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| brightness-control | Adjust physical display brightness | brightnessctl → brightnessctl | hypr:binding | Planned | Component observed in VM; complete current workflow and explicit-profile deployment need verification; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| media-control | Adjust audio and control playback | playerctl → playerctl | hypr:binding | Planned | Component observed in VM; complete current workflow and explicit-profile deployment need verification; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| island-shell | Navigate the desktop and open applications | quickshell → session-workstation-shell | systemd-user:workstation-shell.service | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; unverified on hardware; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| island-dashboard | Navigate the desktop and open applications | quickshell → session-workstation-shell | hypr:binding | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; unverified on hardware; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| island-timer | Manage focus time and reminders | quickshell → session-workstation-shell | hypr:binding | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; unverified on hardware; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| notifications | Read notifications and control interruptions | dunst → dunst | systemd-user:dunst.service | Planned | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| notification-history | Read notifications and control interruptions | quickshell → session-workstation-shell | hypr:binding | Planned | Plan 009 Option 1; Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; unverified on hardware; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| notification-control | Read notifications and control interruptions | dunst → dunstctl | hypr:binding | Planned | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| wallpaper | Change appearance and restore wallpapers | awww → awww-daemon | systemd-user:awww-daemon.service | Planned | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| wallpaper-selection | Change appearance and restore wallpapers | awww → workstation-wallpaper | helper:workstation-wallpaper | Planned | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| wallpaper-keybinding | Change appearance and restore wallpapers | awww → workstation-wallpaper | hypr:binding | Planned | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| clipboard-persistence | Copy and reuse text or symbols | wl-clip-persist → wl-clip-persist | systemd-user:wl-clip-persist.service | Planned | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| lock-screen | Protect the session while away or asleep | quickshell → session-lock | hypr:binding | Planned | Component observed in VM; complete current workflow and explicit-profile deployment need verification; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| idle-lock | Protect the session while away or asleep | hypridle → hypridle | systemd-user:hypridle.service | Planned | Component observed in VM; complete current workflow and explicit-profile deployment need verification; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| protected-suspend | Protect the session while away or asleep | go → workstation-suspend | helper:workstation-suspend | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| theme-selection | Change appearance and restore wallpapers | jq → workstation-theme | helper:workstation-theme | Planned | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| theme-keybinding | Change appearance and restore wallpapers | jq → workstation-theme | hypr:binding | Planned | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| screenshot | Capture and transform media or share files | hyprshot → workstation-capture | hypr:binding | Planned | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; unverified on hardware; [evidence](services/productivity/README.md) |
| color-picker | Capture and transform media or share files | hyprpicker → workstation-capture | helper:workstation-capture | Planned | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; unverified on hardware; [evidence](services/productivity/README.md) |
| screen-recording | Capture and transform media or share files | wf-recorder → workstation-record | helper:workstation-record | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/productivity/README.md) |
| screen-ocr | Capture and transform media or share files | tesseract → workstation-media | helper:workstation-media | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/productivity/README.md) |
| ocr-english | Capture and transform media or share files | tesseract-data-eng → workstation-media | helper:workstation-media | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/productivity/README.md) |
| ocr-portuguese | Capture and transform media or share files | tesseract-data-por → workstation-media | helper:workstation-media | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/productivity/README.md) |
| qr-reader | Capture and transform media or share files | zbar → workstation-media | helper:workstation-media | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/productivity/README.md) |
| qr-generator | Capture and transform media or share files | qrencode → workstation-media | helper:workstation-media | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/productivity/README.md) |
| image-conversion | Capture and transform media or share files | imagemagick → workstation-media | helper:workstation-media | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/productivity/README.md) |
| media-conversion | Capture and transform media or share files | ffmpeg → workstation-media | helper:workstation-media | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/productivity/README.md) |
| file-sharing | Capture and transform media or share files | wl-clipboard → workstation-media | helper:workstation-media | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/productivity/README.md) |
| reminders | Manage focus time and reminders | libnotify → workstation-remind | helper:workstation-remind | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/productivity/README.md) |
| desktop-utilities | Navigate the desktop and open applications | walker-bin → session-walker | hypr:binding | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-theme | Change appearance and restore wallpapers | jq → workstation-theme | menu:workstation.toml | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-wallpaper | Change appearance and restore wallpapers | awww → workstation-wallpaper | menu:workstation.toml | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-shortcuts | Inspect and maintain the workstation | hyprland → workstation-keybindings | menu:workstation.toml | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-audio | Adjust audio and control playback | quickshell → workstation-controls | menu:workstation.toml | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-network | Configure networking and reach trusted remote machines | network-manager-applet → workstation-controls | menu:workstation.toml | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-search | Navigate the desktop and open applications | walker-bin → walker | menu:workstation.toml | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-notifications | Read notifications and control interruptions | dunst → dunstctl | menu:workstation-notifications.toml | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-capture | Capture and transform media or share files | hyprshot → workstation-capture | menu:workstation-capture.toml | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/productivity/README.md) |
| control-menu-browser | Navigate the desktop and open applications | zen-browser-bin → zen-browser | menu:workstation-tools.toml | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-terminal | Navigate the desktop and open applications | ghostty → session-terminal | menu:workstation-tools.toml | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| system-monitor | Inspect and maintain the workstation | btop → btop | menu:workstation-tools.toml | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| terminal-files | Navigate the desktop and open applications | yazi → yazi | menu:workstation-tools.toml | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| terminal-editor | Navigate the desktop and open applications | neovim → nvim | menu:workstation-tools.toml | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| clipboard-history | Copy and reuse text or symbols | elephant-clipboard → walker | hypr:binding | Planned | Component observed in VM; complete current workflow and explicit-profile deployment need verification; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| symbol-picker | Copy and reuse text or symbols | elephant-symbols → walker | hypr:binding | Planned | Component observed in VM; complete current workflow and explicit-profile deployment need verification; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| window-switcher | Navigate the desktop and open applications | elephant-windows → walker | hypr:binding | Planned | Component observed in VM; complete current workflow and explicit-profile deployment need verification; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| browser-keybinding | Navigate the desktop and open applications | zen-browser-bin → zen-browser | hypr:binding | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| shortcut-reference | Navigate the desktop and open applications | hyprland → workstation-keybindings | hypr:binding | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| project-launcher | Work on projects and run coding agents | ghostty → workstation-project | hypr:binding | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| agent-status | Work on projects and run coding agents | time → workstation-agent | helper:workstation-agent | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/development/README.md) |
| workstation-diagnosis | Inspect and maintain the workstation | systemd → workstation-doctor | helper:workstation-doctor | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/recovery/README.md) |
| file-backup | Back up and recover personal files | restic → workstation-backup | helper:workstation-backup | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/recovery/README.md) |
| update-checkpoints | Inspect and maintain the workstation | blend → workstation-maintain | helper:workstation-maintain | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/recovery/README.md) |
| firmware-inspection | Inspect and maintain the workstation | fwupd → workstation-doctor | helper:workstation-doctor | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/recovery/README.md) |
| desktop-settings | Inspect and maintain the workstation | jq → workstation-controls | hypr:binding | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| directory-default | Open files with consistent defaults | nemo → nemo | xdg-default:nemo.desktop | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| image-viewer | Open files with consistent defaults | imv → imv | xdg-default:imv.desktop | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| document-viewer | Open files with consistent defaults | zathura → zathura | xdg-default:org.pwmt.zathura.desktop | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| pdf-backend | Open files with consistent defaults | zathura-pdf-mupdf → zathura | xdg-default:org.pwmt.zathura.desktop | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| media-player | Open files with consistent defaults | mpv → mpv | xdg-default:mpv.desktop | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| policy-agent | Authorize operations and share files or the desktop | hyprpolkitagent → /usr/lib/hyprpolkitagent/hyprpolkitagent | systemd-user:hyprpolkitagent.service | Planned | Component observed in VM; complete current workflow and explicit-profile deployment need verification; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| portal | Authorize operations and share files or the desktop | xdg-desktop-portal-hyprland → /usr/lib/xdg-desktop-portal-hyprland | dbus-user:xdg-desktop-portal-hyprland.service | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| network-applet | Configure networking and reach trusted remote machines | network-manager-applet → nm-applet | xdg-autostart:nm-applet.desktop | Planned | Component observed in VM; complete current workflow and explicit-profile deployment need verification; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| network-editor | Configure networking and reach trusted remote machines | network-manager-applet → workstation-controls | menu:workstation.toml | Planned | Component observed in VM; complete current workflow and explicit-profile deployment need verification; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| browser | Navigate the desktop and open applications | zen-browser-bin → zen-browser | xdg-default:zen.desktop | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| host-firewall | Configure networking and reach trusted remote machines | ufw → ufw | system-service:ufw | Planned | Source implementation present; installed workflow acceptance pending; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| remote-overlay-network | Configure networking and reach trusted remote machines | tailscale → tailscale | system-service:tailscaled | Planned | Component observed in VM; complete current workflow and explicit-profile deployment need verification; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| remote-desktop | Configure networking and reach trusted remote machines | rustdesk-unattended-wayland → rustdesk | system-service:rustdesk.service | Blocked | Known locked-connection capture failure; owner-deferred diagnosis; requires reviewed native package; unverified on hardware; **Compatibility Shim**: Native Arch packaging stages the upstream DRM variant without a RustDesk source fork; [evidence](services/rustdesk/README.md) |
| graphical-login | Sign in to the workstation | greetd → greetd | system-service:greetd.service | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| login-greeter | Sign in to the workstation | quickshell → /etc/blendos-workstation/identity/greeter-host | system-service:greetd.service | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| container-engine | Run local development services without Docker | podman → podman | rootless-user:podman.socket | Planned | Component observed in VM; complete current workflow and explicit-profile deployment need verification; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| compose-provider | Run local development services without Docker | podman-compose → podman-compose | podman:compose-provider | Planned | Component observed in VM; complete current workflow and explicit-profile deployment need verification; unverified on hardware; [evidence](services/desktop/CHECKLIST.md) |
| development-routes | Run local development services without Docker | mise → portless-compose | helper:portless-compose | Planned | Existing loopback .localhost workflow; complete provisioning was absent in the disposable VM receipt; unverified on hardware; **Compatibility Shim**: Pinned Portless 0.15.6 bind patch removes its privileged-port assumption; exact-source checks fail closed; [evidence](services/portless/README.md) |
| git-identities | Commit with the intended public or work identity | git → git-profile | helper:git-profile | Planned | Explicit identity profiles and directory mappings are Local State; configure personally; unverified on hardware; [evidence](README.md#git-identity-profiles) |
<!-- capabilities:physical:end -->

</details>

<details>
<summary>VirtualBox evidence</summary>

<!-- capabilities:vm:start -->
| Capability | Workflow(s) | Component | Integration Point | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| desktop-data | Work on projects and run coding agents | go → workstation-data | helper:workstation-data | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/development/README.md) |
| island-projects-card | Work on projects and run coding agents | quickshell → session-workstation-shell | helper:session-workstation-shell | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/development/README.md) |
| island-card-surface | Navigate the desktop and open applications | quickshell → session-workstation-shell | hypr:binding | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| terminal | Navigate the desktop and open applications | ghostty → session-terminal | hypr:var:terminal | Installed | Component observed in VM; complete current workflow and explicit-profile deployment need verification; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| file-manager | Navigate the desktop and open applications | nemo → nemo | hypr:var:fileManager | Installed | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; [evidence](services/desktop/CHECKLIST.md) |
| launcher | Navigate the desktop and open applications | quickshell → session-workstation-shell | hypr:binding | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| launcher-service | Navigate the desktop and open applications | go → workstation-launcher | systemd-user:workstation-launcher.service | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; [evidence](services/desktop/CHECKLIST.md) |
| launcher-backend | Navigate the desktop and open applications | elephant → elephant | systemd-user:elephant.service | Installed | Component observed in VM; complete current workflow and explicit-profile deployment need verification; [evidence](services/desktop/CHECKLIST.md) |
| audio-control | Adjust audio and control playback | wireplumber → wpctl | hypr:binding | Installed | Component observed in VM; complete current workflow and explicit-profile deployment need verification; [evidence](services/desktop/CHECKLIST.md) |
| audio-mixer | Adjust audio and control playback | pavucontrol → workstation-controls | helper:workstation-controls | Installed | Component observed in VM; complete current workflow and explicit-profile deployment need verification; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| brightness-control | Adjust physical display brightness | brightnessctl → brightnessctl | hypr:binding | Installed | Component observed in VM; complete current workflow and explicit-profile deployment need verification; [evidence](services/desktop/CHECKLIST.md) |
| media-control | Adjust audio and control playback | playerctl → playerctl | hypr:binding | Installed | Component observed in VM; complete current workflow and explicit-profile deployment need verification; [evidence](services/desktop/CHECKLIST.md) |
| island-shell | Navigate the desktop and open applications | quickshell → session-workstation-shell | systemd-user:workstation-shell.service | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| island-dashboard | Navigate the desktop and open applications | quickshell → session-workstation-shell | hypr:binding | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| island-timer | Manage focus time and reminders | quickshell → session-workstation-shell | hypr:binding | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| notifications | Read notifications and control interruptions | dunst → dunst | systemd-user:dunst.service | Installed | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; [evidence](services/desktop/CHECKLIST.md) |
| notification-history | Read notifications and control interruptions | quickshell → session-workstation-shell | hypr:binding | Planned | Plan 009 Option 1; Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| notification-control | Read notifications and control interruptions | dunst → dunstctl | hypr:binding | Installed | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; [evidence](services/desktop/CHECKLIST.md) |
| wallpaper | Change appearance and restore wallpapers | awww → awww-daemon | systemd-user:awww-daemon.service | Installed | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; [evidence](services/desktop/CHECKLIST.md) |
| wallpaper-selection | Change appearance and restore wallpapers | awww → workstation-wallpaper | helper:workstation-wallpaper | Installed | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; [evidence](services/desktop/CHECKLIST.md) |
| wallpaper-keybinding | Change appearance and restore wallpapers | awww → workstation-wallpaper | hypr:binding | Installed | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; [evidence](services/desktop/CHECKLIST.md) |
| clipboard-persistence | Copy and reuse text or symbols | wl-clip-persist → wl-clip-persist | systemd-user:wl-clip-persist.service | Installed | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; [evidence](services/desktop/CHECKLIST.md) |
| vm-shared-clipboard | Develop and validate in VirtualBox | virtualbox-guest-utils → VBoxClient | systemd-user:vboxclient-clipboard.service | Planned | Prior guest behavior accepted; newly separated profile has not been deployed; VM-only capability; [evidence](services/desktop/CHECKLIST.md) |
| vm-display-assistant | Develop and validate in VirtualBox | virtualbox-guest-utils → VBoxClient | systemd-user:vboxclient-vmsvga.service | Planned | Prior guest behavior accepted; newly separated profile has not been deployed; VM-only capability; [evidence](services/desktop/CHECKLIST.md) |
| lock-screen | Protect the session while away or asleep | quickshell → session-lock | hypr:binding | Installed | Component observed in VM; complete current workflow and explicit-profile deployment need verification; [evidence](services/desktop/CHECKLIST.md) |
| idle-lock | Protect the session while away or asleep | hypridle → hypridle | systemd-user:hypridle.service | Installed | Component observed in VM; complete current workflow and explicit-profile deployment need verification; [evidence](services/desktop/CHECKLIST.md) |
| protected-suspend | Protect the session while away or asleep | go → workstation-suspend | helper:workstation-suspend | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; [evidence](services/desktop/CHECKLIST.md) |
| theme-selection | Change appearance and restore wallpapers | jq → workstation-theme | helper:workstation-theme | Installed | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; [evidence](services/desktop/CHECKLIST.md) |
| theme-keybinding | Change appearance and restore wallpapers | jq → workstation-theme | hypr:binding | Installed | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; [evidence](services/desktop/CHECKLIST.md) |
| screenshot | Capture and transform media or share files | hyprshot → workstation-capture | hypr:binding | Installed | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; [evidence](services/productivity/README.md) |
| color-picker | Capture and transform media or share files | hyprpicker → workstation-capture | helper:workstation-capture | Installed | Prior VM integration evidence exists; explicit-profile installation and lifecycle need renewed acceptance; [evidence](services/productivity/README.md) |
| screen-recording | Capture and transform media or share files | wf-recorder → workstation-record | helper:workstation-record | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/productivity/README.md) |
| screen-ocr | Capture and transform media or share files | tesseract → workstation-media | helper:workstation-media | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/productivity/README.md) |
| ocr-english | Capture and transform media or share files | tesseract-data-eng → workstation-media | helper:workstation-media | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/productivity/README.md) |
| ocr-portuguese | Capture and transform media or share files | tesseract-data-por → workstation-media | helper:workstation-media | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/productivity/README.md) |
| qr-reader | Capture and transform media or share files | zbar → workstation-media | helper:workstation-media | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/productivity/README.md) |
| qr-generator | Capture and transform media or share files | qrencode → workstation-media | helper:workstation-media | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/productivity/README.md) |
| image-conversion | Capture and transform media or share files | imagemagick → workstation-media | helper:workstation-media | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/productivity/README.md) |
| media-conversion | Capture and transform media or share files | ffmpeg → workstation-media | helper:workstation-media | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/productivity/README.md) |
| file-sharing | Capture and transform media or share files | wl-clipboard → workstation-media | helper:workstation-media | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/productivity/README.md) |
| reminders | Manage focus time and reminders | libnotify → workstation-remind | helper:workstation-remind | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/productivity/README.md) |
| desktop-utilities | Navigate the desktop and open applications | walker-bin → session-walker | hypr:binding | Planned | Source implementation present; installed workflow acceptance pending; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-theme | Change appearance and restore wallpapers | jq → workstation-theme | menu:workstation.toml | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-wallpaper | Change appearance and restore wallpapers | awww → workstation-wallpaper | menu:workstation.toml | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-shortcuts | Inspect and maintain the workstation | hyprland → workstation-keybindings | menu:workstation.toml | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-audio | Adjust audio and control playback | quickshell → workstation-controls | menu:workstation.toml | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-network | Configure networking and reach trusted remote machines | network-manager-applet → workstation-controls | menu:workstation.toml | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-search | Navigate the desktop and open applications | walker-bin → walker | menu:workstation.toml | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-notifications | Read notifications and control interruptions | dunst → dunstctl | menu:workstation-notifications.toml | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-capture | Capture and transform media or share files | hyprshot → workstation-capture | menu:workstation-capture.toml | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/productivity/README.md) |
| control-menu-browser | Navigate the desktop and open applications | zen-browser-bin → zen-browser | menu:workstation-tools.toml | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| control-menu-terminal | Navigate the desktop and open applications | ghostty → session-terminal | menu:workstation-tools.toml | Planned | Source implementation present; installed workflow acceptance pending; **Compatibility Shim**: Client-scoped software rendering only in the explicitly selected vm profile; native rendering on physical hardware; [evidence](services/desktop/CHECKLIST.md) |
| system-monitor | Inspect and maintain the workstation | btop → btop | menu:workstation-tools.toml | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| terminal-files | Navigate the desktop and open applications | yazi → yazi | menu:workstation-tools.toml | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| terminal-editor | Navigate the desktop and open applications | neovim → nvim | menu:workstation-tools.toml | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| clipboard-history | Copy and reuse text or symbols | elephant-clipboard → walker | hypr:binding | Installed | Component observed in VM; complete current workflow and explicit-profile deployment need verification; [evidence](services/desktop/CHECKLIST.md) |
| symbol-picker | Copy and reuse text or symbols | elephant-symbols → walker | hypr:binding | Installed | Component observed in VM; complete current workflow and explicit-profile deployment need verification; [evidence](services/desktop/CHECKLIST.md) |
| window-switcher | Navigate the desktop and open applications | elephant-windows → walker | hypr:binding | Installed | Component observed in VM; complete current workflow and explicit-profile deployment need verification; [evidence](services/desktop/CHECKLIST.md) |
| browser-keybinding | Navigate the desktop and open applications | zen-browser-bin → zen-browser | hypr:binding | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| shortcut-reference | Navigate the desktop and open applications | hyprland → workstation-keybindings | hypr:binding | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| project-launcher | Work on projects and run coding agents | ghostty → workstation-project | hypr:binding | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| agent-status | Work on projects and run coding agents | time → workstation-agent | helper:workstation-agent | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/development/README.md) |
| workstation-diagnosis | Inspect and maintain the workstation | systemd → workstation-doctor | helper:workstation-doctor | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/recovery/README.md) |
| file-backup | Back up and recover personal files | restic → workstation-backup | helper:workstation-backup | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/recovery/README.md) |
| update-checkpoints | Inspect and maintain the workstation | blend → workstation-maintain | helper:workstation-maintain | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/recovery/README.md) |
| firmware-inspection | Inspect and maintain the workstation | fwupd → workstation-doctor | helper:workstation-doctor | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/recovery/README.md) |
| desktop-settings | Inspect and maintain the workstation | jq → workstation-controls | hypr:binding | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; [evidence](services/desktop/CHECKLIST.md) |
| directory-default | Open files with consistent defaults | nemo → nemo | xdg-default:nemo.desktop | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| image-viewer | Open files with consistent defaults | imv → imv | xdg-default:imv.desktop | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| document-viewer | Open files with consistent defaults | zathura → zathura | xdg-default:org.pwmt.zathura.desktop | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| pdf-backend | Open files with consistent defaults | zathura-pdf-mupdf → zathura | xdg-default:org.pwmt.zathura.desktop | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| media-player | Open files with consistent defaults | mpv → mpv | xdg-default:mpv.desktop | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| policy-agent | Authorize operations and share files or the desktop | hyprpolkitagent → /usr/lib/hyprpolkitagent/hyprpolkitagent | systemd-user:hyprpolkitagent.service | Installed | Component observed in VM; complete current workflow and explicit-profile deployment need verification; [evidence](services/desktop/CHECKLIST.md) |
| portal | Authorize operations and share files or the desktop | xdg-desktop-portal-hyprland → /usr/lib/xdg-desktop-portal-hyprland | dbus-user:xdg-desktop-portal-hyprland.service | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| network-applet | Configure networking and reach trusted remote machines | network-manager-applet → nm-applet | xdg-autostart:nm-applet.desktop | Installed | Component observed in VM; complete current workflow and explicit-profile deployment need verification; [evidence](services/desktop/CHECKLIST.md) |
| network-editor | Configure networking and reach trusted remote machines | network-manager-applet → workstation-controls | menu:workstation.toml | Installed | Component observed in VM; complete current workflow and explicit-profile deployment need verification; [evidence](services/desktop/CHECKLIST.md) |
| browser | Navigate the desktop and open applications | zen-browser-bin → zen-browser | xdg-default:zen.desktop | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| host-firewall | Configure networking and reach trusted remote machines | ufw → ufw | system-service:ufw | Planned | Source implementation present; installed workflow acceptance pending; [evidence](services/desktop/CHECKLIST.md) |
| remote-overlay-network | Configure networking and reach trusted remote machines | tailscale → tailscale | system-service:tailscaled | Installed | Component observed in VM; complete current workflow and explicit-profile deployment need verification; [evidence](services/desktop/CHECKLIST.md) |
| remote-desktop | Configure networking and reach trusted remote machines | rustdesk-unattended-wayland → rustdesk | system-service:rustdesk.service | Blocked | Known locked-connection capture failure; owner-deferred diagnosis; requires reviewed native package; **Compatibility Shim**: Native Arch packaging stages the upstream DRM variant without a RustDesk source fork; [evidence](services/rustdesk/README.md) |
| graphical-login | Sign in to the workstation | greetd → greetd | system-service:greetd.service | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; [evidence](services/desktop/CHECKLIST.md) |
| login-greeter | Sign in to the workstation | quickshell → /etc/blendos-workstation/identity/greeter-host | system-service:greetd.service | Planned | Current presentation/adapter source is present; earlier shell evidence does not accept this replacement; [evidence](services/desktop/CHECKLIST.md) |
| container-engine | Run local development services without Docker | podman → podman | rootless-user:podman.socket | Installed | Component observed in VM; complete current workflow and explicit-profile deployment need verification; [evidence](services/desktop/CHECKLIST.md) |
| compose-provider | Run local development services without Docker | podman-compose → podman-compose | podman:compose-provider | Installed | Component observed in VM; complete current workflow and explicit-profile deployment need verification; [evidence](services/desktop/CHECKLIST.md) |
| development-routes | Run local development services without Docker | mise → portless-compose | helper:portless-compose | Planned | Existing loopback .localhost workflow; complete provisioning was absent in the disposable VM receipt; **Compatibility Shim**: Pinned Portless 0.15.6 bind patch removes its privileged-port assumption; exact-source checks fail closed; [evidence](services/portless/README.md) |
| git-identities | Commit with the intended public or work identity | git → git-profile | helper:git-profile | Planned | Explicit identity profiles and directory mappings are Local State; configure personally; [evidence](README.md#git-identity-profiles) |
<!-- capabilities:vm:end -->

</details>

## History and recovery

`main` uses fresh sanitized history. The existing `quickshell-shell` branch is
retained for owner recovery and contains the complete original `main` history.
The repository remains private. That legacy branch retains personal metadata
and must be handled before a future public visibility change. Keep legacy
history separate from sanitized `main`; merging it back restores that metadata.

To inspect the old history in a separate checkout:

```sh
git clone --single-branch --branch quickshell-shell https://github.com/atila-almd/config.git "$HOME/workstation-legacy"
```

A verified pre-update mirror and complete Git bundle are also stored outside
the source tree under `%LOCALAPPDATA%\blendos-workstation\release-backups\`
on the preparation machine. The original development checkout and its
uncommitted work are preserved separately. The remote recovery branch and
bundle contain committed history; the original checkout also retains the
uncommitted work.

## Omarchy Reference and license

Omarchy is an [Omarchy Reference](CONTEXT.md) for desktop cohesion, selected
keybindings, appearance and workflows, not a feature list to reproduce. The
maintained project is [basecamp/omarchy](https://github.com/basecamp/omarchy).
Borrowed components and notices are recorded in
[desktop upstream provenance](services/desktop/UPSTREAM.md), including the
small attributed MIT audio-label helpers. Existing tools are composed through
upstream interfaces; project-owned compatibility adjustments are declared in
the Capability table and their service guides.

Project-owned work is licensed under [MIT](LICENSE). Retain upstream notices
and the original licenses of third-party components/assets. This is a personal
project; see [CONTRIBUTING.md](CONTRIBUTING.md) for scope and expectations.

## Verify the repository

Run these checks in a compatible Bash environment before installation:

`bash scripts/check-repository.sh` runs the complete list below, including any
new `validate-*.sh` and `test-*.sh` checks. It stops at the first failure and
prints its output. On Windows use WSL; this does not require the blendOS VM.
The data-service checks and home installer require Go 1.27 or newer; race tests
also need GCC and dbus-daemon. See the [backend guide](services/desktop/API.md).
The panel tests require Qt 6's `qmltestrunner`, Qt Quick Controls and QtTest.

```sh
bash -n bootstrap install.sh bin/* scripts/*.sh
bash scripts/validate-component-contract.sh
bash scripts/validate-capability-status.sh
bash scripts/test-bootstrap.sh
bash scripts/test-machine-profiles.sh
bash scripts/validate-user-session.sh
bash scripts/validate-shell-containers.sh
bash scripts/validate-security-baseline.sh
bash scripts/validate-desktop-shell.sh
bash scripts/validate-desktop-identity.sh
bash scripts/validate-workstation-controls.sh
bash scripts/check-workstation-shell.sh --source
bash scripts/validate-rustdesk.sh
bash scripts/test-component-contract.sh
bash scripts/test-session-terminal.sh
bash scripts/test-vm-rendering.sh
bash scripts/test-portless-compose.sh
bash scripts/test-portless-patch.sh
bash scripts/test-git-profile.sh
bash scripts/test-installer-rerun.sh
bash scripts/test-shell-containers.sh
bash scripts/test-source-fixture.sh
bash scripts/test-rustdesk-package.sh
bash scripts/test-theme-pipeline.sh
bash scripts/test-desktop-shell.sh
bash scripts/test-workstation-capture.sh
bash scripts/test-workstation-keybindings.sh
bash scripts/test-workstation-project.sh
bash scripts/test-workstation-controls.sh
bash scripts/test-workstation-control-center.sh
bash scripts/test-workstation-media.sh
bash scripts/test-workstation-record.sh
bash scripts/test-workstation-remind.sh
bash scripts/test-workstation-agent.sh
bash scripts/test-workstation-data.sh
bash scripts/test-workstation-shell.sh
bash scripts/test-desktop-identity.sh
bash scripts/test-workstation-doctor.sh
bash scripts/test-workstation-backup.sh
bash scripts/test-workstation-maintain.sh
bash scripts/validate-maintenance.sh
git diff --check
```

After rebuilding and installing inside blendOS, validate the live account:

```sh
bash scripts/validate-component-contract.sh --installed
bash scripts/validate-user-session.sh --installed
bash scripts/validate-desktop-shell.sh --installed
bash scripts/validate-desktop-identity.sh --installed
bash scripts/validate-shell-containers.sh --installed
bash scripts/validate-security-baseline.sh --installed
```

The installed checks require the blendOS user session and are not substitutes
for the repository-only checks.

## Current runtime

UWSM defines the Hyprland graphical-session boundary. The
`blendos-workstation-session.target` user target starts and stops Quickshell,
the lock guard, Hypridle, Dunst, Awww and wallpaper restoration, Walker,
Elephant, the launcher adapter, regular clipboard persistence, the `vm` profile’s VirtualBox
shared-clipboard client, and the policy agent with that session. Inspect the
live relationship with:

```sh
systemctl --user status blendos-workstation-session.target
systemctl --user list-dependencies blendos-workstation-session.target
```

The managed user units each have a distinct role:

| Unit | Why it is managed here |
| --- | --- |
| `blendos-workstation-session.target` | Gives graphical components one UWSM-bound lifecycle. |
| `workstation-shell.service` | Owns Island's per-output bar, activity state, cards and dashboard. |
| `workstation-data.service` | Supplies shared project, agent and desktop control observations. |
| `workstation-launcher.service` | Translates the Island launcher contract to the Elephant provider socket. |
| `workstation-lock.service` | Runs the independent Wayland session lock and PAM authentication. |
| `workstation-lock-guard.service` | Blocks sleep until compositor lock acknowledgement; preserves protection across restart. |
| `hypridle.service` | Requests idle locking and display power changes. |
| `awww-daemon.service` | Runs the wallpaper daemon for the declared wallpaper capability. |
| `wallpaper-restore.service` | Restores the selected validated wallpaper after Awww is ready. |
| `wl-clip-persist.service` | Keeps regular Wayland clipboard contents available after an application exits. |
| `vboxclient-clipboard.service` | Connects the VirtualBox host and Wayland clipboards while running in the VM. |
| `vboxclient-vmsvga.service` | Runs VirtualBox's VMSVGA session assistant while running in the VM. |
| `dunst.service.d/` | Attaches Dunst's package-provided unit to the graphical session. |
| `elephant.service` | Keeps the source-built provider/index family resident in the session. |
| `hyprpolkitagent.service.d/` | Attaches authentication dialogs to the graphical session. |
| `walker.service` | Keeps Walker's application service resident and ordered after Elephant. |
| `portless.service` | Runs the independent, login-scoped local development proxy. |

The package-service drop-ins do not duplicate package-provided services; they only add
session ownership, Wayland readiness, and graphical resource accounting.

The managed `vboxclient.desktop` autostart override disables upstream's aggregate
`VBoxClient-all` launcher. The two VirtualBox units provide clipboard and VMSVGA
support under the session target, preventing competing clipboard processes.
Both units are installed only by the explicitly selected `vm` profile.

Ghostty and Quickshell enable Mesa software rendering only with the selected `vm` profile through
`session-terminal`, `session-workstation-shell`, and `session-workstation-lock`. Walker starts through `session-walker`,
which selects GTK's Cairo renderer only with the selected `vm` profile. These client-scoped
fallbacks avoid the VM's unstable accelerated VMSVGA path without changing
rendering on physical machines.

The VirtualBox monitor profile selects 1920x1080 at scale 1 because its
synthetic display can report 640x480 as the preferred mode. Physical displays
continue to use their preferred mode and automatic scale.

Zen Browser is the XDG default browser. Helium is installed as the secondary
Chromium-based browser.

Zsh is the login shell. Mise provides development runtimes, Zoxide provides
directory navigation, and Starship owns the final interactive prompt. Podman is
the only container engine and is exposed through its rootless user socket.

Portless provides collision-free `.localhost` routes for native and Compose
projects. See the [Portless operator guide](./services/portless/README.md) for
commands, security constraints, and maintenance details.

## Desktop shell operations

The integrated desktop boundary is intentionally small and wired to the
current machine profile:

| Capability | Entry point | Session/config ownership |
| --- | --- | --- |
| Quickshell Island | top bar; workspaces, tray, cards, timer, projects and dashboard | `.config/quickshell/workstation/` and `workstation-shell.service` |
| Island launcher | 'Super+R', 'Super+Space' or the bar Apps/Search buttons | `workstation-shell.service` over `workstation-launcher.service` and `elephant.service` |
| Notifications | Dunst popups plus the lazy Island history/DND card | Dunst owns persistence; `workstation-data` adapts it while the card is open |
| Wallpapers | 'Super+Ctrl+Space' or 'workstation-wallpaper' | 'awww-daemon.service' plus 'wallpaper-restore.service' |
| Lock screen | 'Super+Ctrl+L' or Island Power | `session-lock`, independent Quickshell locker and lock guard |
| Graphical login | greetd on tty2; public Workstation identity screen | `greetd.service`, isolated pre-login Hyprland and `services/desktop/identity/` |
| Appearance | 'Super+Ctrl+Shift+Space' or 'workstation-theme' | semantic theme release in Local State |

### Keybindings and click actions

The main desktop bindings are:

| Binding | Action |
| --- | --- |
| 'Super+Q' | launch 'session-terminal' |
| 'Super+E' | open Nemo |
| 'Super+R' | open the Quickshell launcher over Elephant |
| `Super+Space` | open the Quickshell launcher (additional binding) |
| `Super+Alt+Space` | open the workstation utility menu |
| `Super+D` | open the Island dashboard |
| `Super+Shift+T` | open the Island timer card |
| `Super+K` | search the active Hyprland keyboard shortcuts |
| `Super+Escape` | open the Island Power card |
| `Super+Ctrl+C` | open the capture menu |
| `Super+Ctrl+V` | search clipboard history |
| `Super+Ctrl+E` | search symbols and emoji |
| `Super+Tab` | search and focus open windows |
| `Super+B` | launch Zen Browser |
| `Print` / `Shift+Print` / `Ctrl+Print` | capture a region / window / output |
| `Alt+Print` | copy a region capture without saving a file |
| `Super+Print` | pick and copy a color |
| 'Super+Ctrl+L' | lock through 'session-lock' |
| 'Super+N' | open the Island notification history card |
| 'Super+Shift+N' | close all notifications |
| 'Super+Ctrl+N' | toggle Dunst pause |
| 'Super+Ctrl+Space' | select the next theme wallpaper |
| 'Super+Ctrl+Shift+Space' | choose a desktop theme |

The Island bar has these actions:

| Surface | Action |
| --- | --- |
| Apps / Search | Quickshell launcher over Elephant |
| Workspace | Activate the backend workspace on that output |
| Tray icon | Native activation; right click/Menu key opens its menu; middle click and scrolling forward native actions |
| Projects | Open the project and agent card; closing it leaves the bar running |
| Terminal | `session-terminal`; narrow bars retain the keyboard/menu entry |
| Lock | `session-lock` |
| Tools | Open the workstation utility menu; Island dashboard/cards open from the center and surviving widget icons |

Island cards use the same glass material and shared motion tokens. The
[Island guide](services/desktop/ISLAND.md) owns card commands, live
configuration and the capability skip list. The [desktop checklist](services/desktop/CHECKLIST.md)
continues to own installed/lifecycle evidence and hardware limits.

### Walker and notification controls

The workstation utility menu groups appearance, notifications, audio, wired
networking, capture, tools, and power actions. It uses the existing Elephant
menus and Walker theme. Terminal tools (Btop, Yazi, and Neovim) use
`session-terminal`, including its VM fallback. The shortcut reference reads
the running compositor's bindings; selecting a row does not execute it.

### Captures and opening files

`workstation-capture region`, `window`, and `output` save screenshots under
the XDG Pictures directory's `Screenshots` subdirectory (falling back to
`~/Pictures/Screenshots` when no Pictures directory is configured).
`workstation-capture clipboard` copies a region without saving;
`workstation-capture color` copies a picked color. Escape cancels selection.
Capture and clipboard history use the existing Wayland tools and session
backend; they add no background daemon.

Nemo is the default directory handler. PNG, JPEG, GIF, WebP, and SVG files open
in Imv; PDFs open in Zathura with its MuPDF backend; common video and audio
files open in mpv. Open files from Nemo or the Island launcher's `/` file
search. These
applications run on demand and exit independently of the desktop daemons.
Their package-provided controls and appearance defaults are retained.
Browser URL associations remain with Zen.

After deploying this change, the new viewers require a blendOS rebuild and
reboot before use; then run `bash install.sh` from a TTY with the graphical
session logged out. After logging into Workstation, check
effective associations with `xdg-mime query default application/pdf` or the
installed component validator. Test one screenshot, its image viewer, a PDF,
and an audio/video file in the VM. Repository checks do not establish visual
acceptance or VirtualBox rendering compatibility for the new viewers.

### Walker utility providers

Walker remains the presentation for utility selection. The Island launcher
owns application, file, calculator and web-search rows; Walker's explicit
prefixes below cover the remaining provider jobs and utility menus. An empty
Walker query is not an application-launcher entry point.

| Prefix | Provider |
| --- | --- |
| ';' | provider list |
| '>' | command runner |
| '.' | symbols |
| ':' | clipboard |
| '$' | windows |

The command runner is not in the default provider set. Walker has a 50-result
global cap and does not expose password-vault or package-install actions.

Dunst keeps history and progress notifications enabled. `Super+N` opens the
lazy Island history card over the existing `workstation-data` Dunst adapter;
its Pause/Resume, Clear history, Show and Dismiss actions use the validated
`workstation-controls` boundary. `Super+Shift+N` closes live popups and
`Super+Ctrl+N` toggles Dunst pause. Notification actions remain attached to
live notifications; closed history rows deliberately expose no action labels.
The existing Island attention surface also presents native volume and
microphone volume/mute feedback.

### Themes and wallpapers

The bundled theme is Catppuccin Mocha. Theme definitions are manifests under
'themes/<theme-id>/'; a user definition at
'$XDG_CONFIG_HOME/blendos-workstation/themes/<theme-id>/' overrides a built-in
definition with the same ID.

The same release supplies Island's bar, cards and dashboard plus the independent
locker through `workstation-shell.json`. The [desktop guide](services/desktop/README.md) owns
their reload and lock constraints.

Validate a new definition before selecting it:

~~~sh
workstation-theme list
workstation-theme validate --all
workstation-theme set catppuccin-mocha
workstation-theme current
workstation-theme choose
workstation-theme reload
~~~

Add a theme by creating only its manifest and compatible, licensed wallpaper
files. Keep the manifest ID equal to its directory name, use the semantic
color roles and 16-entry terminal palette, and use relative wallpaper paths
that remain inside the theme directory. The shared templates are the
appearance contract; a new theme should not copy a complete component config
tree.

Theme activation renders every consumer into a private release under
'$XDG_STATE_HOME/blendos-workstation/theme/' (falling back to
'~/.local/state/blendos-workstation/theme/'). The 'current' symlink changes
only after the whole release validates. 'previous' and the newest releases
are retained. Active services reload in a fixed order; a failed active reload
restores the previous release and retries the old configuration. GTK settings
are updated through GSettings when the relevant schemas are writable.

The stable Walker, Dunst, Ghostty, and GTK paths are installer-created
symlinks into the active release. Hyprland loads its generated border/shadow
table with a guarded fallback. Awww reads only wallpapers from the validated
active manifest:

~~~sh
workstation-wallpaper list
workstation-wallpaper current
workstation-wallpaper restore
workstation-wallpaper next
workstation-wallpaper previous
workstation-wallpaper choose
workstation-wallpaper set INDEX
~~~

Wallpaper indexes and rendered alternate wallpaper images are also Local
State. Awww readiness is retried for at most five seconds, and a failed
transition leaves the previous index selected.

When Ghostty is running under its official user service, the theme reload
signals that service. Standalone Ghostty windows may need
'Ctrl+Shift+,'; new windows read the active generated palette.

### Installation migration and troubleshooting

The installer manages individual files inside Hyprland and Ghostty
directories. An old directory symlink is removed only when it points to this
repository. An unrelated directory, file, or symlink is moved to the normal
timestamped backup path before managed files are installed, and unowned files
inside a preserved directory remain in place.

Useful checks after an install or theme change:

~~~sh
systemctl --user status blendos-workstation-session.target workstation-shell.service \
  workstation-launcher.service \
  dunst.service awww-daemon.service wallpaper-restore.service \
  elephant.service walker.service
systemctl --user list-dependencies blendos-workstation-session.target
journalctl --user -b -u workstation-shell.service -u dunst.service \
  -u awww-daemon.service -u wallpaper-restore.service \
  -u elephant.service -u workstation-launcher.service -u walker.service --no-pager
elephant listproviders
awww query
workstation-theme current
workstation-wallpaper current
~~~

If the Island launcher is slow or empty, check that
`workstation-launcher.service` and Elephant are active and that all source-built
Elephant provider packages report one identical upstream version. Walker's
utility jobs use the same Elephant provider family.
If a theme does not apply, inspect 'workstation-theme current', the
'current'/'previous' release pointers, and the user-service journal before
restarting the desktop target. Do not edit generated release files in place.
Locker failure keeps the compositor's protected surface. Use the recovery
procedure in the [desktop guide](services/desktop/README.md); never treat a
running lock process as proof that sleep is safe.

## Git identity profiles

The tracked `.gitconfig` contains only neutral defaults. Names, email addresses,
and directory mappings live outside the repository under:

```text
~/.local/state/blendos-workstation/git/
```

Create a profile and map it to an area containing repositories:

```sh
git-profile add personal "Your Name" personal@example.com
git-profile map personal "$HOME/Projects/personal"

git-profile add work "Your Work Name" you@example.org
git-profile map work "$HOME/Projects/work"
```

The mapping applies to every Git repository below that directory. Inspect the
configured profiles and the identity resolved inside a repository with:

```sh
git-profile list
git-profile show "$HOME/Projects/work/example-repository"
```

Remove a directory mapping before deleting its profile:

```sh
git-profile unmap "$HOME/Projects/work"
git-profile delete work
```

Without a matching profile, Git intentionally has no managed fallback identity;
this prevents a personal identity from being used silently in a work tree.

## Security baseline

UFW is the host firewall. `install.sh` applies these baseline policies after a
system-enabled installation:

- deny unsolicited incoming traffic;
- allow outgoing traffic;
- deny routed traffic;
- allow incoming traffic on `tailscale0` for authenticated tailnet peers.

RustDesk uses its outbound relay path, so no public inbound exception is
opened. Portless remains HTTP-only on loopback. The baseline does not reset
additional operator-created UFW rules; inspect all effective rules after
installation with:

```sh
sudo ufw status verbose
```

Full-disk encryption is an installation-time decision rather than something
this repository can safely retrofit. The installed validator reports whether
encrypted root storage is detectable; treat an unencrypted bare-metal result as
a security exception requiring an explicit decision. Development VMs may use a
documented exception.

Run the installed security validator to check the service and policy and to
print listening sockets for review:

```sh
bash scripts/validate-security-baseline.sh --installed
```

## Private state

Machine-specific, generated, personal, or secret data is Local State and does
not belong in this repository. Keep it outside the working tree.

This includes the Git identity profiles created by `git-profile`, firewall
exceptions beyond the managed baseline, browser profiles, and service
credentials.
