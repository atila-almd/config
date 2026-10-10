import QtQuick
import QtQuick.Controls
import "../models/IslandMotion.js" as Motion

Slider {
    id: root
    required property var islandPalette
    property bool reduceMotion: false

    implicitHeight: 28

    background: Rectangle {
        x: 0
        y: root.height / 2 - height / 2
        width: root.width
        height: 6
        radius: 3
        color: Qt.rgba(root.islandPalette.surfaceAlt.r, root.islandPalette.surfaceAlt.g,
            root.islandPalette.surfaceAlt.b, 0.75)
        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: root.islandPalette.accent
        }
    }

    handle: Rectangle {
        x: root.visualPosition * (root.width - width)
        y: root.height / 2 - height / 2
        width: 14
        height: 14
        radius: 7
        color: root.islandPalette.foreground
        border.width: 2
        border.color: root.islandPalette.accent
        scale: root.pressed ? 0.96 : (root.hovered ? 1.06 : 1)
        Behavior on scale {
            SpringAnimation {
                spring: Motion.spring(Motion.press, root.islandPalette.speed, root.reduceMotion)
                damping: Motion.damping(Motion.press, root.reduceMotion)
                mass: Motion.press.mass
            }
        }
    }
}
