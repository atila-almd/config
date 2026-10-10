# Agent Guide

This repository builds a personal, highly integrated blendOS workstation with
an Omarchy-like level of cohesion. It is not an Omarchy installation, an
Omarchy package mirror, or a commitment to reproduce Omarchy feature for
feature.

Read [CONTEXT.md](./CONTEXT.md) before changing project terminology.

## Documentation ownership

- `CONTEXT.md` defines project-specific terms and contains no implementation,
  operational, or planning detail.
- `AGENTS.md` owns product principles, architecture boundaries, source
  ownership, and contributor workflow.
- `README.md` owns installation, verification, and operator-facing summaries
  of current behavior.
- A service README owns commands, constraints, and troubleshooting unique to
  that service.

Update the owning document and link to it from other documents. Do not maintain
parallel copies of the same instructions.

## Mission

Build a feature-complete workstation around the owner's actual workflows. The
system should feel deliberately assembled: applications, keybindings, session
services, defaults, themes, and development workflows should cooperate as one
environment instead of behaving like unrelated packages.

The repository is currently a custom blendOS environment rather than a
standalone Linux distribution. Do not describe it as a blendOS fork unless the
repository later acquires the image-building, release, and update machinery
that makes that true.

## Product principles

Apply these priorities in order:

1. Solve a workflow the owner actually needs. Do not copy an Omarchy feature
   merely because Omarchy ships it.
2. Prefer well-integrated behavior over a long application list. A capability
   is incomplete until installation, launch, lifecycle, defaults, and failure
   behavior fit the rest of the system.
3. Prefer customizable, actively maintained FOSS tools with documented,
   scriptable interfaces and no dependency on a single distro's private
   conventions.
4. Prefer configuration or composition of upstream tools over maintaining a
   fork.
5. Fork an Omarchy tool only when it is small enough to understand, test, and
   maintain here, and a concrete required change cannot reasonably be made
   upstream or through configuration.
6. A large Omarchy tool may be used unchanged when replacing it would cost more
   than the coupling it introduces. Record the reason and isolate its
   assumptions behind a wrapper or contract where practical.
7. Minimize one-off code. Small project-owned helpers are appropriate when
   they close a real integration gap and have focused tests.

When comparing components, consider license, configurability, interoperability,
accessibility, upstream health, release/package availability, resource use,
Wayland support, and ongoing maintenance cost. "FOSS" alone does not make a
component a good fit.

## What integrated means

An integrated capability normally has all applicable parts below:

- its package and executable are declared;
- it starts and stops with the correct system or graphical-session lifecycle;
- it is reachable through the expected keybinding, launcher, default
  association, status surface, or command;
- its environment, portal, permissions, notifications, and file associations
  agree with the rest of the desktop;
- its styling and interaction conventions are coherent with the environment;
- installation is repeatable on the supported machine profile;
- important cross-file assumptions are represented by a validation script or
  focused test;
- user-facing behavior and unusual maintenance constraints are documented.

Adding a package to `system.yaml` is therefore not sufficient to add a desktop
feature.

## Sources of truth

- `system.yaml` declares common blendOS packages/services and rebuild commands;
  `profiles/<name>.yaml` adds approved hardware packages/services. `bootstrap`
  composes the active System Definition into external machine Local State.
- `components.tsv` maps each desktop capability to its package, executable, and
  integration point. It also owns workflow/profile scope, acceptance status,
  evidence and adaptation justification; its generated README tables must stay
  synchronized. It is the component contract, not a general package list.
- `.config/hypr/hyprland.lua` owns compositor behavior, input, interaction, and
  desktop keybindings.
- `.config/systemd/user/` owns session-bound and independent user-service
  lifecycles. Graphical components belong to
  `blendos-workstation-session.target` when they must share the Hyprland session.
- `.config/mimeapps.list` owns XDG default application associations.
- `install.sh` deploys managed home paths and performs the small amount of
  account/system wiring that blendOS does not express directly.
- `bin/` contains project-owned integration helpers; `scripts/` contains tests,
  validators, and narrowly scoped maintenance operations.
- `services/` documents and templates service-specific workflows.
- `README.md` is the operator guide. Keep it aligned with behavior, but do not
  duplicate every implementation detail in it.

Before introducing another manifest or source of truth, extend one of these if
the concept already has an owner.

## Current architecture and invariants

### Authorized shell replacement

Plans 005–010 in [docs/plans/README.md](docs/plans/README.md) now own the
Quickshell implementation. The owner explicitly rejects old-shell compatibility,
fallback sessions and migration paths. Plan 006 removes the Noctalia and Waybar
session owners from managed source. Delete each
replaced component and its unused integration in the delivering plan, updating
this section and the validators together. Tool and component reuse choices are
made by the owner at execution time; stop with concrete options at each choice.

