# Workstation data API, version 1

The project and agent helpers own registrations and run records. The Go adapter
under `data/` reads their public JSON and overlays systemd observations. It does
not write workflow state or launch commands. The Island shell consumes this
contract and sends launch intents to the project helper. Card availability and
intentionally skipped sources are documented in ISLAND.md.

Plan 009 Option 1 extends the existing workstation-data service for a
Dunst-backed notifications topic; it does not add a second service or socket.
The topic is subscribed lazily by the Island history card. Dunst remains the
popup and persistence owner, while the card consumes only the sanitized
structured contract below.

## Build, deploy and run

`system.yaml` declares Go. Home installation requires Go 1.27 or newer and
downloads the exact modules in `data/go.sum` when absent from the Go cache.
`GOTOOLCHAIN=local` prevents an implicit compiler download. Build failures stop
installation before deploying home files. Runtime needs no compiler or network.

From the repository, outside the graphical session:

```sh
bash install.sh --config-only
```

Home installation builds and copies the executable to
`~/.local/libexec/blendos-workstation/workstation-data`,
links its command wrapper, and copies `workstation-data.service`. Changed
destinations use the installer's normal backups; identical binaries are retained.
The unit requires the graphical session and stops with
`blendos-workstation-session.target`. That sole target starts both the data
adapter and `workstation-shell.service` at login; the shell also requires the
adapter. The data service performs no metric sampling without interested views.

Inside the installed graphical account:

```sh
systemctl --user start workstation-data.service
workstation-data get projects
workstation-data get agent_runs
workstation-data watch projects agent_runs --metrics
```

`get` exits after one snapshot (nonzero when unavailable/error); `watch` streams
until interrupted or disconnected. `serve` runs the same service in the foreground
for diagnosis. `journalctl --user -u workstation-data.service` shows sanitized
service failures. A lost event subscription terminates the process and systemd
restarts it; clients reconnect and subscribe again.

## Island launch actions

The shell starts through session-workstation-shell; --dashboard, --card,
--debug and --layout target Island IPC, while --preview uses only the bundled
fixture and disables launch actions. --run is the unit's foreground
entry. Both require native Quickshell and a generated theme release. Live mode
uses the installed config; preview copies the same managed sources to a private
temporary directory for a separate instance identity, so it cannot intercept the
live window's lifecycle or theme IPC.
Escape, click-outside and hover grace collapse the expanded Island surface while
the bar remains. The expanded card is hosted by the same surface geometry; it
does not create a separate popup. The adapter stays available until the
graphical session ends, without metric sampling when idle.

The controller invokes `workstation-project dispatch open ID terminal|editor`
or `workstation-project dispatch agent ID -- COMMAND ARGUMENT...`. The project
helper validates the directory and executable before asking systemd to start a
transient service requiring, ordered after, and stopped with the graphical
session. Terminals survive closing the Island card. A successful dispatch means launch
was accepted; command output and later failures belong to the terminal/run record.
The QML Process uses explicit argument arrays and discards helper output so private
paths/argv cannot become status text. It shows a generic failure for nonzero exit.
The agent input accepts a nonempty JSON array of strings, never a shell command
line. Quotes, spaces and shell metacharacters remain literal argument content.

Presentation components take explicit collections, status, selection and Island
palette inputs and emit intents. The Projects card's selection is temporary view
state; the helper's persisted CLI selection is only the initial choice. Existing project
registrations and run records remain authoritative.

## Island bar and native adapter contracts

The persistent shell creates one bar per native output. `Desktop.qml` converts
native Hyprland and StatusNotifier event state to JSON-compatible values:

```json
{"schema_version":1,"status":"ready","items":[{"id":"1","name":"1","output_id":"DP-1","active":true,"focused":true,"urgent":false}]}
{"schema_version":1,"status":"ready","revision":7,"items":[{"id":"application","slot":0,"title":"Application","tooltip":"Application","icon":"image://native/icon","has_menu":true,"only_menu":false}]}
```

Workspace IDs are string forms of compositor IDs, including negative named
workspace IDs. Output IDs are native screen/monitor names, never configured
guesses. `workspaceRequested(id)` resolves the current native workspace and
calls its activation method. Removed IDs do nothing. An empty monitor collection
reports workspaces unavailable instead of inventing output state.

