import QtQuick
import "../models/IslandMotion.js" as Motion

Item {
    id: root
    property string glyph: "•"
    property string label: ""
    property color color: palette ? palette.foreground : "white"
    property var palette: null
    property bool active: false
    property bool alert: false
    property real iconSize: 18
    property bool hovered: hover.hovered
    signal clicked()
    signal wheelAdjusted(real delta)

    implicitWidth: Math.max(28, iconSize + 10)
    implicitHeight: Math.max(28, iconSize + 10)
    opacity: root.enabled ? 1 : 0.35
    scale: pressed ? 0.96 : (hover.hovered ? 1.06 : 1)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.active ? Qt.rgba(root.palette.accent.r, root.palette.accent.g, root.palette.accent.b, 0.22) : "#00000000"
        border.width: root.active ? 1 : 0
        border.color: root.palette.accent
    }
    Text {
        anchors.centerIn: parent
        text: root.glyph
        color: root.alert ? root.palette.red : root.color
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: root.iconSize
        font.bold: root.active || root.alert
    }
    Rectangle {
        visible: root.alert
        width: 6
        height: 6
        radius: 3
        anchors.right: parent.right
        anchors.top: parent.top
        color: root.palette.red
        border.width: 1
        border.color: root.palette.background
    }

    property bool pressed: tap.pressed
    HoverHandler { id: hover }
    TapHandler {
        id: tap
        enabled: root.enabled
        onTapped: root.clicked()
    }
    WheelHandler {
        enabled: root.enabled
        onWheel: event => root.wheelAdjusted(event.angleDelta.y)
    }

    Behavior on scale {
        SpringAnimation {
            spring: Motion.spring(Motion.hover,
                root.palette && root.palette.speed ? root.palette.speed : 1, false)
            damping: Motion.damping(Motion.hover, false)
            mass: Motion.hover.mass
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Motion.duration(Motion.hover.duration,
                root.palette && root.palette.speed ? root.palette.speed : 1, false)
            easing.type: Easing.OutCubic
        }
    }
}
