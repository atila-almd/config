import QtQuick
import "../models/IslandMotion.js" as Motion

Item {
    id: root
    property string text: "00:00"
    property real speed: 1
    property bool reduceMotion: false
    property color color: "white"
    property real pixelSize: 15
    property string family: "JetBrainsMono Nerd Font"
    implicitWidth: clockRow.implicitWidth
    implicitHeight: pixelSize * 1.25

    Row {
        id: clockRow
        anchors.fill: parent
        spacing: 0
        Repeater {
            model: root.text.length
            delegate: Item {
                id: digitCell
                required property int index
                property string incoming: root.text.charAt(index)
                property string visibleDigit: incoming
                property string previousDigit: incoming
                property bool rolling: false
                width: digitText.implicitWidth
                height: root.height
                clip: true

                Component.onCompleted: {
                    visibleDigit = incoming;
                    previousDigit = incoming;
                }
                onIncomingChanged: {
                    if (incoming === visibleDigit) return;
                    previousDigit = visibleDigit;
                    visibleDigit = incoming;
                    rolling = false;
                    if (root.reduceMotion) {
                        // Do not leave the old glyph covering the new one.
                        previousDigit = incoming;
                    } else {
                        Qt.callLater(function() { digitCell.rolling = true; });
                    }
                }
                Text {
                    id: oldDigit
                    width: parent.width
                    height: parent.height
                    text: digitCell.previousDigit
                    y: digitCell.rolling ? -height : 0
                    opacity: digitCell.rolling ? 0 : 1
                    color: root.color
                    font.family: root.family
                    font.pixelSize: root.pixelSize
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    Behavior on y { NumberAnimation { duration: Motion.duration(Motion.rollingDigits.duration, root.speed, root.reduceMotion); easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Motion.duration(Motion.rollingDigits.duration, root.speed, root.reduceMotion); easing.type: Easing.OutCubic } }
                }
                Text {
                    id: digitText
                    width: parent.width
                    height: parent.height
                    text: digitCell.visibleDigit
                    y: digitCell.rolling ? 0 : height
                    opacity: digitCell.rolling ? 1 : 0
                    color: root.color
                    font.family: root.family
                    font.pixelSize: root.pixelSize
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    Behavior on y { NumberAnimation { duration: Motion.duration(Motion.rollingDigits.duration, root.speed, root.reduceMotion); easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Motion.duration(Motion.rollingDigits.duration, root.speed, root.reduceMotion); easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
