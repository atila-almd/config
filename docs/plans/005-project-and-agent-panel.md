# Plan 005: Open projects and inspect agent runs in Quickshell

Status: DONE — source, native render, rebuilt installation and installed launch
acceptance passed. Dependencies: existing project/agent backends at `6f88261`.
Bounded outcome: one useful window, not a desktop replacement.

## Scope

Standalone themed project/agent window: select a registered project, open its
terminal/editor, inspect measured runs, and launch explicitly entered argv through
the existing project/agent owners. Fixture preview and live mode share components.
Out: registration editing, presets, provider integrations/quotas, bar, launcher
replacement, device panels, session cutover, login and benchmarks. No desktop
owner is replaced here and no fallback window implementation is added.

Baseline grounding: project reads emitted TSV and created state; agent status
mixed properties, record JSON and text. Those read semantics are now replaced
with versioned JSON in the owning helpers. QML must consume their public contract.

## Decision points

1. Resolved: owner selected Unix socket + JSON lines, with one session-bound
   adapter shared by all consumers. See the execution record.
2. Resolved: owner selected Go with fsnotify, direct godbus/v5 and standard
   go test. No additional backend test framework is introduced.
3. Resolved: owner selected project-owned composition with Qt Quick Controls,
   reiterating theme support. The donor review is in services/desktop/UPSTREAM.md.
4. Resolved: owner selected Qt Quick Test. Native Qt 6.11.2 component tests and
   presentation lint pass in blendOS; full Quickshell render checks follow.

## Interfaces

The implemented v1 JSON/socket schemas, limits, lifecycle and sampling contract
are owned by [API.md](../../services/desktop/API.md). Implemented UI interfaces:

- `Projects`/`AgentStatus` QML take explicit model/palette inputs and emit
  `openProject(id, mode)` and `launchAgent(id, argv)` intents. The controller
  owns asynchronous commands; empty argv is rejected, never shell-evaluated.
- Managed UI: `.config/quickshell/workstation/`. Palette:
  `${XDG_STATE_HOME:-$HOME/.local/state}/blendos-workstation/theme/current/workstation-shell.json`.
  Geometry stays in managed defaults; generated/private state stays out of QML.

Change old CLI consumers/tests together rather than retaining TSV/mixed-output
compatibility modes. Exact command signatures follow the API contract. Never expose
prompts, argv, credentials, raw logs or internal record-file paths in status.

## Deliverables

- `.config/quickshell/workstation/shell.qml`, `surfaces/Projects.qml`,
  `surfaces/AgentStatus.qml`, needed small `components/`, `models/`, `adapters/`.
- `bin/session-workstation-shell` with preview/live-window entry; updated
  project/agent helpers and callers. Chosen transport implementation under
  `bin/` or UI adapters, not a second registry/recorder.
- `themes/templates/workstation-shell.json.tpl`, renderer validation, native
  package/component declarations and managed-home installer entries.
- `scripts/check-workstation-shell.sh`, `scripts/test-workstation-shell.sh`,
  `scripts/fixtures/workstation-shell/`, project/agent/theme test updates.
- `services/desktop/API.md`, `services/desktop/UPSTREAM.md` for actual donor
  decisions, desktop/development guide updates with runnable commands.

## Checks

Run project/agent tests before edits, then update them for JSON and real callers.
Test empty/many rows, malformed/unsupported schema, missing project directory,
stale scope, failed process, partial metrics, literal metacharacters, read-only
snapshots, reconnect, atomic-write bursts and cancellation. Two consumers must
share one metric scheduler; closing the last observer stops sampling.

Run theme/installer tests and the full repository suite. The shell checker
separates fixture, actual QML lint/type and boot/render modes. Render mode uses
a bounded disposable graphical context, captures and inspects pixels, checks
runtime errors and cleans up its process; a PID/ready log is not render proof.
Test keyboard navigation, Escape, 200% text and empty/error layouts. In blendOS
open real project terminals and launch explicit argv. Screenshots/real records
stay private. Missing tooling leaves its check pending, never silently passed.

## Done criteria

- Fixture and live window render and launch projects/agents through their owners.
- JSON/event contracts and one scheduler are documented and behaviorally tested.
- Theme changes reach the window; source, QML and blendOS render checks pass.
- Installer deploys sources without generated writes into the repository.
- Decisions, launch command and evidence documented; one completion commit.

## Assumptions

- Workstation is the provisional name; use current semantic theme/font.
- Existing registrations remain backend input, not a migration task. New runs
  may record project IDs; unresolved IDs are null, never guessed.
