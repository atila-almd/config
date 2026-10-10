import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import WorkstationShared 1.0

Pane {
    id: root
    required property var rows
    required property string status
    required property string projectId
    required property bool canLaunch
    required property bool busy
    property string inputError: ""
    property color mutedText: palette.windowText
    signal launchAgent(string projectId, var argv)
    padding: 16
    ColumnLayout {
        anchors.fill: parent
        Label { text: "Agent runs"; font.bold: true; font.pixelSize: root.font.pixelSize * 1.4 }
        Label {
            Layout.fillWidth: true
            text: root.status !== "ready" ? root.status : root.rows.length ? "Measured process usage" : "No recorded runs."
            wrapMode: Text.Wrap
        }
        ListView {
            objectName: "agentList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.rows
            activeFocusOnTab: true
            ScrollBar.vertical: ScrollBar {}
            delegate: ItemDelegate {
                id: runRow
                required property var modelData
                width: ListView.view.width
                contentItem: Label {
                    text: runRow.modelData.label + " · " + runRow.modelData.state
                        + "\n" + runRow.modelData.id + " · " + runRow.modelData.started_at
                        + "\nMemory: " + Contract.bytes(runRow.modelData.memory_bytes)
                        + " · Peak: " + Contract.bytes(runRow.modelData.max_rss_bytes)
                        + "\nCPU: " + (runRow.modelData.cpu_usage_ns === null ? "Unavailable" : (Number(runRow.modelData.cpu_usage_ns) / 1e9).toFixed(2) + " s")
                        + " · Exit: " + (runRow.modelData.exit_status === null ? "Unavailable" : runRow.modelData.exit_status)
                        + "\nElapsed: " + (runRow.modelData.wall_seconds === null ? "Unavailable" : runRow.modelData.wall_seconds + " s")
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                }
            }
        }
        Label { text: root.projectId ? "Launch in " + root.projectId : "Select an available project to launch"; Layout.fillWidth: true; wrapMode: Text.Wrap }
        TextField {
            id: argumentInput
            objectName: "agentArguments"
            Layout.fillWidth: true
            placeholderText: '["codex", "--help"]'
            placeholderTextColor: root.mutedText
            Accessible.name: "Command arguments as a JSON array"
            selectByMouse: true
            onTextEdited: root.inputError = ""
        }
        Label { text: "Enter command and arguments as a JSON array of strings."; Layout.fillWidth: true; wrapMode: Text.Wrap }
        Label { text: root.inputError; visible: text.length > 0; Layout.fillWidth: true; wrapMode: Text.Wrap }
        Button {
            objectName: "launchAgent"
            text: root.width < 700 ? "Launch agent" : "Launch agent in terminal"
            Accessible.name: "Launch agent in terminal"
            enabled: root.canLaunch && !root.busy
            onClicked: {
                try {
                    var argv = Contract.argv(argumentInput.text);
                    root.inputError = "";
                    root.launchAgent(root.projectId, argv);
                    argumentInput.clear();
                } catch (error) { root.inputError = "Enter a nonempty JSON array of strings, starting with the command."; }
            }
        }
    }
}
