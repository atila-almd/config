# Implementation plans

Execution direction accepted 2026-09-09 after the earlier shell evaluation,
reconciled against baseline `6f88261`. Work branch: `quickshell-shell`.

| Plan | Outcome | Dependencies | Status |
| --- | --- | --- | --- |
| [005](005-project-and-agent-panel.md) | Usable project/agent window | Existing backends | DONE — source, native/render and installed launch acceptance passed |
| [006](006-quickshell-desktop-session.md) | Sole desktop session and working bar | 005 | DONE — supported-VM acceptance passed; RustDesk deferred below |
| [007](007-workstation-control-panels.md) | Device/appearance/workflow controls | 006 | IN PROGRESS — implementation checkpoint; remaining acceptance unverified by owner direction |
| [008](008-launcher-and-utility-entry-points.md) | Search and utility selection | 006 | IMPLEMENTED IN SOURCE — guest launcher/visual acceptance pending |
| [009](009-notifications-and-osd.md) | Notifications/history/DND/OSD | 007 | IMPLEMENTED IN SOURCE — guest acceptance pending |
| [010](010-desktop-identity-and-login.md) | Matching desktop/lock/graphical login | 007, 008, 009 | IMPLEMENTED IN SOURCE — guest acceptance pending |

The original 001–004 planning set and its shell-selection evidence were
superseded before the current implementation. Git history retains that
record; active planning and decisions begin with Plan 005.

## Execution contract

These six usable deliveries form the active roadmap. The project/agent window
works before shell replacement. Session cutover stays together because installer,
bindings, theme routing and agent/record/reminder target detection cannot be
independent infrastructure milestones. Controls, selection and notifications
have separate bounded surfaces and tests. Identity ends with usable login,
not a polish-only or benchmarking plan.

The plan set was committed before implementation began. At every new
tool/library/approach choice, present 2–4 viable candidates with concise
tradeoffs and a recommendation, then stop for the owner. A historical
recommendation is not a selection. Record
the answer and implement only that path. Honor choices already made for the
same responsibility. Other unresolved design details are executor decisions
recorded under Assumptions in the affected plan.

On 2026-09-11 the owner explicitly authorized direct definition of the combined
production stack without a separate proof of concept. The selected decisions
are owned by Plans 006 and 010 and do not need to be presented again for
selection. This authorization covers that recorded stack, not arbitrary future
tools or dependencies; installed acceptance and plan-completion checks remain.

Before proposing reuse, inspect the actual component at a pinned revision.
Report license, imports, services/singletons, theme assumptions, timers,
lifecycle, necessary changes, and vendoring versus tracked-upstream maintenance.
Recommend reuse, adapt or original code and stop for the answer. A component
needing half a rewrite is not cheap reuse. Native Noctalia v5 evidence is not
QML evidence; older QML needs its own audit. No donor is approved by these plans.

### Plan 009 Option 1 decision (2026-09-13)

Option 1 is selected for Plan 009. Dunst remains the sole notification daemon
and persistence owner. The source implementation extends the existing
`workstation-data` service and its versioned JSON contract; it does not
introduce another user service, package, D-Bus owner or notification database.
The volume/microphone OSD reuses the existing Island attention surface and its
single deadline owner rather than adding a donor surface or widget timer.

The Dunst v1.13.2 source audit, including the exact tag commit and D-Bus
methods/signals used by this boundary, is recorded in
[services/desktop/UPSTREAM.md](../../services/desktop/UPSTREAM.md#plan-009-option-1-dunst-audit).
No Dunst source is vendored. The Go adapter, history presentation and
microphone/volume event feed are present in source. Installed behavior,
keyboard/restart journeys and visual acceptance remain pending; this is not a
Plan 009 completion claim.

### Plan 010 source checkpoint (2026-09-13)

The selected greetd/native-Quickshell stack is implemented in source. The
project-owned isolated pre-login host, public identity projection, shared
authentication presentation, component rows, validators and Qt fixtures are
present. The source tests and disposable installer publication test pass in
WSL. Native Quickshell lint/render and all installed login, keyring, portal,
TTY, logout/relogin and visual checks remain pending without a rebuilt blendOS
guest; this checkpoint is not a completion claim.

Each completed plan gets one implementation commit including checks, operator
docs, decisions and status. A decision-blocked partial plan is not DONE and gets
no completion commit. Report actual checks, assumptions, pending choice and
exact available launch command; proposed commands are not runnable results.

### Owner-directed Plan 007 verification stop (2026-09-12)

The owner directed that no further code checks were needed and authorized
committing the current work. This permits a Plan 007 implementation checkpoint
without rerunning the latest guest fixes or completing the remaining installed
journeys. Retain the actual prior evidence and identify unverified acceptance;
this direction does not turn those checks into passes or mark the full plan DONE.
[STATE.md](../../STATE.md#plan-007-implementation-checkpoint-2026-09-12) owns the
checkpoint's evidence and limits. No later tool or reuse choice is selected by
this commit authorization.

### Owner-directed RustDesk sequencing (2026-09-12)

The owner authorized committing the current work on `quickshell-shell`, including
a checkpoint if other Plan 006 acceptance remains incomplete. This is not a
completion claim or a general change to the completion-commit rule above.

RustDesk functionality and its locked-session/boot-greeter acceptance are
deferred until the remaining non-RustDesk work in Plans 005–010 is ready. Keep
the selected package and the recorded capture failure; do no RustDesk diagnosis,
access restoration, remote tests or fixes before that condition. Resume the
deferred work when the condition is met without requiring another authorization.
Remote acceptance is therefore not a completion gate for Plans 006 or 010.
All other source, installed, graphical, lifecycle and authentication requirements
remain in force. Mark Plan 006 complete only if RustDesk is its sole remaining
gap; any other unmet required check keeps it in progress.

## Replacement boundary

No compatibility output, fallback session, old-config archive or migration path.
Change repository callers/tests together when an interface changes. Delete
replaced components' managed configs, units, templates, bindings, obsolete tests
and unused packages in the same delivery. Git holds history. Fresh provisioning
is the target; add no stale-install conversion/cleanup system. Do not erase
unrelated private data. Existing general installer protection for displaced
personal files is not old-shell support; add no special shell backups.

005 adds a window without replacing a desktop owner. 006 deletes Noctalia and
Waybar and collapses session selection to one path. Existing independent
utilities may remain the sole implementation of their jobs until their plan;
they are not a second desktop or failure route. Plan 006 records the selected
tools that replace bundled Noctalia duties before removal. Later deliveries honor
those choices and may add presentation without competing daemons.

Native packages belong in `system.yaml`, project code in managed home paths,
capability mappings in `components.tsv`. API/operational docs belong in desktop
or workflow service guides; plans describe intended contracts until implemented.
No measurement/benchmark gates, unrelated Priority 7, speculative hardware,
backup destination or OS-recovery implementation.

## Verification

Use focused workflow tests, behavioral fixtures and actual QML lint/type checks.
The bounded boot/render check captures and inspects pixels; a running PID or
ready log alone is not evidence. Test keyboard/Escape, scaling and errors in
the graphical runtime. Real screenshots/records remain private Local State.
New source `test-*.sh`/`validate-*.sh` join `bash scripts/check-repository.sh`;
installed/render modes are explicit. Missing prerequisites never count as PASS.
Windows/WSL can run source checks; installed checks run in rebuilt blendOS.
Required unavailable guest checks leave the plan incomplete while independent
work may continue. Every completed plan leaves its stated usable outcome.