Tray `id` is the backend application ID, which may repeat across processes.
`trayRequested(id, slot, revision, action, x, y, delta, horizontal)` requires
the current collection revision and matching slot/ID before acting. Actions are
`activate`, `secondary`, `menu`, or `scroll`; native DBusMenu owns popup content.
Coordinates are relative to the owning bar window. Slots are observation-local,
not persistent identity. Reordered/removed entries reject stale actions.
The adapter publishes items and revision together as one snapshot; evaluating a
snapshot never increments its revision. Native DBusMenu popups require the shell
root's `UseQApplication` pragma.

IslandBar emits explicit widget, dashboard, collapse, workspace, tray, launcher,
terminal and lock intents. Its tooltips stay inside an input-transparent IslandGlass
surface, so hover text cannot cover a workspace or tray button and consume its click.
Views contain no native objects, commands, processes or timers. One shell scheduler
supplies all rolling clocks, activity samples and timer ticks. Preview fixtures do
not invent live data.
The terminal action starts `session-terminal` in a transient user service bound
to `graphical-session.target`. It survives shell restart and ends at logout.

Native Island IPC on config workstation provides island show/hide/toggle,
card, dashboard, collapse, debug, layout, attention, configReload and status.
panel and controls remain compatibility aliases. Native theme IPC provides
reload, current and release; the last returns the exact loaded semantic release
ID.

## Island control contracts

The old validated control helper remains the side-effect boundary; Island cards
call it without opening the retired Qt Quick Controls window. Open Island with
`session-workstation-shell --controls [section]`; sections are `audio`, `media`,
`network`, `outputs`, `appearance`, `recording`, `power` and `settings`.
`--preview-controls` renders private fixtures without live adapters or commands.
Native IPC target `controls` provides `show`, `hide`, `toggle`, `section(name)`
and `status`. The status output is diagnostic, not authorization.

## Quickshell launcher adapter

The Island launcher is a Quickshell surface over the installed Elephant
provider family. `workstation-launcher.service` owns the project adapter and
listens on `$XDG_RUNTIME_DIR/blendos-workstation/launcher.sock`; the socket is
mode `0600` and is removed when the service exits. The adapter is deliberately
separate from the data socket so search cancellation and provider failures do
not affect project or agent subscriptions.

Requests are newline-delimited JSON:

```json
{"schema_version":1,"request_id":"launcher-4","op":"query","query":"ghost","kind":"launcher","limit":30,"providers":["desktopapplications","calc","websearch"]}
{"schema_version":1,"request_id":"activate-5","op":"activate","provider":"desktopapplications","identifier":"com.mitchellh.ghostty.desktop","action":"start"}
```

The bridge speaks Elephant's versioned framed JSON socket internally. It
allows only the managed provider IDs, clamps results to fifty rows and closes
the previous Elephant query when a newer request arrives. Results use one
stable envelope:

```json
{"schema_version":1,"type":"result","op":"query","request_id":"launcher-4","status":"ready","items":[{"id":"com.mitchellh.ghostty.desktop","kind":"desktopapplications","label":"Ghostty","detail":"Terminal","icon":"utilities-terminal","available":true,"provider":"desktopapplications","identifier":"com.mitchellh.ghostty.desktop","actions":["start"]}]}
```

Only the provider and identifier from a current row may be activated. Desktop
entries are validated and passed as literal arguments to `uwsm app`; file
rows use the path retained from the current Elephant snapshot and pass it as
one literal `xdg-open` argument through a session-bound `systemd-run`; calc
rows copy their result through `wl-copy`. The bridge never evaluates labels,
provider text, query text or shell command strings. Unsupported actions return
an explicit error and do not fall back to Elephant's shell-based activators.

The launcher is observed only while its Island surface is open. It clears
rows on reconnect, ignores stale request IDs, closes hidden work and reports
backend unavailability without inventing empty success data. Walker remains
the selected presentation for the distinct clipboard, symbol, window,
menu/capture and shortcut jobs; it does not provide the application launcher
surface.

