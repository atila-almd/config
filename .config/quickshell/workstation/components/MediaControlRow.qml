import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Qt 6.2 fixture support predates ComponentBehavior: Bound.
// qmllint disable unqualified
ColumnLayout {
    id: root
    required property var player
    property bool busy: false
    signal transportRequested(string action)
    Label {
        Layout.fillWidth: true
        text: root.player.label
        textFormat: Text.PlainText
        font.bold: true
        wrapMode: Text.Wrap
    }
    Label {
        Layout.fillWidth: true
        text: (root.player.title || "Title unavailable") + (root.player.artist ? " · " + root.player.artist : "")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    Label { text: root.player.state; textFormat: Text.PlainText }
    Flow {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: [{action:"previous",label:"Previous"},{action:"play",label:"Play"},{action:"pause",label:"Pause"},{action:"next",label:"Next"}]
            delegate: Button {
                required property var modelData
                objectName: "media-" + modelData.action + "-" + root.player.id
                text: modelData.label
                enabled: !root.busy && root.player["can_" + modelData.action] === true
                onClicked: root.transportRequested(modelData.action)
            }
        }
    }
}
