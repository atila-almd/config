import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import WorkstationShared 1.0

// Qt 6.2 fixture support predates ComponentBehavior: Bound. These delegates
// deliberately close over this file's root and row IDs.
// qmllint disable unqualified

ThemedPane {
    id: root
    required property string outputId
    required property var workspaces
    required property var trayItems
    property int trayRevision: 0
    property string workspaceStatus: "ready"
    property string clockText: ""
    property string dateText: ""
    signal workspaceRequested(string id)
    signal actionRequested(string action)
    signal trayRequested(string id, int slot, int revision, string action, real x, real y, int delta, bool horizontal)
    signal hintRequested(string text, real x)
    property Item hintOwner: null
    onHintOwnerChanged: if (!hintOwner) root.hintRequested("", 0)
    function hintFor(item, text, hovered) {
        if (hovered) {
            hintOwner = item;
            root.hintRequested(text, item.mapToItem(root, 0, 0).x);
        } else if (hintOwner === item) {
            hintOwner = null;
        }
    }
    padding: 6
    implicitHeight: Math.max(44, 40 * textScale + 8)
    function trayAction(row, action, button, delta, horizontal) {
        var position = button.mapToItem(root, button.width / 2, button.height);
        root.trayRequested(row.id, row.slot, root.trayRevision, action, position.x, position.y, delta, horizontal);
    }
    RowLayout {
        anchors.fill: parent
        spacing: 6
        Button {
            objectName: "barApplications"
            text: "Apps"
            Accessible.name: "Open application launcher"
            onClicked: root.actionRequested("launcher")
        }
        Flickable {
            objectName: "workspaceStrip"
            Layout.fillWidth: true
            Layout.preferredWidth: 320
            Layout.minimumWidth: 42
            Layout.fillHeight: true
            clip: true
            contentWidth: workspaceRow.implicitWidth
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            Row {
                id: workspaceRow
                spacing: 4
                height: parent.height
                Repeater {
                    model: root.workspaces.filter(function(row) { return row.output_id === root.outputId; })
                    delegate: Button {
                        id: workspaceButton
                        required property var modelData
                        objectName: "workspace-" + modelData.id
                        height: workspaceRow.height
                        text: modelData.name
                        highlighted: modelData.active
                        font.bold: modelData.focused
                        Accessible.name: "Workspace " + modelData.name + (modelData.active ? ", active" : "") + (modelData.urgent ? ", urgent" : "")
                        onClicked: root.workspaceRequested(modelData.id)
                        onHoveredChanged: root.hintFor(workspaceButton, Accessible.name, hovered)
                        background: Rectangle {
                            radius: 6
                            color: workspaceButton.highlighted ? root.colors.selection : root.colors.surface
                            border.width: workspaceButton.activeFocus || workspaceButton.modelData.urgent ? 2 : 0
                            border.color: workspaceButton.modelData.urgent ? root.colors.red : root.colors.accent
                        }
                    }
                }
                Label {
                    visible: root.workspaceStatus !== "ready"
                    text: "Workspaces unavailable"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        Label {
            id: clockLabel
            objectName: "barClock"
            text: root.clockText
            font.bold: true
            Accessible.name: root.dateText + " " + root.clockText
            HoverHandler {
                onHoveredChanged: root.hintFor(clockLabel, root.dateText, hovered)
            }
        }
        Flickable {
            Layout.preferredWidth: Math.min(trayRow.implicitWidth, root.width * 0.22)
            Layout.fillHeight: true
            contentWidth: trayRow.implicitWidth
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Row {
                id: trayRow
                spacing: 4
                height: parent.height
                Repeater {
                    model: root.trayItems
                    delegate: Button {
                        id: trayButton
                        required property var modelData
                        objectName: "tray-" + modelData.slot
                        height: trayRow.height
                        width: height
                        Accessible.name: modelData.title || modelData.id || "Tray application"
                        onHoveredChanged: root.hintFor(trayButton, modelData.tooltip || Accessible.name, hovered)
                        onClicked: root.trayAction(modelData, modelData.only_menu ? "menu" : "activate", trayButton, 0, false)
                        Keys.onMenuPressed: root.trayAction(modelData, "menu", trayButton, 0, false)
                        contentItem: Image {
                            source: trayButton.modelData.icon
                            sourceSize: Qt.size(24, 24)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            Label {
                                anchors.centerIn: parent
                                visible: parent.status !== Image.Ready
                                text: trayButton.Accessible.name.slice(0, 1).toUpperCase()
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton | Qt.MiddleButton
                            onClicked: mouse => root.trayAction(trayButton.modelData, mouse.button === Qt.RightButton ? "menu" : "secondary", trayButton, 0, false)
                            onWheel: wheel => {
                                var horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y);
                                root.trayAction(trayButton.modelData, "scroll", trayButton, horizontal ? wheel.angleDelta.x : wheel.angleDelta.y, horizontal);
                                wheel.accepted = true;
                            }
                        }
                    }
                }
            }
        }
        Button {
            objectName: "barProjects"
            text: root.width >= 1100 ? "Projects" : "P"
            Accessible.name: "Open projects and agent runs"
            onClicked: root.actionRequested("projects")
        }
        Button {
            objectName: "barTerminal"
            visible: root.width >= 900
            text: "Terminal"
            onClicked: root.actionRequested("terminal")
        }
        Button {
            objectName: "barLock"
            text: "Lock"
            onClicked: root.actionRequested("lock")
        }
        Button {
            id: toolsButton
            objectName: "barTools"
            text: "⋯"
            Accessible.name: "Workstation tools and power"
            onClicked: root.actionRequested("tools")
            onHoveredChanged: root.hintFor(toolsButton, "Tools, power, settings and utilities", hovered)
        }
    }
}