The new UI consumes stable structured JSON contracts from backend adapters;
backends remain authoritative. Subscribe to available events. Unavoidable
polling has one shared scheduler and no widget-owned timers. Expensive panels
load on first open and suspend or unload hidden work. Small components take
explicit inputs and emit intents; borrowed code must meet the same boundaries.
Semantic palettes still come from the existing theme renderer. No shell
benchmarking or measurement gate is part of this work.

### Current implementation

- The Quickshell shell starts with `blendos-workstation-session.target`, owns
  the per-output Island bar and tray, and morphs its single surface between
  compact/activity/attention/split/expanded/dashboard/launcher states.
  `workstation-shell.service` requires the shared `workstation-data.service`;
  the launcher surface observes `workstation-launcher.service` only while it
  is open.
  Expanded card content is loaded only on the active cursor output; collapsing
  it returns the same surface to the bar. Views consume the contracts in
  `services/desktop/API.md`; semantic palettes come from
  `workstation-shell.json` in the existing atomic theme release.
- blendOS provides the immutable/declarative system base; Hyprland is the
  Wayland compositor.
- UWSM supplies the graphical-session boundary. Desktop daemons are managed by
  systemd user units rather than compositor `exec-once` entries.
- `workstation.desktop` is the sole managed UWSM session. Retain `Exec=Hyprland`
  for UWSM's compositor plugin. No old-shell selector or fallback target remains.
- `blendos-workstation-session.target` owns Quickshell, the lock guard,
  Hypridle, Dunst, Awww and wallpaper restoration, Walker, Elephant, the
  launcher adapter, clipboard persistence, and the policy agent. Do not add a second
  compositor-owned launch path for one of these services.
- `greetd.service` is the sole graphical-login owner. Its dedicated `greeter`
  account runs the project-owned pre-login host from the system-readable
  identity bundle; that host uses an isolated Hyprland configuration and the
  native Quickshell Greetd adapter. It hands off only through UWSM to the sole
  `workstation.desktop` entry, then exits with its compositor. Login never
  reads private home/theme state and never uses the locker's `PamContext`.
- Dunst remains the sole `org.freedesktop.Notifications` owner. Plan 009
  Option 1 extends the existing `workstation-data` service with a lazy,
  bounded history/DND adapter and uses the Island attention surface for
  volume/microphone OSD feedback; it adds no notification daemon, OSD package,
  QML D-Bus owner, or donor shell. Dunst still owns live popup actions and
  persistence; the Island card owns only the sanitized history presentation
  and validated mutation intents.
- Ghostty is the terminal. Always launch it through `session-terminal`, which
  contains the VirtualBox-only software-rendering fallback.
- VirtualBox rendering fallbacks stay client-scoped: `session-workstation-shell`
  and `session-workstation-lock` select Mesa software rendering; `session-walker` selects GTK's Cairo
  renderer for Walker, and `workstation-controls audio-mixer` selects Cairo for the
  audio mixer. Do not export those renderer overrides session-wide or
  apply them to physical machines.
- `workstation-lock.service` runs a separate Quickshell Wayland session lock.
  PAM authenticates through `workstation-lock`; authentication success alone
  cannot unlock until the sleep guard has reacquired its block inhibitor.
  The guard independently observes compositor lock acknowledgement. A process
  ID or frontend status string never authorizes sleep. Shared authentication
  presentation is reusable; it does not implement login/session creation.
- Only an explicitly selected `vm` Machine Profile installs guest units and
  enables client render overrides; runtime selection uses the public
  `/etc/blendos-workstation/machine-profile` marker, never DMI detection.
- The VirtualBox monitor profile uses 1920x1080 at scale 1 because its synthetic
  display reports 640x480 as preferred. Physical displays retain preferred mode
  and automatic scale; keep any future guest override equally profile-scoped.
- Podman is the only container engine. It is rootless and socket-activated.
  Do not silently add Docker compatibility packages or shell aliases.
- Portless provides loopback-only `.localhost` development routes on port 80.
  Its pinned compatibility patch is narrow, tested, and expected to fail closed
  if the upstream source changes.
- UFW is the host firewall. The managed baseline denies incoming and routed
  traffic, allows outgoing traffic, and permits authenticated tailnet ingress
  on `tailscale0`. RustDesk receives no public inbound exception.
- Git identity values and directory mappings are Local State managed through
  `git-profile`; they must never be committed as Managed Configuration.
- Project registrations and agent run records are Local State. Agent commands
  are explicit argv and run in session-bound systemd scopes; records contain
  measured process/resource facts, never prompts, argv, credentials or inferred
  provider quotas. Project instruction files are initialized only on request.
- Restic backup destinations, source selections, credentials and operation
  records are Local State. The backup timer is independent of the desktop and
  disabled until explicitly configured and enabled. File checkpoints do not
  represent bootable OS generations; Akshara remains the system builder.
- Zsh startup order is intentional: login-wide paths/environment, Mise shims,
  then interactive Mise, Zoxide, and Starship initialization.
