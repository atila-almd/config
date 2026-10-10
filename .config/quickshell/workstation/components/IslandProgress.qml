import QtQuick
import QtQuick.Controls

ProgressBar {
    id: root
    required property var islandPalette
    implicitHeight: 8

    background: Rectangle {
        implicitHeight: 6
        height: 6
        radius: 3
        color: Qt.rgba(root.islandPalette.surfaceAlt.r, root.islandPalette.surfaceAlt.g,
            root.islandPalette.surfaceAlt.b, 0.75)
    }

    contentItem: Item {
        implicitHeight: 6
        Rectangle {
            width: root.visualPosition * parent.width
            height: 6
            radius: 3
            color: root.islandPalette.accent
        }
    }
}
