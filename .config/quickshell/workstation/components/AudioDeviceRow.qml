import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var device
    property bool isDefault: false
    property bool busy: false
    signal volumeRequested(real volume)
    signal muteRequested(bool muted)
    signal defaultRequested()
    spacing: 8
    readonly property bool usable: device.available === true && !busy
    Label {
        Layout.fillWidth: true
        text: root.device.label || "Unnamed device"
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        font.bold: true
    }
    Label {
        Layout.fillWidth: true
        text: root.device.volume === null ? "Volume unavailable" : "Volume " + Math.round(root.device.volume * 100) + "%"
        textFormat: Text.PlainText
    }
    Slider {
        id: volume
        objectName: "audioVolume-" + root.device.id
        Layout.fillWidth: true
        from: 0; to: 1; stepSize: 0.01
        enabled: root.usable && root.device.volume !== null
        visible: root.device.volume !== null
        value: root.device.volume === null ? 0 : root.device.volume
        Accessible.name: "Volume for " + root.device.label
        function submit() {
            if (enabled) root.volumeRequested(value);
            // User manipulation can replace a binding. Reinstall it even when
            // the request fails and the authoritative snapshot stays unchanged.
            value = Qt.binding(function() { return root.device.volume === null ? 0 : root.device.volume; });
        }
        onPressedChanged: if (!pressed) submit()
        onMoved: if (!pressed) submit()
    }
    Flow {
        Layout.fillWidth: true
        spacing: 8
        Button {
            objectName: "audioMute-" + root.device.id
            text: root.device.muted === null ? "Mute unavailable" : root.device.muted ? "Unmute" : "Mute"
            enabled: root.usable && root.device.muted !== null
            Accessible.name: text + " " + root.device.label
            onClicked: root.muteRequested(!root.device.muted)
        }
        Button {
            objectName: "audioDefault-" + root.device.id
            text: root.isDefault ? "Default device" : "Use as default"
            enabled: root.usable && !root.isDefault
            onClicked: root.defaultRequested()
        }
    }
}
