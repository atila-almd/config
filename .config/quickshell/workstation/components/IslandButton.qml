import QtQuick
import "../models/IslandMotion.js" as Motion

Item {
    id: root
    required property var palette
    property string text: ""
    property string glyph: ""
    property bool active: false
    property bool destructive: false
    property real minimumWidth: 44
    property real buttonHeight: 34
    signal clicked()

    implicitWidth: Math.max(root.minimumWidth, label.implicitWidth + (root.glyph.length ? 36 : 24))
    implicitHeight: root.buttonHeight
    opacity: root.enabled ? 1 : 0.38
    scale: tap.pressed ? 0.96 : (hover.hovered ? 1.02 : 1)

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: root.active ? Qt.rgba(root.palette.accent.r, root.palette.accent.g, root.palette.accent.b, 0.24)
            : Qt.rgba(root.palette.surface.r, root.palette.surface.g, root.palette.surface.b, 0.32)
        border.width: root.active ? 1 : 0
        border.color: root.destructive ? root.palette.red : root.palette.accent
    }
    Row {
        anchors.centerIn: parent
        spacing: 7
        Text {
            visible: root.glyph.length > 0
            text: root.glyph
            color: root.destructive ? root.palette.red : root.palette.foreground
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
        }
        Text {
            id: label
            text: root.text
            color: root.destructive ? root.palette.red : root.palette.foreground
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
        }
    }
    HoverHandler { id: hover }
    TapHandler { id: tap; enabled: root.enabled; onTapped: root.clicked() }
    Behavior on scale {
        SpringAnimation {
            spring: Motion.spring(Motion.press,
                root.palette && root.palette.speed ? root.palette.speed : 1, false)
            damping: Motion.damping(Motion.press, false)
            mass: Motion.press.mass
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
