import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    required property var palette
    property string glyph: "•"
    property string title: ""
    property string subtitle: ""
    property string value: ""
    signal clicked()
    spacing: 10
    implicitHeight: 42

    Text {
        text: root.glyph
        color: root.palette.accent
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 22
        font.bold: true
        Layout.preferredWidth: 28
        horizontalAlignment: Text.AlignHCenter
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1
        Text {
            text: root.title
            color: root.palette.foreground
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Text {
            text: root.subtitle
            color: root.palette.foregroundMuted
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
    Text {
        visible: root.value.length > 0
        text: root.value
        color: root.palette.foreground
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        font.bold: true
        Layout.alignment: Qt.AlignTop
    }
    TapHandler { onTapped: root.clicked() }
}