Island cards take plain snapshots, palette tokens and explicit intent signals.
The Controls adapter remains the validated side-effect boundary; no native
objects, subprocesses or timers belong to Island surfaces. Audio/media commands
are admitted against current capabilities, while recording and power continue
to use the shared event topics. Hidden expanded content does not create new
subscriptions or widget-owned polling.

Quickshell's native MPRIS singleton has no unsubscribe/disable interface. After
first use its upstream event-only discovery may persist even when the project's
adapter is unloaded. No media position reads, position timer or polling helper
is introduced. PipeWire node properties are tracked only by the native adapter;
the three selected label helpers and their provenance are in [UPSTREAM.md](UPSTREAM.md).

Each topic uses the existing v1 snapshot envelope with `status`, `data`,
`revision`, `observed_at` and sanitized `error`. The center combines native
`audio`, `media`, `outputs` snapshots with shared `network`, `appearance`,
`recording`, `power` snapshots. Unavailable/error snapshots have `data:null`;
ready empty lists remain empty. Unknown values are null, never guessed zeros.

| Topic | `data` fields |
| --- | --- |
| `audio` | `default_output_id`, `default_input_id`; `items` with string `id`, `direction:output|input`, `label`, `volume:number|null` in 0..1, `muted:boolean|null`, `available:boolean` |
| `media` | `items` with full MPRIS bus-name `id`, `label`, nullable `title`/`artist`, `state:playing|paused|stopped`, `can_play`, `can_pause`, `can_next`, `can_previous` |
| `network` | Wired `items` with backend `id`, `interface`, `label`, measured `state` and nullable boolean `carrier` |
| `outputs` | Native `items` with `id`, `label`, `x`, `y`, `width`, `height`, `scale`, `focused` |
| `appearance` | `theme_id`, `release_id`, `wallpaper_id`; `themes:[{id,label,mode}]`, `wallpapers:[{id,label}]`, and `settings` below |
| `recording` | `run_id`, `state:idle|starting|recording|stopping|completed|failed|unknown`, `can_stop` |
| `power` | `actions:[{id,available,authorization}]`; authorization is `yes|challenge|no|na|unknown` |

### Plan 009 Option 1 notification contract

The implemented notifications snapshot uses the existing v1 envelope and is
loaded lazily when the Island history card is open:

```json
{
  "schema_version": 1,
  "type": "snapshot",
  "topic": "notifications",
  "status": "ready",
  "data": {
    "dnd": false,
    "unread_count": 2,
    "items": [{
      "id": "42",
      "app_label": "Example",
      "summary": "Build finished",
      "body": "The requested build completed.",
      "urgency": "normal",
      "timestamp": "2026-09-13T12:00:00Z",
      "actions": [],
      "state": "history"
    }]
  },
  "error": null
}
```

The adapter maps Dunst paused to dnd and Dunst waitingLength to unread_count;
history_length = 50 is the array cap. IDs are strings, timestamps are UTC
RFC3339 text, urgency is low/normal/critical, and unavailable Dunst state is
topic-local unavailable/error with data null. History rows expose `actions: []`
because closed Dunst records do not retain a safe action mapping; live popup
actions remain Dunst-owned. Summary/body are bounded plain text. icon_path and
urls are omitted, and the shell never evaluates notification markup, links or
commands.

The implemented intents are `notifications.show {id}` (Dunst history-pop),
`notifications.dismiss {id}`, `notifications.clear {}`, and
`notifications.set_dnd {paused}`. No history action-invoke intent is exposed:
Dunst owns live popup actions, and closed history records do not retain safe
action labels or keys. Mutations fail closed on stale or malformed IDs.
Dunst history, NotificationHistoryRemoved/NotificationHistoryCleared,
NotificationClosed/ActionInvoked and pause/property changes invalidate the
topic; no widget-owned poller is added. See Plan 009 and the Dunst audit in
UPSTREAM.md for the source and maintenance boundary.

