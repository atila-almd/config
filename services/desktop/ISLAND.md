# Island

Island is the managed Quickshell shell at
.config/quickshell/workstation/. It is one per output, with one shared state
machine and one shared scheduler. Compact, activity, attention, split,
expanded and dashboard are geometry/content modes of the same island surface.

## Run and trigger it

The session owner is workstation-shell.service; it starts through
blendos-workstation-session.target.

~~~
systemctl --user start workstation-shell.service
session-workstation-shell --dashboard
session-workstation-shell --toggle
session-workstation-shell --launcher
session-workstation-shell --card volume
session-workstation-shell --card timer
session-workstation-shell --debug compact
session-workstation-shell --debug activity-media
session-workstation-shell --debug activity-timer
session-workstation-shell --debug attention
session-workstation-shell --debug split
session-workstation-shell --debug expanded
session-workstation-shell --debug dashboard
session-workstation-shell --layout grouped
session-workstation-shell --layout spread
session-workstation-shell --layout one
~~~

The compositor bindings are Super+R and Super+Space for the launcher, Super+D
for the dashboard, Super+Shift+T for the timer and Super+Escape for the power
card. Launcher rows come from Elephant through the project-owned
`workstation-launcher.service` adapter. Walker and Elephant remain the
authoritative presentation/backend for the distinct clipboard, symbols,
windows, utility-menu, capture and shortcut selection jobs; Dunst owns
notification history. Plan 009 Option 1 exposes Dunst's bounded history
through the existing workstation-data service and this Island surface. The
card subscribes lazily and sends validated mutations back through
workstation-controls; Dunst remains the live popup/action owner.

The native IPC target is island:

~~~
qs -c workstation ipc call -- island status
qs -c workstation ipc call -- island debug split
qs -c workstation ipc call -- island card performance
session-workstation-shell --card notifications
qs -c workstation ipc call -- island collapse
~~~

panel and controls IPC names remain compatibility aliases for existing menus
and helpers. They resolve to Island dashboard/cards rather than opening the
retired panel or control-center windows.

## Live configuration

The single live configuration file is
CONFIG_HOME/quickshell/workstation/island.json, where CONFIG_HOME is
XDG_CONFIG_HOME when set and HOME/.config otherwise. The file watcher applies
changes without restarting the shell.

Supported values include:

~~~
{
  "layout": "grouped",
  "theme_mode": "auto",
  "enabled_widgets": ["media", "volume", "calendar", "timer"],
  "widget_order": ["media", "volume", "calendar", "timer"],
  "animation_speed": 1.0,
  "reduce_motion": false,
  "bar_height": 40,
  "top_margin": 8,
  "dashboard_width": 860,
  "text_scale": 1.0
}
~~~

grouped, spread and one are animated layout targets. auto follows the mode of
the active semantic theme release; light and dark override it. The existing
theme pipeline exposes semantic mode but no wallpaper-luminance or wallpaper
pixel source, so auto cannot derive a new mode from wallpaper brightness. The
semantic release watcher crossfades palette and glass-material properties
instead of replacing the visible palette object.

## Available sources

- Launcher: the Island launcher searches Elephant's applications, files,
  calculator and web-search providers. Prefix `/` selects files, `=` selects
  calculations and `@` selects web search. Search rows are lazy and bounded;
  hidden launcher content closes its adapter query.

- Media: native MPRIS metadata and transport through the existing media
  adapter/helper. The activity island shows album art when the player supplies
  an art URL.
- Volume: PipeWire node state and the existing validated wpctl control
  contract.
- Attention/OSD: the existing Island attention surface presents native
  volume and microphone feedback with one shared deadline owner; no standalone
  OSD package or widget timer is selected.
- Battery: /sys/class/power_supply facts when a real battery is present.
  Desktop systems without a battery do not receive a battery icon/card.
- Calendar: the month grid and today marker are shell-owned; event dots are
  omitted because no calendar source is managed here.
- Performance: one shared /proc sampler for CPU, memory, load and uptime.
- Tasks: private shell-owned JSON under the user state directory.
- Timer: internal shell state, with the same countdown ring in the card and
  activity island.
- Recorder: the existing workstation-record/wf-recorder region flow.
- System info: basic hostname, blendOS, Hyprland and uptime facts.
- Workspaces/tray: native Hyprland and StatusNotifier subscriptions.
- Projects/agents: the existing workstation-data socket and project helper.
- Power: the existing validated lock, suspend, logout, reboot and shutdown
  owners. Destructive actions require a second confirmation click.

## Intentionally skipped

No fake cards or placeholder data are created for unavailable capabilities.

- Wi-Fi: only wired NetworkManager facts are available in the current backend;
  Wi-Fi support is not enabled in system.yaml.
- Bluetooth: no existing Quickshell/backend control source is enabled.
- Weather: no local weather source exists.
- Claude Code usage: no readable local usage contract is present.
- GitHub contributions: no configured token/network source is present.
- Virtual pet: no existing state or asset source is present.
- Island notification center: the Plan 009 Option 1 card exposes bounded Dunst
  history, DND, Show, Dismiss and Clear actions. It loads only while open;
  closed-row actions remain empty because Dunst invalidates them. `Super+N`
  opens the card, while Dunst still owns live popup actions.
- Screenshot attention: the existing capture helper has no event stream for
  completed captures, so screenshots remain on their existing keybindings.
- AI answers and account-backed search: no provider is selected for this plan;
  adding one requires an explicit owner decision about local/remote execution,
  credentials and lifecycle.
- Workspaces window thumbnails: native workspace/window titles and urgency are
  available; a capturable thumbnail source is not.
- Wallpaper-driven auto luminance: the existing wallpaper owner exposes no
  luminance/pixel contract to Quickshell, so auto follows the semantic theme
  release mode rather than inventing a wallpaper sampler.
- Media scrubbing: the existing validated helper exposes transport but not a
  seek contract, so the card does not pretend a seek action succeeded.
- Recorder source/window/screen segmentation: the existing helper only provides
  interactive region selection, so the card exposes Region only.

Skipped capabilities leave no icon, tab or empty dashboard tile. Dashboard
tabs are limited to Dashboard, Media, Performance and Workspaces because those
are the surviving tab sources.
