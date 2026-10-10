import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../surfaces"

Pane {
    id: root
    required property var colors
    required property var projects
    required property var runs
    required property string projectStatus
    required property string runStatus
    property string selectedId: ""
    property string message: ""
    property bool busy: false
    property real textScale: 1
    signal openProject(string projectId, string mode)
    signal launchAgent(string projectId, var argv)
    signal closeRequested()
    signal retryRequested()
    padding: 0
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 15 * textScale
    palette.window: colors.background
    palette.windowText: colors.foreground
    palette.base: colors.background_alt
    palette.alternateBase: colors.surface_alt
    palette.text: colors.foreground
    palette.button: colors.surface
    palette.buttonText: colors.foreground
    palette.highlight: colors.selection
    palette.highlightedText: colors.foreground
    palette.mid: colors.muted
    palette.light: colors.surface_alt
    palette.dark: colors.background_alt
    background: Rectangle { color: root.colors.background }
    focus: true
    Keys.onEscapePressed: root.closeRequested()
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 16
            Label { text: "Workstation"; font.bold: true; Layout.fillWidth: true }
            Button { text: "Reconnect"; onClicked: root.retryRequested() }
            Button { objectName: "closePanel"; text: "Close"; onClicked: root.closeRequested() }
        }
        Label {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            visible: text.length > 0
            text: root.message
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: root.width < 780 ? Qt.Vertical : Qt.Horizontal
            Projects {
                id: projectView
                SplitView.preferredWidth: 350
                SplitView.preferredHeight: 280
                SplitView.minimumWidth: 200
                SplitView.minimumHeight: 160
                rows: root.projects
                status: root.projectStatus
                busy: root.busy
                selectedId: root.selectedId
                onSelectedIdChanged: root.selectedId = selectedId
                onOpenProject: (projectId, mode) => root.openProject(projectId, mode)
            }
            AgentStatus {
                SplitView.fillWidth: true
                SplitView.fillHeight: true
                SplitView.minimumWidth: 200
                SplitView.minimumHeight: 220
                rows: root.runs
                status: root.runStatus
                projectId: root.selectedId
                busy: root.busy
                mutedText: root.colors.foreground_muted
                canLaunch: root.projectStatus === "ready" && !!projectView.selected && projectView.selected.directory_available
                onLaunchAgent: (projectId, argv) => root.launchAgent(projectId, argv)
            }
        }
    }
}