Output focus compares the current monitor with `Hyprland.focusedMonitor`.
This canonical native pointer handles startup-discovered monitors whose individual
`focused` property remains false in Quickshell 0.3.1. The adapter keeps native
event dependency tracking; it adds no fork, polling or JSON fallback. The exact
upstream source path is recorded in [UPSTREAM.md](UPSTREAM.md#plan-007-native-output-focus).

The controller validates current IDs/capabilities, assigns a request ID and
calls `workstation-controls dispatch` with one JSON argument:

```json
{"schema_version":1,"request_id":"controls-1","action":"audio.set_volume","args":{"id":"42","volume":0.5}}
```

The helper emits one result:

```json
{"schema_version":1,"type":"result","request_id":"controls-1","status":"ok","error":null,"data":null}
```

Status is `ok|cancelled|error`; errors have a stable code and sanitized message.
Lock contention reports `busy`; bounded command expiry reports `backend_timeout`.
External editor/audio/media commands have a ten-second bound; recording, lock
and suspend have a 45-second bound. Appearance keeps its helper-owned transaction
and acknowledgement limits.
Successful dispatch acknowledges the request; subsequent backend facts establish
device, media, theme and recording state. Volume controls reinstall their value
binding after user input, including failures with an unchanged snapshot. Mute,
default selection and private settings never optimistically replace backend data.

| Actions | Arguments |
| --- | --- |
| `audio.set_volume`, `audio.set_mute`, `audio.set_default` | `{id,volume}`, `{id,muted}`, `{id}` |
| `media.play`, `media.pause`, `media.next`, `media.previous` | `{id}`; explicit transport action, no toggle |
| `network.open`, `audio.open_mixer` | `{}`; existing external editor/mixer |
| `appearance.set_theme` | `{id}` |
| `appearance.set_wallpaper` | `{id,theme_id,release_id}`; reject a stale selection |
| `recording.stop` | `{run_id}`; reject a replaced recording |
| `power.lock`, `power.suspend` | `{}`; existing lock/guarded suspend owners |
| `power.logout`, `power.reboot`, `power.shutdown` | `{confirmed:true}` after explicit UI confirmation |
| `settings.update`, `settings.reset`, `settings.export` | Only `{density?,text_scale?}`, `{}`, `{}` respectively |

Settings are private overrides with `schema_version:1`, optional
`density:compact|spacious` and optional numeric `text_scale` from 1 to 2.
These overrides affect only the settings controller; Island, the locker and login retain
their own geometry and text sizing. Managed defaults are spacious/1. Reset removes
only those overrides, and export returns only the settings schema
in result `data`. The controller provides a read-only selectable JSON string for
copying. Corrupt settings show an explicit error while retaining reset/export.
The settings file uses mode 0600 in a private directory, atomic replacement and a
private operation lock to serialize updates. Neither operation publishes themes or exports credentials,
device settings, paths, project data or unrelated configuration.

Appearance reads call the existing `workstation-theme snapshot` and
`workstation-wallpaper snapshot` interfaces. They return metadata only and create
no state or rendered assets. Theme data is `{theme_id,release_id,themes}`;
wallpaper data is `{theme_id,release_id,wallpaper_id,items}` with numeric-string
wallpaper IDs. The backend retries up to three times to join matching theme/release
observations; concurrent activation cannot publish a mixed appearance snapshot.
Mutation uses `workstation-wallpaper set INDEX --expect-theme THEME
--expect-release RELEASE`. Theme and wallpaper mutations serialize with one
operation lock in the existing theme state root; the renderer's child wallpaper
restore adopts its verified inherited descriptor. Mismatched expected identity
returns 75 before applying anything; concurrent mutation returns 73.

Every rendered `workstation-shell.json` includes `release_id`, distinct from
`theme_id`. Activation waits for each active shell/locker `theme release` endpoint
to report exactly that ID after reload. An older release of the same theme does
not acknowledge the transaction. Failed acknowledgement uses the existing atomic
pointer/selection rollback and reissues the previous release. The locker keeps
its in-flight PAM conversation throughout palette reload.

`bash scripts/test-workstation-control-center.sh` runs pure Qt fixtures. Add
`--render /absolute/new/directory` to retain the fixture captures outside the
repository. Tests cover explicit intents, missing/replaced devices, unknown
values, authoritative failure state, media capabilities, stale theme/record IDs,
power confirmation, Tab/Shift+Tab focus visibility while scrolling, keyboard/Escape,
settings recovery/export and light/dark
empty/full/error layouts at up to 200% text. Qt 6.2.4 may report one QQmlContext
fixture warning; native warning-free lint and installed acceptance are separate.

## Graphical login contract

The pre-login Quickshell greeter uses `Quickshell.Services.Greetd` as its only
authentication/session backend. Its controller submits a validated account
name to `createSession`, displays transient greetd messages, answers only
responses marked as required, and calls `launch` with the exact UWSM argv
`/usr/bin/uwsm start -e -D Hyprland -- workstation.desktop`. It never uses
`PamContext`, reads private theme state or starts user services. The isolated
Hyprland host and the `greeter` account own the pre-login lifecycle; successful
handoff terminates both before the Workstation session starts.

The public login palette is a version-1 projection of the bundled Catppuccin
manifest at `/etc/blendos-workstation/identity/public-theme.json`.
`mark-dark.svg` and `mark-light.svg` are system-readable static variants. A
missing or invalid public release uses the neutral emergency palette and
reports an actionable error; it never falls back to a user's private release.

## Independent locker contract

Config `workstation-lock` runs independently and imports the pure `AuthForm`
presentation shared with the graphical greeter. It takes palette, prompt/message,
response visibility/requirement, busy/ready/retry state, keyboard state and a
reset token, and emits response, cancel, retry and input-state-refresh intents.
Responses remain transient in the TextField/PAM call and clear on every prompt,
submission, cancel and result. No credential enters workstation-data or status IPC.

`KeyboardState.qml` reads `hyprctl devices -j` on initial/focus, native
layout/config events and modifier release. Exactly one backend `main` keyboard
must provide boolean `capsLock` and string `active_keymap`. Its snapshot is
`{schema_version:1,status:"ready",caps_lock:false,layout:"English (US)"}`;
failure/ambiguity uses `status:"unavailable"` and null values. It does not infer
Caps Lock or layout and introduces no polling timer.

`qs -c workstation-lock ipc call -- lock status` returns
`{schema_version:1,requested:true,secure:true,authenticating:false}`. This is
diagnostic, not a sleep authorization contract. The guard independently consumes
compositor lock notifications. The locker begins PAM only after native secure
acknowledgement, and PAM success invokes the guard's `prepare-unlock` command.
Only successful inhibitor reacquisition/storage permits compositor unlock.
There is no unlock/close IPC. Theme `reload`/`current`/`release` are the only other endpoints.
File watching is disabled in the locker so a source edit cannot replace an
in-flight PAM conversation; palette IPC preserves that conversation. Denied or
unacknowledged acquisition exits with failure instead of leaving an inert service.
Compositor acknowledgement establishes protection, including a possible crash
surface; it does not prove that usable authentication pixels have been rendered.

The common `WorkstationShared` QML module lives under
`.config/quickshell/WorkstationShared` and contains one copy of authentication,
palette presentation and contract helpers. The installer copies this same
module into the public identity bundle for pre-login use; wrappers set its
parent directory in process-scoped `QML_IMPORT_PATH`. Relative imports across
Quickshell configuration roots are unsupported by its runtime scanner and must
not replace this module.

## Helper reads

`workstation-project list` emits `{ "schema_version": 1, "data": ... }`, where
data contains `selected_id: string|null` and `items: []`. Each project has `id`,
`label` and `directory_available: boolean`. Paths remain private. Reads do not
create state. Directory availability is measured on each snapshot; directories
and project contents are not recursively watched.

`workstation-agent list` uses the same envelope with `data.items`. It reads
persisted facts, without querying systemd per record. `status RUN-ID` observes
the live scope and returns one record in `data.items`; an unexpectedly missing
scope is `state-lost` with nonzero exit status. Both expose a whitelist of run
fields; GNU time maximum RSS uses `max_rss_kib` here. Socket snapshots normalize
that field to bytes. Neither read exposes prompts, argv, credentials or paths.
The explicit launch/select commands remain owned by the helpers and are separate
from this read-only socket.

## Transport and subscriptions

Endpoint: `$XDG_RUNTIME_DIR/blendos-workstation/data.sock`. The runtime and child
directory must be owned by the user with mode 0700; socket mode is 0600 and Linux
peer credentials must match. An exclusive lock prevents competing instances.

One UTF-8 JSON object per newline; embedded newlines must be escaped. Requests:

```json
{"schema_version":1,"request_id":"panel-1","op":"subscribe","topics":["projects","agent_runs"],"metrics":true}
{"schema_version":1,"request_id":"panel-2","op":"unsubscribe","topics":["agent_runs"]}
```

Only `subscribe` and `unsubscribe` exist. Request IDs are 1–64 ASCII letters,
digits, dots, underscores or hyphens, beginning with a letter/digit. Unknown
fields, duplicate/unknown topics and unsupported versions are rejected.
The allowed topics are `projects`, `agent_runs`, `network`, `appearance`,
`recording` and `power`; mutation is never a socket operation. Metrics
interest is valid only with an agent-run subscription. Resubscribing replaces
that interest and requests a fresh snapshot; unsubscribing affects named topics.

Each request gets `type: result`, `schema_version`, `request_id`, `status: ok|error`
and `error: null|{code,message}`. Invalid requests return an empty request ID.
Successful subscriptions then receive complete snapshots, never deltas:

```json
{"schema_version":1,"type":"snapshot","topic":"projects","revision":"opaque-1","observed_at":"2026-09-09T23:00:00Z","status":"ready","data":{"selected_id":null,"items":[]},"error":null}
```

Revisions identify observations and change across service restarts. They are not
replay cursors. Ordering is per socket; topics can finish independently. A client
must discard old connection state on reconnect. Pending record/lifecycle changes
coalesce and supersede a load; pending metric ticks do not discard a completed
sample. Subscription refreshes can also update existing observers.

Status is `ready`, `unavailable` or `error`. Failure has `data: null` and a
sanitized error. Known codes: `backend_unavailable`, `systemd_unavailable`,
`invalid_backend_data`, `backend_error`, and request-only `invalid_request`.
Missing accounting is null; unavailable systemd is not mistaken for a missing
scope. Freshness (`observed_at`) is distinct from run state.

Limits: 16 clients, 64 KiB request, 4 MiB snapshot, 2048 items per topic; each
client has an eight-message/4 MiB outgoing bound and a three-second write
deadline. Slow clients and oversized requests disconnect. Oversized snapshots
produce an error. Helper loads have a five-second deadline and bounded output.
Disconnect/unsubscribe removes interest; no event history is retained.

## Run snapshot data

`agent_runs.data.items` contains newest-first records with these fields:

| Fields | Type and meaning |
| --- | --- |
| `id`, `label`, `unit` | Strings; stable run ID, display label, systemd scope |
| `project_id` | Registered ID or null; never inferred from an unknown path |
| `state` | `running`, `succeeded`, `failed`, `interrupted`, `state-lost` |
| `started_at`, `ended_at` | RFC3339 timestamp; end may be null |
| `exit_status` | Integer or null |
| `cpu_usage_ns`, `memory_bytes`, `max_rss_bytes` | Exact unsigned decimal strings or null |
| `wall_seconds`, `user_cpu_seconds`, `system_cpu_seconds` | Measured decimal strings or null |
| `provider_usage` | Always null; no provider quota inference |

Projects sort by ID. A ready empty collection is `[]`, never null. JavaScript
consumers must preserve counter strings until display conversion to avoid losing
64-bit precision. Zero is a measurement; null means unknown/unavailable.

## Event and sampling ownership

fsnotify watches registry/run state directories and atomic replacements, adds
new run-directory watches and resynchronizes after overflow. Reads never create
missing state directories. systemd D-Bus signals invalidate scope lifecycle;
manager ownership changes trigger resubscription. Read calls prohibit service
autoactivation. No periodic helper invocation or lifecycle scan exists.

The control topics extend the same event service. Filesystem invalidations cover
theme release/index/settings and recording changes. NetworkManager and logind
signals invalidate wired and power facts. A missing service name on a healthy
system bus yields topic-local unavailability and recovers on owner events; an
initially unavailable or disconnected bus terminates the data service so its
existing systemd restart policy can reconnect. Removing the last topic subscriber
cancels an in-flight read. Native audio/media and output events remain inside
their Quickshell adapters; they add no helper polling schedule.

systemd accounting counters do not provide continuous property-change signals.
One adapter-owned two-second scheduler samples active scopes while at least one
agent subscriber requests metrics. All consumers share its results. The timer
stops when the last metric observer leaves or no active runs remain. Hidden
panels must unsubscribe; widgets must not start their own metric timers.

## Shell theme input

The existing theme renderer also produces `workstation-shell.json` in its atomic
release. The UI reads
`${XDG_STATE_HOME:-$HOME/.local/state}/blendos-workstation/theme/current/workstation-shell.json`.
It contains `schema_version: 1`, `release_id`, `theme_id`, `mode: dark|light` and the semantic
`colors` object from the selected theme manifest. Release validation requires an
exact match with that manifest. Both bundled and private themes use this path.
Geometry, font defaults and behavior belong in managed UI configuration. There
is no independent shell theme selection. Theme activation invokes the active
shell's and active locker's `theme reload` IPC handlers after switching the atomic
pointer. A malformed/missing initial shell theme fails startup. The locker instead
retains a neutral emergency palette so theme failure never prevents protection.

## Checks

Source and presentation checks:

```sh
bash scripts/check-workstation-shell.sh --source
bash scripts/test-workstation-shell.sh
```

The component tests use Qt Quick Test offscreen with the Basic controls style.
They exercise empty/error layouts, keyboard selection and Escape, emitted open
and launch intents, invalid/literal argv, many rows, palette changes and 200%
text in wide and narrow layouts. Auth/bar fixtures also cover response clearing,
busy/secure gating, prompt changes, output filtering and typed tray intents.
These tests do not import Quickshell.

Additional native source checks can run in a disposable Linux environment:

```sh
bash scripts/check-workstation-shell-native.sh
bash scripts/check-workstation-shell-views.sh "$HOME/.cache/workstation-view-check"
```

The first requires native Quickshell, jq, `dbus-run-session` and test-only Weston.
A private D-Bus fixture loads the real desktop adapter and reads its initial tray
snapshot, catching native binding loops without claiming a live tray application.
It also starts a
private headless display, loads the real shell and locker roots/modules, checks
missing/invalid initial theme failures, and requires explicit locker rejection
when the lock protocol is unavailable. A native Process fixture covers guard
success, nonzero exit, failed executable startup and retry. No PAM credentials,
live desktop or logind sleep operation is used. Weston is not a workstation
package selection. The second needs native Quickshell and renders bar/auth views
offscreen with no backends; it includes the bar's actual default height at 1920px
and narrow/enlarged-text fixtures. Inspect PNGs; neither check establishes guest
or actual lock acceptance.

Inside the rebuilt blendOS graphical account:

```sh
bash scripts/check-workstation-shell.sh --lint
bash scripts/check-workstation-shell.sh --live
bash scripts/check-workstation-shell.sh --render "$HOME/.cache/workstation-render-check"
```

Lint requires native Quickshell qmltypes and rejects warnings. Narrowly
annotated native signal handlers account for missing enum metadata in Quickshell
0.3.1; socket reconnect is exercised natively and process completion belongs to
installed launch acceptance. The live check builds the
actual adapter and runs real helper reads/events in private temporary state,
covering disconnect/reconnect, hide/show and an atomic private-theme switch.
It never executes launch intents. The render check uses a disposable fixture
window on the active Hyprland display, captures its geometry with Grim, checks
nonuniform pixels with ImageMagick, scans runtime diagnostics and cleans up its
process. Inspect its PNG as well; stored reports must be outside the repository.
An existing report directory is never overwritten. Native tools are declared in
system.yaml and installed through the blendOS rebuild procedure in the root guide.

`bash scripts/test-workstation-data.sh` runs standard Go tests with the race
detector, real Unix sockets/inotify, an isolated D-Bus mock manager and `go vet`.
Requires Go 1.27+, GCC and dbus-daemon in Linux. Tests cover protocol validation,
exact counters, source cancellation, lifecycle/metric ownership, reconnect,
atomic filesystem changes and manager disappearance/reappearance. The installer
rerun check covers executable deployment and unchanged reruns. These establish
backend behavior, not installed blendOS or QML rendering acceptance.
