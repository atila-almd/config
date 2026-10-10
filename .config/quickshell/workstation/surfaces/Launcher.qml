pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

FocusScope {
    id: root
    required property var palette
    required property var adapter
    required property bool reduceMotion
    property real speed: 1
    property int currentIndex: 0
    signal closeRequested()
    signal activateRequested(var item, string action)

    function actionFor(item) {
        if (!item) return "";
        if (item.provider === "desktopapplications") return "start";
        if (item.provider === "files") return "open";
        if (item.provider === "calc") return "copy";
        return "";
    }

    function activateCurrent() {
        if (root.currentIndex < 0 || root.currentIndex >= root.adapter.items.length)
            return;
        var item = root.adapter.items[root.currentIndex];
        var action = root.actionFor(item);
        if (!action) {
            root.adapter.message = "This result is read-only.";
            return;
        }
        root.activateRequested(item, action);
    }

    function moveSelection(delta) {
        var count = root.adapter.items.length;
        if (!count) return;
        root.currentIndex = Math.max(0, Math.min(count - 1,
            root.currentIndex + delta));
        results.positionViewAtIndex(root.currentIndex, ListView.Contain);
    }

    function syncSelection() {
        root.currentIndex = Math.max(0, Math.min(
            Math.max(0, root.adapter.items.length - 1), root.currentIndex));
    }

    onAdapterChanged: if (root.adapter) root.adapter.query = search.text
    onVisibleChanged: if (visible) Qt.callLater(function() {
        search.forceActiveFocus();
        search.selectAll();
    })

    Keys.onEscapePressed: root.closeRequested()
    Keys.onUpPressed: root.moveSelection(-1)
    Keys.onDownPressed: root.moveSelection(1)
    Keys.onReturnPressed: root.activateCurrent()
    Keys.onEnterPressed: root.activateCurrent()

    Component.onCompleted: Qt.callLater(function() {
        search.forceActiveFocus();
        search.selectAll();
    })

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: "\uf002"
                color: root.palette.accent
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 20
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: "Launcher"
                    color: root.palette.foreground
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    text: "Elephant index · / files · = calculate · @ web"
                    color: root.palette.foregroundMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
            IslandButton {
                palette: root.palette
                glyph: "\uf00d"
                text: "Close"
                onClicked: root.closeRequested()
            }
        }

        TextField {
            id: search
            objectName: "launcherSearch"
            Layout.fillWidth: true
            implicitHeight: 48
            placeholderText: "Search applications, files, calculations…"
            color: root.palette.foreground
            placeholderTextColor: root.palette.foregroundMuted
            selectionColor: root.palette.selection
            selectedTextColor: root.palette.foreground
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            selectByMouse: true
            onTextEdited: {
                root.currentIndex = 0;
                root.adapter.query = text;
            }
            background: Rectangle {
                radius: 13
                color: Qt.rgba(root.palette.surface.r, root.palette.surface.g,
                    root.palette.surface.b, 0.68)
                border.width: 1
                border.color: search.activeFocus ? root.palette.accent : root.palette.rim
            }
            Keys.onEscapePressed: root.closeRequested()
            Keys.onDownPressed: root.moveSelection(1)
            Keys.onUpPressed: root.moveSelection(-1)
            Keys.onReturnPressed: root.activateCurrent()
            Keys.onEnterPressed: root.activateCurrent()
        }

        ListView {
            id: results
            objectName: "launcherResults"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 5
            model: root.adapter.items
            currentIndex: root.currentIndex
            onCurrentIndexChanged: root.currentIndex = currentIndex
            onModelChanged: root.syncSelection()
            ScrollBar.vertical: ScrollBar {}

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 54
                radius: 11
                color: index === root.currentIndex
                    ? Qt.rgba(root.palette.selection.r, root.palette.selection.g,
                        root.palette.selection.b, 0.72)
                    : Qt.rgba(root.palette.surface.r, root.palette.surface.g,
                        root.palette.surface.b, 0.28)
                border.width: index === root.currentIndex ? 1 : 0
                border.color: root.palette.accent

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 13
                    anchors.rightMargin: 13
                    spacing: 12
                    Text {
                        Layout.preferredWidth: 25
                        text: row.modelData.icon || (row.modelData.provider === "files"
                            ? "\uf07b" : row.modelData.provider === "calc" ? "\uf1ec" : "\uf111")
                        color: root.palette.accent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 17
                        horizontalAlignment: Text.AlignHCenter
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.label || "Unnamed result"
                            color: root.palette.foreground
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            elide: Text.ElideMiddle
                        }
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.detail || row.modelData.provider || ""
                            color: root.palette.foregroundMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            elide: Text.ElideMiddle
                        }
                    }
                    Text {
                        text: row.modelData.provider === "calc" ? "Copy"
                            : root.actionFor(row.modelData) ? "Enter" : ""
                        color: root.palette.foregroundMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                    }
                }
                TapHandler {
                    onTapped: {
                        root.currentIndex = row.index;
                        root.activateCurrent();
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: root.adapter.status === "loading" ? "Searching…"
                    : root.adapter.status === "unavailable" ? root.adapter.message
                    : root.adapter.status === "error" ? root.adapter.message
                    : root.adapter.items.length ? root.adapter.items.length + " results"
                    : "No matching results"
                color: root.adapter.status === "error" ? root.palette.red
                    : root.palette.foregroundMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Text {
                text: "↑↓ select · Enter open · Esc close"
                color: root.palette.foregroundMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
            }
        }
    }
}
