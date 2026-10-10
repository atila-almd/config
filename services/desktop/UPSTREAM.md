# Workstation shell upstream record

## Accepted backend dependencies

The owner selected Go, fsnotify, direct godbus/v5 and standard go test. Exact
module versions/checksums belong to `data/go.mod` and `data/go.sum`:

| Module | Version | License | Purpose |
| --- | --- | --- | --- |
| [fsnotify](https://github.com/fsnotify/fsnotify/tree/v1.10.1) | 1.10.1 | BSD-3-Clause | Linux filesystem invalidations |
| [godbus/dbus](https://github.com/godbus/dbus/tree/v5.2.2) | 5.2.2 | BSD-2-Clause | Typed systemd calls and signals |
| [x/sys](https://cs.opensource.google/go/x/sys/+/v0.27.0:LICENSE) | 0.27.0 | BSD-3-Clause | Linux peer credentials and socket locking |

Modules are checksum-pinned dependencies, not copied source. Upgrades require
the race-enabled suite, actual inotify/socket/D-Bus integration and review of
signal delivery and cancellation semantics. Go 1.27.1 was used for validation;
the module requires Go 1.27.0+. No QML donor is accepted or copied.

## Plan 005 presentation decision: own Qt Quick Controls composition

The owner selected option 1 below and reiterated that the system supports themes.
Use project-owned layouts and upstream Qt controls, with semantic palette inputs
from the existing theme renderer. Do not vendor FocusRing or the rejected donors.
The comparison below records the inspected alternatives, not implementation paths.

Inspected DMS v1.6.1 (`aa4b99def48637d86a69620c0a8f3cc6aa0c4092`)
and Omarchy v4.0.3 (`0534987009061cbe2dacdde4ad564092ab698d12`).
DMS's public `Widgets/DankButton.qml` is a forwarding wrapper: its actual source
comes from the `dank-qml-common` submodule at
`26396ce432d6c71c3f5367438f96f4a8d667e160`. Pinning only the wrapper would miss
the dependency being reused.

Two viable scopes for this project-specific window:

1. **Own composition using Qt Quick Controls — recommended.** Use upstream
   Button/ItemDelegate/TextField/ScrollView with project-owned layouts and semantic
   palette inputs. Imports: QtQuick, QtQuick.Controls, QtQuick.Layouts and
   Quickshell's window/socket APIs. No shell services, theme singleton or donor
   timer. Model inputs and action signals conform directly to API.md; hidden
   panels release subscriptions. Qt stays a native package dependency, with no
   Qt source vendored. Qt Quick Controls offers LGPL-3.0/GPL-2.0/commercial
   licensing; project-owned presentation remains repository source. Keyboard,
   accessibility and scaled-text behavior still require real UI checks.
   [Qt module and licensing](https://doc.qt.io/qt-6/qtquickcontrols-index.html).
2. **The same composition, narrowly adapting DMS FocusRing.** Its twelve-line
   rectangle supplies a visible focus outline and genuinely fits keyboard-focused
   project/agent actions. MIT, Avenge Media LLC; imports QtQuick and
   `qs.DankCommon.Common`. Its only singleton use is `Style.primary`; implicit
   inputs are the parent's radius and activeFocus. Replace those with explicit
   color/radius/focused properties, retaining outline geometry locally. No
   services, backend access, animations or polling timers. Vendor the single
   adapted file with copyright/license and pinned upstream URL; manually review
   upstream diffs when changing it. Do not import the DMS common module. This is
   clean reuse but saves very little code, so it is optional rather than a reason
   to adopt a component library.
   [Exact FocusRing source](https://github.com/AvengeMedia/dank-qml-common/blob/26396ce432d6c71c3f5367438f96f4a8d667e160/DankCommon/Widgets/FocusRing.qml),
   [MIT license](https://github.com/AvengeMedia/dank-qml-common/blob/26396ce432d6c71c3f5367438f96f4a8d667e160/LICENSE).

Rejected as donors for this window, rather than treating large rewrites as reuse:

- **DMS DankButton**, MIT, imports QtQuick plus DankCommon Common/Widgets.
  Direct dependencies: Style, FocusRing, DankRipple, DankIcon and StyledText;
  StyledText also references Appearance. Its theme/animation/font/icon graph
  exceeds the useful button behavior. No backend polling in the inspected button,
  but state/ripple animations need visibility discipline. Untangling the complete
  graph and supplying accessibility would cost more than styling Qt's control.
  [Button](https://github.com/AvengeMedia/dank-qml-common/blob/26396ce432d6c71c3f5367438f96f4a8d667e160/DankCommon/Widgets/DankButton.qml),
  [text dependency](https://github.com/AvengeMedia/dank-qml-common/blob/26396ce432d6c71c3f5367438f96f4a8d667e160/DankCommon/Widgets/StyledText.qml).
- **Omarchy Button**, MIT: QtQuick/QtQuick.Controls/qs.Commons imports;
  BorderSurface, Border, Color and Style implement its configurable border/theme
  machinery. No data timer; optional infinite icon rotation must stop hidden.
  Replacing that machinery for our palette would rewrite much of the component.
  **PopupCard** additionally imports Quickshell.Hyprland, requires a bar and
  anchorItem, calls requestPopout/releasePopout, and assumes bar-edge placement.
  It is a poor match for this standalone window. Neither should be vendored here.
  [Button](https://github.com/omacom/omarchy/blob/v4.0.3/shell/Ui/Button.qml),
  [PopupCard](https://github.com/omacom/omarchy/blob/v4.0.3/shell/Ui/PopupCard.qml),
  [license](https://github.com/omacom/omarchy/blob/v4.0.3/LICENSE).

The project/agent rows remain owned presentation in either viable choice: the
inspected donors do not supply this domain model. This decision covers Plan 005
only; later panels evaluate their own concrete donors at execution time.

## Plan 005 QML testing choice: Qt Quick Test selected

Native availability verified: Arch Extra provides Quickshell 0.3.1-1, depending
on qt6-declarative. The latter supplies `/usr/lib/qt6/bin/qmllint`,
`/usr/lib/qt6/bin/qmltestrunner` and QtTest. The owner selected Qt Quick Test.
Qt 6.2.4 tooling was installed into the WSL validation environment; blendOS
already provides Qt 6.11.2. The component suite passes on both. Native Quickshell
is declared alongside qt6-declarative in system.yaml.

1. **Qt Quick Test — recommended.** Use the packaged qmltestrunner/QtTest for
   isolated presentation components: keyboard/mouse input, emitted intents,
   asynchronous assertions, theme changes, empty/error states and scaled text.
   Run component cases offscreen, with a separate real Quickshell launch/render
   check in blendOS for its window, socket and theme integration. Qt's maintained
   runner supplies assertions, cleanup and image capture; project tests remain
   QML with no new C++ test runner. LGPL-3.0/GPL-2.0/commercial licensing.
2. **Project-owned QML fixture assertions.** Run a dedicated fixture under
   Quickshell, drive exposed fixture actions and verify screenshots/results with
   repository scripts. This avoids QtTest and directly exercises the Quickshell
   runtime, but requires maintaining assertion/cleanup code and provides weaker
   automatic keyboard/focus coverage unless we add input-driving machinery.
   Existing qmllint and real blendOS rendering checks are still required.

The selected runner tests input, intents, theme propagation and layout offscreen.
Pixel evidence comes from the separate real Quickshell render check: Qt 6.2's
offscreen setup returned empty grabImage results. No empty capture is accepted
as render proof. The second option above records the rejected alternative.
[Quickshell package](https://archlinux.org/packages/extra/x86_64/quickshell/),
[Qt package files](https://archlinux.org/packages/extra/x86_64/qt6-declarative/files/),
[Qt Quick Test](https://doc.qt.io/qt-6/qtquicktest-index.html),
[TestCase input and image APIs](https://doc.qt.io/qt-6/qml-qttest-testcase.html).

## Plan 008 launcher decision: Quickshell UI over Elephant

The owner selected a project-owned Quickshell launcher surface over Elephant's
existing provider/index family. Elephant remains source-built as one
version-aligned core/provider set; Walker remains installed for the separate
utility jobs that still use its presentation. No second application index or
new search provider is introduced.

### Inspected alternatives

1. Native Quickshell `DesktopEntries` plus an original ranking model would
   avoid a protocol bridge, but would discard Elephant's file watchers,
   fuzzy scoring, history and provider coverage. Quickshell's native
   `DesktopEntry.execute()` also does not safely expand `Terminal=true` and
   desktop-entry field codes, so it still needs a separate activation owner.
2. **Selected: Quickshell rows with a bounded Elephant adapter.** Elephant
   v2.22.0's framed JSON mode provides provider queries and cancellation while
   the project adapter exposes the stable JSON rows required by the shell.
   Typed app activation goes through `uwsm app`; file and calculator actions
   use literal argv. This keeps backend objects out of QML and retains
   Elephant's ranking/file index at the cost of one small protocol boundary.
3. Retaining Walker's application surface would minimize new UI but would
   duplicate the Island entry point and keep application activation coupled to
   Elephant's shell-based provider activator. It remains selected only for
   clipboard, symbols, windows, menus/capture and shortcut selection.

### Pin, license and protocol boundary

The inspected Elephant release is v2.22.0 at commit
`8e77c59ca5b7fd28c0a168535f1a1c000e6b5389`, GPL-3.0:
[repository](https://github.com/abenz1267/elephant), [query handler](https://github.com/abenz1267/elephant/blob/8e77c59ca5b7fd28c0a168535f1a1c000e6b5389/internal/comm/handlers/queryrequesthandler.go),
[activation handler](https://github.com/abenz1267/elephant/blob/8e77c59ca5b7fd28c0a168535f1a1c000e6b5389/internal/comm/handlers/activationrequesthandler.go),
and [protocol definitions](https://github.com/abenz1267/elephant/tree/8e77c59ca5b7fd28c0a168535f1a1c000e6b5389/pkg/pb).
The core accepts framed JSON query/activation requests and returns bounded
item frames; the project adapter consumes only query frames and intentionally
does not call Elephant's shell-based activation paths. It owns no provider
index, history file, timer or search ranking.

The bridge's unit/socket is project-owned source, built with the existing Go
module and deployed by `install.sh`; no external library or donor code is
vendored. Update the pin and this record together, verify every Elephant
provider package reports the same upstream version, and rerun the frame,
cancellation, literal-activation and installed launcher checks. A protocol
change fails closed as an unavailable/invalid response rather than falling
back to a second launcher.

## Plan 007 selected audio-label reuse

Plan 007's owner-approved reuse is limited to three functions from Omarchy
Quattro: `friendlyDeviceLabel`, `nodeProps` and `nodeLabel`. They live in
[`AudioLabels.js`](../../.config/quickshell/workstation/models/AudioLabels.js).
All control surfaces, rows, adapters and lifecycle integration are original
project source. No donor shell, panel, stream matching, glyph selection,
availability parser or volume classification was imported.

### Pin and license

Source repository: [omacom/omarchy](https://github.com/omacom/omarchy).
Inspected commit: `0534987009061cbe2dacdde4ad564092ab698d12`.

- [Audio model](https://github.com/omacom/omarchy/blob/0534987009061cbe2dacdde4ad564092ab698d12/shell/plugins/panels/audio/Model.js)
- [Audio model tests](https://github.com/omacom/omarchy/blob/0534987009061cbe2dacdde4ad564092ab698d12/test/shell.d/audio-test.sh)
- [MIT license](https://github.com/omacom/omarchy/blob/0534987009061cbe2dacdde4ad564092ab698d12/LICENSE)

The selected functions were inspected with `git show` at this exact commit.
The full upstream copyright and permission notice is retained in the managed
JavaScript file. Formatting is adapted to the local source; behavior remains
the selected label normalization, property-readiness guard and label fallback.
Focused Qt tests cover the two relevant upstream examples and additional null,
unready-property and nickname precedence cases; the upstream test harness and
unselected tests were not copied.

### Coupling and maintenance

These functions import nothing, start no services, read no files, use no timers
and know no theme tokens or Omarchy commands. They accept node-like data:
`nodeProps` uses properties only when `ready`; `nodeLabel` chooses nickname,
device-profile description, description or name. Native PipeWire tracking and
node lifetime remain the project's adapter responsibility. Device identity is
the backend ID, never the cleaned label.

The full [Quattro audio panel](https://github.com/omacom/omarchy/blob/0534987009061cbe2dacdde4ad564092ab698d12/shell/plugins/panels/audio/Panel.qml)
was rejected: its host/theme modules, Omarchy helper calls, native node ownership
and refresh timers would require substantial replacement. The inspected DMS
[audio row](https://github.com/AvengeMedia/DankMaterialShell/blob/aa4b99def48637d86a69620c0a8f3cc6aa0c4092/quickshell/Modules/ControlCenter/Widgets/AudioSliderRow.qml)
and input/port companions couple presentation to global audio/theme/session
services, donor widgets and direct native mutation. Replacing those dependencies
with explicit snapshots and intents would remove most of their useful source.
Neither donor's panel, row, service or common-widget module is included.

This is a vendored three-function adaptation with manual updates, not a live
dependency or tracked upstream checkout. To update, inspect those functions,
their relevant tests and the license at a new explicit commit; preserve this
boundary, update the pin/notice, and rerun the focused Qt and native audio
checks. Any expansion beyond these three functions needs the normal owner
reuse decision. Replacing them costs only the label helper and its small tests.

## Plan 007 native output focus

Use the existing `Hyprland.focusedMonitor` identity for output focus. At inspected
Quickshell commit `1a4716cde794a59928d9d9fc15f2afc7a95de360` (also checked against
v0.3.1), [`monitor.cpp`](https://github.com/quickshell-mirror/quickshell/blob/1a4716cde794a59928d9d9fc15f2afc7a95de360/src/wayland/hyprland/ipc/monitor.cpp#L16)
installs the per-monitor focus binding only through `updateInitial`, while the
[`refresh path`](https://github.com/quickshell-mirror/quickshell/blob/1a4716cde794a59928d9d9fc15f2afc7a95de360/src/wayland/hyprland/ipc/connection.cpp#L828)
can create a startup monitor through `updateFromObject` alone. The canonical
focused-monitor pointer is still updated and exposed with native change signals.
The project compares that pointer with each monitor in its adapter; no upstream
code is copied or patched, and no polling or JSON failure route is added.

## Plan 009 Option 1 Dunst audit

The owner-selected notification owner is Dunst v1.13.2. The signed tag resolves
to commit 312ed56fbcdc84823c99f21008467561394a8eb1:
[Dunst v1.13.2](https://github.com/dunst-project/dunst/tree/v1.13.2).
The audited source is BSD-3-Clause
([license](https://github.com/dunst-project/dunst/blob/v1.13.2/LICENSE)).
No Dunst source is vendored.

The source audit covered Dunst's src/dbus.c and its dunstctl documentation.
Dunst owns org.freedesktop.Notifications at
/org/freedesktop/Notifications and exposes its project control interface as
org.dunstproject.cmd0 on that path. The audited interface provides
NotificationListHistory (aa{sv}), NotificationPopHistory,
NotificationRemoveFromHistory, NotificationClearHistory,
NotificationCloseAll, NotificationShow and NotificationAction. Its readable
properties include paused, pauseLevel, displayedLength, historyLength and
waitingLength. History and state changes emit
NotificationHistoryRemoved, NotificationHistoryCleared and
org.freedesktop.DBus.Properties.PropertiesChanged.

NotificationListHistory returns body, message, summary, appname, category,
default_action_name, icon_path, id, timestamp, timeout, progress, urgency,
stack_tag and urls. The project adapter will consume only the bounded
user-facing text and safe state fields. It will omit icon_path and urls, treat
body as plain text, convert the Dunst timestamp to UTC RFC3339 and expose
closed-history actions as an empty list. Dunst invalidates live action data
when a notification closes, so the Island history card must not invent action
labels or invoke arbitrary history content; live popup actions remain Dunst's
responsibility.

This reuse has no QML donor, theme singleton, project-owned D-Bus service or
new timer. The existing workstation-data service uses its already selected
godbus/v5 dependency to subscribe to Dunst signals and read history only when
the shell has a notifications subscriber. Dunst stays attached to
blendos-workstation-session.target; the Island card owns the Super+N history
presentation while dunstctl remains the live popup close/pause boundary. The
necessary change is a narrow protocol adapter plus explicit Island
inputs/intents, not a Dunst fork or copied UI. Future updates must re-audit the
tag, D-Bus fields, action invalidation and the history_length bound; installed
and visual checks remain required.

## Plan 010 identity and login decision

The owner selected `greetd` as the sole graphical-login owner and a small
project-owned Quickshell greeter hosted by an isolated Hyprland process. The
greeter uses Quickshell's native `Quickshell.Services.Greetd` API for
`createSession`, `respond` and `launch`; it does not implement PAM or create a
second session boundary. Successful handoff launches the sole UWSM
`workstation.desktop` entry, and the greeter host tears down its compositor
after the handoff. The Arch package's PAM file, system unit and dedicated
`greeter` account are used as shipped rather than replaced by a custom login
stack.

The presentation is original project source. `WorkstationShared/AuthForm.qml`
is shared with the independent locker through explicit properties and signals;
the pre-login controller and `GreeterView.qml` remain separate so the locker
cannot become a login/session owner. The public greeter palette is a filtered
projection of the existing Catppuccin semantic theme manifest, with dark/light
mark variants. It is installed as a system-readable bundle during normal
provisioning; no private user theme release, desktop configuration, service
graph or persistent account state is exposed to the greeter.

The isolated host has a dedicated VirtualBox-only monitor/software-rendering
profile. Physical machines use the neutral profile and never receive the
guest renderer overrides. The host, UI wrapper and compositor configurations
are maintained here under `services/desktop/identity/`; updates must preserve
the bounded host cleanup, the native greetd API boundary, the exact UWSM
handoff, and the public-palette projection. SDDM, Ly, ReGreet, Noctalia Greeter,
Cage and a custom PAM engine were rejected for this plan. A future Smithay/Cage
host is a deferred infrastructure choice, not an interchangeable greeter
dependency.

[Quickshell Greetd API](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Greetd/Greetd/),
[greetd package files](https://archlinux.org/packages/extra/x86_64/greetd/files/),
[greetd configuration manual](https://man.archlinux.org/man/greetd.5.en).