- The repository is the source of managed configuration. `install.sh` links
  ordinary config paths but copies systemd units because VirtualBox shared
  folders expose unsuitable permission masks.
- Existing destination files are backed up under
  `~/.local/state/blendos-workstation/backups/`; do not weaken that behavior.
- Machine-specific or secret state belongs outside the working tree, never in
  managed configuration.
- Desktop appearance is a semantic contract. Theme manifests under `themes/`
  provide the palette and functional templates consume only the allowlisted
  theme variables; component geometry and behavior remain in their base
  configurations.
- The shell and independent locker consume the semantic release through native
  theme IPC. Awww is the wallpaper owner until its delivering replacement plan.
  A missing locker theme must not prevent acquiring the compositor lock.
- Theme activation is Local State under
  `${XDG_STATE_HOME:-$HOME/.local/state}/blendos-workstation/theme/`. Releases
  are rendered completely in private staging and switched through the atomic
  `current` pointer. Generated releases, selected themes, wallpaper indexes,
  and rendered assets must never be committed to the repository.
- Elephant and its selected providers are source-built as one package family.
  Core and provider packages must use one upstream version and be checked for
  provider-load/Go-plugin ABI compatibility after upgrades; do not mix in
  `elephant-*-bin` plugins.

These are current architectural facts, not a ban on future change. Change an
invariant deliberately and update its validators and documentation in the same
work.

## Supported targets

Installation paths and the shared Windows/blendOS workflow are documented in
`README.md`. Do not assume PowerShell paths or Windows file semantics apply in
the guest.

The active Machine Profile is currently an AMD CPU, NVIDIA RTX 4060, wired
Ethernet desktop (Ryzen 7 5800X, RTX 4060, Realtek RTL8125) on a secondary SSD.
The separate explicit `vm` profile owns VirtualBox guest support. Neither profile
is selected by hardware detection. Keep
optional hardware capabilities visibly separated; do not enable them without a
real target machine or an explicit request.

## Change workflow for agents

1. Inspect `README.md`, `system.yaml`, `components.tsv`, and the files that own
   the affected integration before proposing or implementing a change.
2. State the user workflow being enabled. Reject speculative package additions
   that have no intended entry point or lifecycle.
3. For a component change, trace the whole chain:
   package -> executable -> service/default/binding -> installer -> validation
   -> operator documentation.
4. Reuse upstream configuration and stable interfaces first. If proposing a
   fork or a large Omarchy-specific dependency, document the missing
   capability, alternatives considered, update strategy, and exit cost.
5. Preserve unrelated local edits and private state. This repository may be
   edited concurrently from Windows and the guest.
6. Use the verification commands in `README.md`. Run the narrowest relevant
   check first, then all repository contract checks when possible.
7. Run installed-system checks only inside the rebuilt blendOS account. Report
   clearly when Windows or an unavailable guest prevented them.

## Known incomplete areas

Do not mistake repository validation for installed or visual acceptance. The
managed source now contains the Quickshell shell/locker, Hypridle, Walker,
Dunst, Awww, launcher adapter, and semantic theme contracts. Plan 006 is
complete for the supported VM, including native workspace focus, urgency and
activation. The
[desktop checklist](services/desktop/CHECKLIST.md) owns guest lock/sleep and
lifecycle evidence, later utility/portal checks and unaccepted physical
limits. RustDesk follows the owner's
[deferred sequencing](docs/plans/README.md#owner-directed-rustdesk-sequencing-2026-09-12).
Earlier Noctalia evidence does not establish acceptance of its replacements.
Plan 007 supplies the control-center implementation under the selected native
event/helper boundaries. Its remaining acceptance is unverified under the
[owner-directed verification stop](docs/plans/README.md#owner-directed-plan-007-verification-stop-2026-09-12);
the checkpoint does not establish full plan acceptance.
Plan 008's Quickshell-over-Elephant source implementation is present; its
installed launcher/literal-activation and visual checks remain a guest
acceptance item. AI answers are intentionally outside the plan until the owner
selects a provider and credential/lifecycle contract.
Plan 009 has an owner-selected Option 1 implementation checkpoint: Dunst
remains the notification owner, the existing `workstation-data` service is the
structured-data adapter, and the existing Island attention surface is the OSD
presentation. The source implementation and focused fixtures are present;
installed/restart and visual guest acceptance remain incomplete.
Plan 010 now has a source implementation checkpoint: greetd replaces Ly, the
isolated Quickshell greeter and public identity bundle are present, and the
shared authentication presentation is used by both login and lock. Native
Quickshell lint/render plus installed login, keyring, portal, TTY, logout and
visual acceptance remain unverified until a rebuilt blendOS guest is available;
the source checkpoint is not a completion claim.

Broader workflows such as idle behavior, display profiles, secrets, backups,
updates, recovery, and application-specific setup should be added only as the
owner's requirements become concrete.

Treat this list as orientation, not an automatic backlog. The owner decides
which workflows belong in the system.
