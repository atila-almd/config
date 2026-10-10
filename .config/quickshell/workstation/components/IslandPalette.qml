import QtQuick
import "../models/IslandMotion.js" as Motion

// Individual color properties let ColorAnimation interpolate an atomic theme
// release instead of replacing an object and flashing the whole shell.
Item {
    id: root
    required property var source
    required property bool dark
    property real speed: 1
    visible: false
    width: 0
    height: 0

    property color accent: source && source.accent ? source.accent : "#89b4fa"
    property color selection: source && source.selection ? source.selection : "#45475a"
    property color muted: source && source.muted ? source.muted : "#6c7086"
    property color background: source && source.background ? source.background : "#1e1e2e"
    property color backgroundAlt: source && source.background_alt ? source.background_alt : "#181825"
    property color surface: source && source.surface ? source.surface : "#313244"
    property color surfaceAlt: source && source.surface_alt ? source.surface_alt : "#45475a"
    property color foreground: source && source.foreground ? source.foreground : "#cdd6f4"
    property color foregroundMuted: source && source.foreground_muted ? source.foreground_muted : "#a6adc8"
    property color red: source && source.red ? source.red : "#f38ba8"
    property color orange: source && source.orange ? source.orange : "#fab387"
    property color yellow: source && source.yellow ? source.yellow : "#f9e2af"
    property color green: source && source.green ? source.green : "#a6e3a1"
    property color cyan: source && source.cyan ? source.cyan : "#94e2d5"
    property color blue: source && source.blue ? source.blue : "#89b4fa"
    property color magenta: source && source.magenta ? source.magenta : "#cba6f7"

    property color glassFill: dark ? Qt.rgba(0.035, 0.045, 0.075, 0.78) : Qt.rgba(1, 1, 1, 0.68)
    property color glassFillRaised: dark ? Qt.rgba(0.08, 0.09, 0.14, 0.82) : Qt.rgba(1, 1, 1, 0.78)
    property color innerLight: dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.72)
    property color rim: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0.12, 0.14, 0.18, 0.16)
    property color shadow: dark ? Qt.rgba(0, 0, 0, 0.42) : Qt.rgba(0.12, 0.16, 0.24, 0.18)

    Behavior on accent { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on selection { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on muted { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on background { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on backgroundAlt { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on surface { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on surfaceAlt { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on foreground { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on foregroundMuted { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on red { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on orange { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on yellow { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on green { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on cyan { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on blue { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on magenta { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on glassFill { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on glassFillRaised { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on innerLight { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on rim { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
    Behavior on shadow { ColorAnimation { duration: Motion.duration(Motion.theme.duration, root.speed, false) } }
}
