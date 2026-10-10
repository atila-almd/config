# Plan 007: Control devices, appearance and active workflows

Status: IN PROGRESS — implementation checkpoint; remaining acceptance unverified
under the [owner-directed verification stop](README.md#owner-directed-plan-007-verification-stop-2026-09-12).
Dependencies: 006 (DONE). Outcome: one lazy control center over the workstation's
existing service and workflow owners. [STATE.md](../../STATE.md#plan-007-implementation-checkpoint-2026-09-12)
records delivered behavior, actual checks and remaining limits.

## Scope

Audio input/output volume, mute and device selection; media transport; wired
status/editor entry; output facts; theme/wallpaper selection; recording status/
stop; project/agent entry; explicit power actions. Layout/text-scale settings
use private Local State. Out: full network editor, monitor policy engine,
Wi-Fi/Bluetooth/laptop controls, new recorder/backups, quotas, notification history.

Grounding: controls currently switch native/external paths. Theme activation
already stages private releases and restores the previous release on failure.
Keep that transaction with one selected shell; media/record/project helpers
remain owners. No new manifest or independent workflow state store.

## Decision points

### Selected implementation (2026-09-12)

The owner selected original Qt Quick Controls presentation and exactly three
MIT Quattro label helpers: `friendlyDeviceLabel`, `nodeProps`, `nodeLabel`, at
commit `0534987009061cbe2dacdde4ad564092ab698d12`. No other donor code is selected.
[UPSTREAM.md](../../services/desktop/UPSTREAM.md) owns inspected sources, license,
coupling, tests and the manual update boundary.

The owner delegated the audio interface choice. Use native Quickshell PipeWire
event observation with explicit `wpctl` commands, native MPRIS media events and
explicit transport actions, and the existing shared backend/helper boundaries
for wired networking, appearance, recording, settings and power. Keep semantic
palette ownership and the original controls; add no package, donor panel or
second audio daemon. These choices are resolved; the remaining gates below
apply only to genuinely new tools or reuse beyond this scope.

- Before adapters needing new tools: choose service binding/library and helper
  language only where 005–006 left them open. Compare push/error support.
- Audio reuse gate: inspect any fitting upstream model functions/tests named by
  [UPSTREAM.md](../../services/desktop/UPSTREAM.md). Report license, imports,
  host services, timers, semantic adaptation and tracked-file/vendor costs,
  then stop. Apply the same gate to other genuinely fitting controls.
- Advanced audio/network tools remain explicit choices if changing current
  owners. Do not reopen an existing choice or keep a second failure route.

## Interfaces

- Extend API.md v1 topics: `audio` (device ID/direction, volume 0..1, mute,
  default ID), `media` (player ID/state/capabilities), `network` (wired ID/state),
  `outputs` (ID/geometry/scale), `recording` (run ID/state), `appearance`
  (theme/wallpaper/release IDs), `power` (supported actions). Unknown is null.
- Adapters subscribe to device/media/network/compositor/power events. Native
  objects never leak into visual rows. Any unavoidable sampling joins the one
  scheduler established in 005 and stops when no consumer needs it.
- Commands: request ID, typed action/arguments; JSON success/cancelled/error
  result with stable error code. Backend events establish resulting state.
- `ControlCenter` takes snapshots/palette and emits intents. Sections load on
  first open and release costly work when hidden. Bar summaries share adapters.
- Private layout settings have a schema and explicit precedence over managed
  defaults. Reset/export only this shell's keys. Palette activation acknowledges
  the exact release and handles atomic `current` replacement, including failure.

## Deliverables

- `surfaces/ControlCenter.qml`, small device/media/appearance rows and adapters,
  managed layout defaults in the existing QML tree.
- Updated controls/theme/wallpaper/record JSON interfaces, selected package/
  service declarations and component/installer entries where needed.
- Device/command/theme fixtures and behavioral tests under the existing shell
  check entry point; API/provenance and desktop/productivity guide updates.

## Checks

Test missing/multiple/disappearing devices, stale IDs, reconnect, muted mic,
failed/cancelled commands, backend restarts and bursts. Verify shared updates,
lazy loaders and hidden subscription disposal. Test corrupt settings, palette
validation, atomic switch, failed acknowledgement and rollback. Run affected
workflow/theme tests, full source suite and actual QML lint/type checks.

Boot empty/full/error fixtures and inspect light/dark, compact/spacious and
200% text screenshots with keyboard/Escape. In blendOS exercise available audio
routes, volume/mute, media, Ethernet reconnect, recording start/stop and theme/
wallpaper changes. Missing physical devices remain unavailable; do not report
their journey passed. Test power actions deliberately with guest work saved.

## Done criteria

- Controls change authoritative state and show real errors.
- Keyboard-usable panels load lazily and release hidden work.
- Theme/settings behavior is tested without source writes.
- Source/QML and supported VM journeys pass; hardware limits recorded.
- Panel-open command and decisions documented; one completion commit.

## Assumptions

- Density and text-scale overrides affect the new control center only. Reset
  and export describe that scope; bar, locker and login scaling remain with
  their existing owners. Plan 010 owns broader consistency across those surfaces.
- Wired networking needs status plus an editor entry, not a second profile UI.
- Hyprland owns output arrangement; this plan exposes facts only.
- Absent hardware stays unavailable rather than enabling speculative services.
