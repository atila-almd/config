# Plan 008: Search applications and complete utility selection flows

Status: IMPLEMENTED IN SOURCE; installed launcher and visual acceptance remain
guest checks. Dependencies: 006; normally execute after 007.

## Scope

Application/project search and coherent entry points for clipboard, symbols,
windows, shortcuts, themes, capture/OCR/QR/conversion, reminders and existing
development/recovery commands. One implementation per selection job; different
jobs may use different chosen tools. Out: new providers, account scanning,
new media/backup engines, unrelated app defaults and generic plugins.

Grounding: Walker/Elephant provides more than application search: stdin project/
theme selection, utility/power menus and clipboard/symbol/window providers.
Update all callers of a replaced interface together; no compatibility wrapper.

## Decision points

- Before search replacement: compare 2–4 launcher/index approaches with actual
  ranking, launch and event APIs. Neither Quickshell UI nor Walker retention is
  preselected. Honor any binding choice already made in 006.
- Choose clipboard/symbol/window/stdin selection tools when app search cannot
  fulfill those jobs. Each selected job has one path, never cross-tool fallback.
- Before QML: audit fitting upstream search fields/result rows/lists for license,
  focus, services, singletons, themes and timers; present reuse/adapt/original
  costs and vendoring versus tracked-upstream choice, then stop.

## Executed decisions

The owner selected a Quickshell launcher surface over Elephant's existing
provider/index family. Elephant remains the source-built, version-aligned
backend. A project-owned Go adapter translates Elephant's framed JSON socket to
the stable launcher JSON envelope, bounds results and cancels the previous
query. The adapter owns typed activation: desktop IDs go to `uwsm app`, file
paths go as one literal `xdg-open` argument through a session-bound
`systemd-run`, and calculator results go to `wl-copy`. Elephant's shell-based
activation is not called. Walker remains for the distinct clipboard, symbols,
windows, utility-menu/capture and shortcut jobs; its competing default
application search entry was removed.

The presentation is original project-owned QML using Qt Quick Controls and the
existing Island palette/motion components. No QML donor, second index or new
provider package was introduced. Prefixes `/`, `=` and `@` select files,
calculator and web-search providers; the existing utility providers remain
available through Walker's explicit bindings.

## Interfaces

- Search request: `{request_id,query,kind,limit}`. Shared JSON envelope returns
  items `{id,kind,label,detail,icon,available}`. Activation uses ID and typed
  action, never executable text derived from a label. Obsolete/cancelled results
  cannot overwrite a newer query. Bound result sizes; specify ranking fixtures.
- Apps obey desktop-entry field codes/literal args, UWSM app lifetime and the
  Ghostty desktop override for `Terminal=true`. Projects use 005's backend.
- Selection distinguishes selected ID, cancellation and failure. Clipboard
  payloads remain private, never search logs/settings. All providers expose
  JSON snapshots/events at their adapter boundary; subscribe to desktop-file,
  clipboard and window changes. Search loads on demand and cancels hidden work.

## Deliverables

- `surfaces/Launcher.qml`, `adapters/ElephantLauncher.qml`, and the
  `workstation-launcher` Go bridge with its user service.
- Updated bindings, project/keybinding/theme/utility callers and menus only if
  still selected; native declarations, components, installer and units as needed.
- Delete replaced Walker/Elephant configs/providers/wrappers/templates/tests
  when no selected job uses them. If Elephant remains, keep its package family
  version-aligned. Remaining backends must have an explicit selected job.
- Behavioral fixtures, shell checks, API/UPSTREAM records and workflow guides.

## Checks

Test ranking, duplicate labels, missing binaries, desktop actions, literal
metacharacters, `Terminal=true`, old query replies, empty/error/cancelled results.
Test clipboard text/images after source exit, symbols and disappearing windows.
Exercise every replaced stdin/menu caller. Run relevant workflow tests, full
source suite, selected-tool validation and QML checks where QML changes.

In blendOS launch apps/terminal/project from the binding, search shortcuts
read-only, use clipboard text/image/symbols, focus windows and run representative
capture/OCR/reminder flows. Inspect private fixture screenshots, focus/Escape,
200% text and output placement when available; check no content leaks into logs.

## Done criteria

- Every listed selection job has a working entry and clear failure semantics.
- Literal argv, desktop activation and terminal ownership are correct.
- Replaced tools/callers are deleted; chosen backend families are coherent.
- Source, selected-tool/QML and live interaction checks pass.
- Commands/choices documented; one completion commit.

## Assumptions

- Preserve existing utility scope/binding intent, not all upstream providers.
- Different tools for separate jobs are allowed; duplicate implementations of
  the same job and failover routes are not.
