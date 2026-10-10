pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../models/IslandMotion.js" as Motion

// The dashboard is hosted inside the same IslandGlass as every other card.
// It is a content mode, never a second window.
Item {
    id: root
    required property var palette
    property int currentTab: 0
    property int previousTab: 0
    property int nowToken: 0
    property real textScale: 1
    property bool reduceMotion: false
    property var enabledWidgets: []
    property var mediaItems: []
    property var audioData: ({items: []})
    property var performance: ({})
    property var battery: ({})
    property var systemInfo: ({})
    property var recording: ({})
    property var power: ({})
    property var tasks: []
    property var workspaces: []
    property var projects: []
    property var runs: []
    property string outputId: ""
    property string selectedProjectId: ""
    property string powerConfirmation: ""
    property int timerRemaining: 0
    property int timerTotal: 0
    property bool timerRunning: false
    property string timerName: ""
    signal tabRequested(int index)
    signal intent(string action, var args)
    signal collapseRequested()

    onCurrentTabChanged: {
        var direction = root.currentTab >= root.previousTab ? 1 : -1;
        root.previousTab = root.currentTab;
        pageLoader.x = direction * pageHost.width * 0.12;
        pageLoader.opacity = 0;
        pageLoader.scale = 0.97;
        Qt.callLater(function() {
            pageLoader.x = 0;
            pageLoader.opacity = 1;
            pageLoader.scale = 1;
        });
    }

    readonly property var tabs: {
        var result = [{label: "Dashboard", glyph: "\uf015", kind: "dashboard"}];
        if (root.enabled("media") && root.mediaItems.length)
            result.push({label: "Media", glyph: "\uf001", kind: "media"});
        if (root.enabled("performance") && root.performance.status === "ready")
            result.push({label: "Performance", glyph: "\uf201", kind: "performance"});
        if (root.enabled("workspaces") && root.workspaces.length)
            result.push({label: "Workspaces", glyph: "\uf00a", kind: "workspaces"});
        return result;
    }

    function enabled(widget) {
        return root.enabledWidgets.indexOf(widget) >= 0;
    }

    function tabKind() {
        return root.tabs[root.currentTab] ? root.tabs[root.currentTab].kind : "dashboard";
    }

    function tabIndexFor(name) {
        for (var i = 0; i < root.tabs.length; ++i)
            if (root.tabs[i].label.toLowerCase() === String(name).toLowerCase()) return i;
        return -1;
    }

    function monthTitle() {
        var ignored = root.nowToken;
        return new Date().toLocaleDateString(undefined, {month: "long", year: "numeric"});
    }

    RowLayout {
        id: tabs
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 18
        height: 38
        spacing: 4
        WheelHandler {
            onWheel: event => {
                var step = event.angleDelta.y < 0 ? 1 : -1;
                var next = (root.currentTab + step + root.tabs.length) % root.tabs.length;
                root.tabRequested(next);
            }
        }
        Repeater {
            model: root.tabs
            delegate: Item {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.fillHeight: true
                Text {
                    anchors.centerIn: parent
                    text: modelData.glyph + "  " + modelData.label
                    color: index === root.currentTab ? root.palette.foreground
                        : root.palette.foregroundMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.bold: index === root.currentTab
                }
                Rectangle {
                    height: 2
                    radius: 1
                    width: index === root.currentTab ? parent.width * 0.62 : 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    color: root.palette.accent
                    Behavior on width {
                        SpringAnimation {
                            spring: Motion.spring(Motion.hover, root.palette.speed,
                                root.reduceMotion)
                            damping: root.reduceMotion ? 1 : 0.74
                            mass: Motion.hover.mass
                        }
                    }
                }
                TapHandler { onTapped: root.tabRequested(index) }
            }
        }
    }

    Item {
        id: pageHost
        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 18
        clip: true

        Loader {
            id: pageLoader
            width: parent.width
            height: parent.height
            y: 0
            sourceComponent: root.tabKind() === "media" ? mediaPage
                : root.tabKind() === "performance" ? performancePage
                : root.tabKind() === "workspaces" ? workspacesPage : dashboardPage
            opacity: 1
            scale: 1
            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.duration(Motion.content.duration, root.palette.speed,
                        root.reduceMotion)
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                SpringAnimation {
                    spring: Motion.spring(Motion.hover, root.palette.speed, root.reduceMotion)
                    damping: Motion.damping(Motion.hover, root.reduceMotion)
                    mass: Motion.hover.mass
                }
            }
            Behavior on x {
                enabled: !root.reduceMotion
                SpringAnimation {
                    spring: Motion.spring(Motion.primary, root.palette.speed, false)
                    damping: Motion.primary.damping
                    mass: Motion.primary.mass
                }
            }
        }
    }

    Component {
        id: dashboardPage
        GridLayout {
            columns: 3
            rowSpacing: 12
            columnSpacing: 12
            Rectangle {
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.preferredHeight: 144
                radius: 22
                color: root.palette.glassFillRaised
                border.color: root.palette.rim
                border.width: 1
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 2
                    Text {
                        text: {
                            var ignored = root.nowToken;
                            return Qt.formatDate(new Date(), "dddd");
                        }
                        color: root.palette.foregroundMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                    }
                    Text {
                        text: {
                            var ignored = root.nowToken;
                            return Qt.formatDate(new Date(), "d");
                        }
                        color: root.palette.foreground
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 40 * root.textScale
                        font.bold: true
                    }
                    Text {
                        text: {
                            var ignored = root.nowToken;
                            return Qt.formatDate(new Date(), "MMMM yyyy");
                        }
                        color: root.palette.accent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }
                }
            }
            IslandGlass {
                visible: root.enabled("system_info")
                Layout.fillWidth: true
                Layout.preferredHeight: 144
                palette: root.palette
                reduceMotion: root.reduceMotion
                raised: true
                IslandCard {
                    anchors.fill: parent
                    anchors.margins: 1
                    palette: root.palette
                    widget: "system_info"
                    reduceMotion: root.reduceMotion
                    systemInfo: root.systemInfo
                    nowToken: root.nowToken
                    onCollapseRequested: root.collapseRequested()
                }
            }
            IslandGlass {
                visible: root.enabled("calendar")
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 332
                palette: root.palette
                reduceMotion: root.reduceMotion
                raised: true
                IslandCard {
                    anchors.fill: parent
                    palette: root.palette
                    widget: "calendar"
                    reduceMotion: root.reduceMotion
                    nowToken: root.nowToken
                    onCollapseRequested: root.collapseRequested()
                }
            }
            ColumnLayout {
                visible: (root.enabled("performance") && root.performance.status === "ready")
                    || (root.enabled("media") && root.mediaItems.length > 0)
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                IslandGlass {
                    visible: root.enabled("performance") && root.performance.status === "ready"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    palette: root.palette
                    reduceMotion: root.reduceMotion
                    raised: true
                    IslandCard {
                        anchors.fill: parent
                        palette: root.palette
                        widget: "performance"
                        reduceMotion: root.reduceMotion
                        performance: root.performance
                        systemInfo: root.systemInfo
                        onCollapseRequested: root.collapseRequested()
                    }
                }
                IslandGlass {
                    visible: root.enabled("media") && root.mediaItems.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 124
                    palette: root.palette
                    reduceMotion: root.reduceMotion
                    raised: true
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10
                        Text {
                            text: "\uf001"
                            color: root.palette.accent
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 22
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: {
                                    var p = root.mediaItems.length ? root.mediaItems[0] : null;
                                    return p ? (p.title || p.label) : "";
                                }
                                color: root.palette.foreground
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                            Text {
                                text: root.mediaItems.length
                                    ? (root.mediaItems[0].artist || root.mediaItems[0].label || "")
                                    : ""
                                color: root.palette.foregroundMuted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: mediaPage
        IslandGlass {
            anchors.fill: parent
            palette: root.palette
            reduceMotion: root.reduceMotion
            raised: true
            IslandCard {
                anchors.fill: parent
                palette: root.palette
                widget: "media"
                reduceMotion: root.reduceMotion
                mediaItems: root.mediaItems
                audioData: root.audioData
                nowToken: root.nowToken
                onIntent: (action, args) => root.intent(action, args)
                onCollapseRequested: root.collapseRequested()
            }
        }
    }

    Component {
        id: performancePage
        IslandGlass {
            anchors.fill: parent
            palette: root.palette
            reduceMotion: root.reduceMotion
            raised: true
            IslandCard {
                anchors.fill: parent
                palette: root.palette
                widget: "performance"
                reduceMotion: root.reduceMotion
                performance: root.performance
                systemInfo: root.systemInfo
                nowToken: root.nowToken
                onCollapseRequested: root.collapseRequested()
            }
        }
    }

    Component {
        id: workspacesPage
        IslandGlass {
            anchors.fill: parent
            palette: root.palette
            reduceMotion: root.reduceMotion
            raised: true
            IslandCard {
                anchors.fill: parent
                palette: root.palette
                widget: "workspaces"
                reduceMotion: root.reduceMotion
                workspaces: root.workspaces
                nowToken: root.nowToken
                onIntent: (action, args) => root.intent(action, args)
                onCollapseRequested: root.collapseRequested()
            }
        }
    }
}