- Agent resource facts are a requested workflow, not shell benchmarking.
- The socket uses the existing workstation namespace under XDG_RUNTIME_DIR;
  it is transient communication state, not persistent workflow storage.
- Reconnecting clients receive a current snapshot rather than an event replay
  log. Slow-client queues are bounded; disconnect/resync replaces unlimited
  buffering. No event-history persistence is introduced for the transport.
- Build the Go executable during home installation, with the declared native Go
  compiler and pinned modules; place generated output in managed home libexec.
- Before session replacement, the data unit is demand-started and bound to the
  existing UWSM graphical-session target. Plan 006 supplies the sole shell owner.
- Resource counters use one two-second interval while observed. Directory
  availability refreshes with project snapshots; project contents are not watched.

## Execution record

Started 2026-09-09 after plan-set commit `687f97f`, on `quickshell-shell`.
The owner selected Unix socket/JSON lines, Go with fsnotify and godbus/v5,
standard Go tests, own Qt Quick Controls composition, and Qt Quick Test.
Concrete donor/licensing decisions are recorded in
[UPSTREAM.md](../../services/desktop/UPSTREAM.md). No donor QML was copied.

Implemented helper JSON reads, the shared event adapter and observed-metric
scheduler, demand-started units, managed-home build/deployment, semantic palette
output, the standalone project/agent window and fixture/live check commands.
The window uses explicit argv through the project helper's `dispatch` entry;
terminals belong to transient graphical-session services and outlive the panel.
View selection is temporary; the persisted CLI selection supplies its initial ID.
Hidden/minimized views unload and disconnect. IPC arguments use `call --` because
Quickshell otherwise interprets the method name `show` as its inspection command.

Checks performed:

- All 35 repository checks passed in an isolated public-source WSL copy, including
  Go race tests, vet, real socket/inotify/D-Bus fixtures, CLI/helper smoke tests,
  installer rerun/backups, theme rollback and Qt Quick Test.
- Qt Quick Test passed on blendOS Qt 6.11.2 (eight results including setup/cleanup),
  covering input, intents, invalid/literal argv, empty/error/many rows, theme
  propagation and 200% text in wide/narrow layouts.
- Full QML lint passed with zero warnings after two local annotations for enum
  types omitted from Quickshell 0.3.1's native metadata. Native socket failure
  and reconnect are exercised; installed launches also exercised process completion.
- Quickshell 0.3.1 and Go 1.27.0 Arch packages were signature-verified against the
  guest's Arch keyring and extracted into private validation cache. Dependencies
  were likewise verified. No system package database was changed by the agent.
- In the actual Hyprland session, the real data adapter and owning helper reads
  passed private-state live checks: empty reads, pushed registration/removal,
  hide/show, backend restart/reconnect and atomic private-theme reload.
- A bounded Quickshell fixture rendered at 931x494 in the guest's tiled window.
  Dark and private light palette switches reached checked pixels; both screenshots
  were visually inspected. Placeholder contrast was corrected. Reports remain
  private outside the repository. This is functional rendering, not a benchmark.
- Subsequent focused checks passed after tightening consumer validation and
  giving interactive preview its own temporary configuration identity. A private
  preview launcher using the verified validation packages is available in the VM;
  it neither installs packages nor enables live launch actions.

- After the owner's blendOS rebuild/reboot, native Quickshell 0.3.1, Qt 6.11.2
  and Go 1.27.0 were installed. Managed configuration deployed from SSH while
  the graphical session was inactive; the second run made no new backups or
  file replacements. Both installed units passed systemd verification. Native
  lint and all eight Qt Quick Test results passed with the installed packages.
- After graphical login, the installed demand-started panel connected to the
  installed data service. Keyboard interaction with its actual buttons launched
  Zsh and Neovim in a disposable registered project directory. Both transient
  terminal services survived panel closure. The agent button launched explicit
  argv `["/usr/bin/sleep","20"]` through the real agent helper/scope; the panel
  received its record with success, exit 0, 20 seconds and measured peak RSS.
  This validates command dispatch and recording without invoking a provider.
  Quickshell logs contained no QML runtime errors. Test terminals and registration
  were removed; the test record and diagnostics were retained in private cache.

**DONE:** Plan 005 implementation and installed launch acceptance are complete.
The earlier suggestion to use `pacman -S` was withdrawn; deployment used the
declared blendOS packages. No tool/reuse decision remains. Plan 006 now owns the
completed supported-VM session cutover; see [Plan 006](006-quickshell-desktop-session.md)
and [the plan index](README.md) for its current status and deferred acceptance.
