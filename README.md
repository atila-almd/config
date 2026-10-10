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
| blendOS packages and services | `system.yaml` |
| Desktop Component Contract | `components.tsv` |
| Hyprland behavior and keybindings | `.config/hypr/hyprland.lua` |
| Ghostty terminal preferences | `.config/ghostty/config.ghostty` |
| Graphical and background user services | `.config/systemd/user/` |
| Default application associations | `.config/mimeapps.list` |
| Shell and development environment | `.zshenv`, `.zprofile`, `.zshrc`, `.config/mise/`, `.config/uwsm/`, `.gitconfig` |
| Project-owned command wrappers | `bin/` |
| Validation and compatibility scripts | `scripts/` |
| Service-specific assets and documentation | `services/` |
| Deployment into an account and system | `install.sh` |

The installer manages individual paths. It does not replace the target home
directory.

## Install from the shared development tree

The Windows project directory is registered in VirtualBox as the `omarchy`
shared folder. In the blendOS guest:

```sh
mkdir -p "$HOME/omarchy"
sudo mount -t vboxsf -o "uid=$(id -u),gid=$(id -g)" omarchy "$HOME/omarchy"
cd "$HOME/omarchy"
bash install.sh
```

The same working tree is visible at:

```text
Windows: C:\path\to\workstation
blendOS: /home/<user>/workstation
```

Edits are shared immediately, but installation and live-system verification
must run inside blendOS.

## Install from a clone

On a real blendOS machine:

```sh
git clone <repository-url> "$HOME/omarchy"
cd "$HOME/omarchy"
bash install.sh
```

By default, the installer manages both the home environment and `/system.yaml`.
Use home-only mode when the System Definition must remain untouched:

```sh
bash install.sh --home-only
```

Home-only mode also preserves `~/system.yaml`, since `/system.yaml` may resolve
through it. Rerunning installation reloads unit definitions but does not restart
desktop services; apply desktop lifecycle changes at the next deliberate login.

For a fresh system missing required packages, first run `bash install.sh
--system-only`. Before rebuilding, [publish the selected RustDesk package and
start its local package server](services/rustdesk/README.md#build-and-publish)
in the blendOS account. Keep that server running throughout every
`sudo akshara update`, including later rebuilds, then deliberately reboot.
Run the full installer from a TTY after logging out; it rejects an active graphical
session before home changes. System-only mode stages the system definition and
defers account/firewall wiring until the full installation after the rebuild.

The full installation also publishes the public Workstation identity bundle
to `/etc/blendos-workstation/identity` and enables greetd after that
bundle is present. The rebuild-time greetd condition deliberately leaves a
fresh image on a TTY until this step completes; it never selects a fallback
greeter. If the first boot has no login screen, use another TTY, log in, and
rerun `bash install.sh` before starting a graphical session.

Home-only mode still configures the account's login shell, Mise tools, Portless
user service, and rootless Podman socket because those belong to the user
environment.

For an already-provisioned account that only needs updated managed files and
units, use `bash install.sh --config-only` after logging out. It preserves backups
and skips runtime/account/system provisioning; no sudo is needed. See the
[desktop lifecycle guide](services/desktop/README.md#installation-and-lifecycle).

The installer records Zsh's canonical path as the login shell and fails closed
if that path is absent from `/etc/shells`; rebuild first so the System
Definition refreshes the shell allowlist. A full install also removes a
leftover `gnome-initial-setup` account, but does not recursively delete a home
directory for that transient account.

Existing managed destinations are moved into timestamped backups under:

```text
~/.local/state/blendos-workstation/backups/
```

`blendos-workstation` is only the neutral state namespace used by the
installer. Each timestamped directory contains files that were displaced by
that installation; it is not another desktop environment or a service.

Ordinary managed paths are symlinked to the repository. User systemd units are
copied with mode `0644` because VirtualBox shared-folder permission masks are
not suitable for unit files; run `install.sh` again after editing a unit.
UWSM loads `.config/uwsm/env` before the graphical session so the project-owned
helpers are available to Hyprland bindings and desktop services.

Git identities are deliberately not managed in the repository. The installer
creates their Local State directory and exposes the `git-profile` helper; see
[Git identity profiles](#git-identity-profiles).

The default System Definition chain is:

```text
/system.yaml -> ~/system.yaml -> ~/omarchy/system.yaml
```

Inspect the resolved source with:

```sh
readlink -f /system.yaml
```

## Verify the repository

Run these checks in a compatible Bash environment before installation:

`bash scripts/check-repository.sh` runs the complete list below, including any
new `validate-*.sh` and `test-*.sh` checks. It stops at the first failure and
prints its output. On Windows use WSL; this does not require the blendOS VM.
The data-service checks and home installer require Go 1.27 or newer; race tests
also need GCC and dbus-daemon. See the [backend guide](services/desktop/API.md).
The panel tests require Qt 6's `qmltestrunner`, Qt Quick Controls and QtTest.

```sh
bash -n install.sh bin/* scripts/*.sh
bash scripts/validate-component-contract.sh
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
Elephant, the launcher adapter, regular clipboard persistence, the VirtualBox
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
Both units are restricted to VirtualBox guests.

Ghostty and Quickshell enable Mesa software rendering only in VirtualBox through
`session-terminal`, `session-workstation-shell`, and `session-workstation-lock`. Walker starts through `session-walker`,
which selects GTK's Cairo renderer only in VirtualBox. These client-scoped
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
