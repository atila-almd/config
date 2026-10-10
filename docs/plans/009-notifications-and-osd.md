# Plan 009: Complete notification feedback and OSD

Status: IMPLEMENTED IN SOURCE — guest acceptance pending. Dependencies: 007.

## Scope

Actionable popups, bounded history/DND, timeout/replacement semantics and
volume/microphone OSD. Show existing capture/media/reminder/record failures
without duplicating those operations. Out: a competing notification daemon,
remote sync, quotas, locker implementation and benchmarks.

## Selected Option 1

Dunst remains the sole org.freedesktop.Notifications owner and the local
history/persistence owner. The structured history adapter extends the
existing workstation-data service, using its current versioned JSON socket and
existing D-Bus dependency. It will not add a second data service, a
notification database, a package, a session launch path or a QML D-Bus owner.

The history presentation is a lazy Island card over that adapter. The
volume and microphone OSD will reuse the existing Island attention surface and
its one deadline/timer owner; no donor shell, standalone OSD package or
widget-owned timer is selected. The source replaces the Super+N history path
with the card while retaining dunstctl for live popup close/pause controls.

The Dunst v1.13.2 source audit and reuse boundary are recorded in
[UPSTREAM.md](../../services/desktop/UPSTREAM.md#plan-009-option-1-dunst-audit).
No Dunst source is vendored.

## Interfaces

### Notification snapshot

The implemented notifications snapshot uses the existing v1 envelope:

```json
{
  "schema_version": 1,
  "type": "snapshot",
  "topic": "notifications",
  "status": "ready",
  "data": {
    "dnd": false,
    "unread_count": 2,
    "items": [
      {
        "id": "42",
        "app_label": "Example",
        "summary": "Build finished",
        "body": "The requested build completed.",
        "urgency": "normal",
        "timestamp": "2026-09-13T12:00:00Z",
        "actions": [],
        "state": "history"
      }
    ]
  },
  "error": null
}
```

The contract has these boundaries:

- items is capped at Dunst's configured history_length = 50; an empty ready
  collection is [], never null.
- dnd maps to Dunst's paused property. unread_count maps to Dunst's waiting
  queue (waitingLength), not an inferred count of historical rows.
- id is the Dunst numeric ID represented as a string. timestamp is UTC RFC3339
  text. urgency is low|normal|critical.
- Historical rows always use state: "history" and actions: []. Dunst owns live
  popup action dispatch; its history records do not retain a safe action
  label/key mapping after the notification closes. The shell must not invent
  action IDs or invoke arbitrary notification content.
- summary and body are bounded plain text. The adapter ignores Dunst icon_path
  and urls; the shell renders body text as plain text, never as executable
  markup or a clickable command/link.
- Unavailable Dunst state is a topic-local unavailable/error snapshot with
  data:null; no empty success snapshot is fabricated during a daemon restart.

The implemented mutation intents are notifications.show {id},
notifications.dismiss {id}, notifications.clear {}, and
notifications.set_dnd {paused}. A notifications.invoke {id,action_id}
intent is reserved for a future live-action mapping and is not advertised by
this history contract. All mutations must use the existing validated helper
boundary and must fail closed on stale or malformed IDs.

### OSD event

The implemented OSD event is an input to the existing Island attention surface:

```json
{
  "kind": "microphone",
  "value": 0.75,
  "muted": false,
  "output_id": null,
  "expires_at": "2026-09-13T12:00:03Z"
}
```

kind is volume or microphone; value is normalized to 0..1 or null; muted is
authoritative; and output_id is a native output ID or null. Repeated events of
the same kind coalesce. expires_at is a deadline owned by the existing
attention lifecycle, not a widget polling interval. Backend PipeWire changes
drive the event; the OSD does not poll devices.

### Lifecycle and privacy

The session-owned adapter keeps a lightweight D-Bus signal match so owner and
history changes cannot be missed, but the server performs no Dunst history or
property reads and publishes no snapshot while the card is hidden. Opening
the card subscribes the shell topic; closing it unsubscribes that topic, and a
later open reconciles after any owner restart. Dunst remains attached to
blendos-workstation-session.target. History is local and bounded. Real
notification content stays out of fixtures, previews, Git and diagnostic
logs.

## Deliverables

The implementation slice delivered by this plan:

- extend the existing Go data service with the notifications topic and the
  Dunst D-Bus adapter; no new package, daemon, socket or vendored source;
- add the lazy Island history card and route mutations through the existing
  control boundary;
- feed volume/microphone changes into the existing attention surface using
  the shared lifecycle scheduler;
- update component/installer wiring only where the existing owners require it,
  and keep current dunstctl bindings until their replacement is implemented
  and tested;
- adds D-Bus, contract, QML and behavior fixtures for bounded history,
  malformed text/image hints, owner restart, action non-advertisement and
  unavailable devices. Guest-only replacement/close journeys and visual OSD
  expiry evidence remain in the acceptance checklist.

## Checks

The focused offline validator and source checks are:

```sh
bash scripts/validate-notification-contract.sh
```

The remaining acceptance requires the existing full source suite, actual
installed D-Bus requests, burst/expiry checks and installed blendOS checks.
Guest checks must invoke notification actions,
restart Dunst, toggle DND, use volume/microphone keys, and exercise reminder,
capture and record failure paths. Repository validation cannot establish those
results.

## Done criteria

- Observed notification capabilities and persistence match this contract.
- History/DND/actions/OSD work with keyboard input and expected Dunst restarts.
- Dunst remains the only notification owner; replaced code and unused
  dependencies are absent.
- Source, behavior, selected-tool/QML and guest render checks pass.
- Commands, limits, choices and maintenance boundary are documented in one
  completion commit.

## Assumptions

- Dunst history is local, bounded and clearable.
- Closed-history action labels are not treated as executable data.
- OSD presentation remains part of Island; a new OSD tool would require a new
  owner decision with a concrete audit.
- Desktop and lock visibility policies must be verified before implementation;
  no private notification content is invented for previews.
