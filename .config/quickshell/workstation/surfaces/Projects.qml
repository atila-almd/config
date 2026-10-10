import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    id: root
    required property var rows
    required property string status
    required property bool busy
    property string selectedId: ""
    readonly property var selected: rows.find(function(row) { return row.id === root.selectedId; }) || null
    signal openProject(string projectId, string mode)
    function syncSelection() {
        list.currentIndex = rows.findIndex(function(row) { return row.id === root.selectedId; });
    }
    onRowsChanged: Qt.callLater(syncSelection)
    onSelectedIdChanged: Qt.callLater(syncSelection)
    padding: 16
    ColumnLayout {
        anchors.fill: parent
        Label { text: "Projects"; font.bold: true; font.pixelSize: root.font.pixelSize * 1.4 }
        Label {
            Layout.fillWidth: true
            text: root.status !== "ready" ? root.status : root.rows.length ? "Select a workspace" : "No registered projects. Use workstation-project add."
            wrapMode: Text.Wrap
        }
        ListView {
            id: list
            objectName: "projectList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.rows
            keyNavigationEnabled: true
            activeFocusOnTab: true
            currentIndex: -1
            onCurrentIndexChanged: if (currentIndex >= 0 && currentIndex < root.rows.length) root.selectedId = root.rows[currentIndex].id
            ScrollBar.vertical: ScrollBar {}
            delegate: ItemDelegate {
                required property var modelData
                required property int index
                width: ListView.view.width
                text: modelData.label + (modelData.directory_available ? "" : " · directory unavailable")
                highlighted: ListView.isCurrentItem
                onClicked: { ListView.view.currentIndex = index; ListView.view.forceActiveFocus(); }
                Accessible.description: modelData.id
            }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Button {
                objectName: "openTerminal"
                text: "Open terminal"
                enabled: !root.busy && root.status === "ready" && !!root.selected && root.selected.directory_available
                onClicked: root.openProject(root.selectedId, "terminal")
            }
            Button {
                text: "Open editor"
                enabled: !root.busy && root.status === "ready" && !!root.selected && root.selected.directory_available
                onClicked: root.openProject(root.selectedId, "editor")
            }
        }
    }
}
