pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../models/IslandMotion.js" as Motion

// One per output. The shell owns the state; this item only maps that state to
// a single morphing geometry and sends user intents upward.
Item {
    id: root
    required property var palette
    required property var config
    required property string outputId
    required property string surfaceState
    required property string cardWidget
    property string expandedOutputId: ""
    property bool launcherHere: surfaceState === "launcher" && expandedOutputId === outputId
    property var launcherAdapter: null
    property var workspaces: []
    property var trayItems: []
    property int trayRevision: 0
    property var mediaItems: []
    property var audioData: ({items: []})
    property var performance: ({})
    property var battery: ({})
    property var systemInfo: ({})
    property var recording: ({})
    property var power: ({})
    property var notifications: ({status: "unavailable", data: null})
    property var tasks: []
    property var projects: []
    property var runs: []
    property string selectedProjectId: ""
    property string powerConfirmation: ""
    property int nowToken: 0
    property real phase: 0
    property int timerRemaining: 0
    property int timerTotal: 0
    property bool timerRunning: false
    property string timerName: ""
    property string attentionGlyph: "\uf129"
    property string attentionTitle: ""
    property string attentionDetail: ""
    property real attentionValue: -1
    property bool reduceMotion: false
    property real speed: 1
    property real cardContentProgress: 1
    property bool primaryIsTimer: false
    property bool secondaryIsTimer: false
    property bool recordingActive: false
    property bool hasBattery: battery && battery.status === "ready"
    property bool hasAudio: audioData && audioData.status === "ready"
    property bool hasMedia: isEnabled("media") && mediaItems.length > 0
    property bool cardOpenHere: surfaceState === "expanded" && expandedOutputId === outputId
    property bool dashboardHere: surfaceState === "dashboard" && expandedOutputId === outputId
    property bool expandedHere: cardOpenHere || dashboardHere || launcherHere
    property int dashboardTab: 0
    property real leftWidth: 214
    property real rightWidth: {
        var count = rightWidgets.filter(function(widget) {
            return rightWidgetAvailable(widget);
        }).length;
        var trayCount = Math.min(5, trayItems.length);
        if (!count && !trayCount) return 0;
        return Math.max(88, count * 34 + 20 + trayCount * 28);
    }
    property var rightWidgets: {
        var base = ["volume", "battery", "timer", "recorder", "projects", "power"];
        var order = config && config.widget_order ? config.widget_order : base;
        var result = [];
        order.forEach(function(widget) {
            if (base.indexOf(widget) >= 0 && result.indexOf(widget) < 0)
                result.push(widget);
        });
        return result;
    }
    property real compactWidth: launcherHere ? Math.max(520, Math.min(760, root.width - 80))
        : dashboardHere ? Number(config.dashboard_width)
        : cardOpenHere ? cardWidth(cardWidget)
        : surfaceState === "activity" || surfaceState === "split" ? 394
        : surfaceState === "attention" ? 360
        : 300
    property real compactHeight: launcherHere ? 520
        : dashboardHere ? 600
        : cardOpenHere ? cardHeight(cardWidget)
        : surfaceState === "attention" ? 46 : 36
    property real centerX: (width - compactWidth) / 2
    property real centerY: expandedHere || surfaceState === "dashboard"
        ? 0 : Math.max(0, (height - compactHeight) / 2)
    property real surfaceHeight: Math.max(Number(config.bar_height) || 40, compactHeight + 4)
    property string tooltipWidget: ""
    property string tooltipText: ""
    signal widgetRequested(string widget)
    signal dashboardRequested()
    signal collapseRequested()
    signal actionRequested(string action)
    signal launcherActivateRequested(var item, string action)
    signal workspaceRequested(string id)
    signal trayRequested(string id, int slot, int revision, string action,
        real x, real y, int delta, bool horizontal)
    signal hoverIntent(string key, bool hovered)
    signal outputActivated()
    signal volumeWheel(real delta)
    signal tabRequested(int index)
    signal intent(string action, var args)

    onCardWidgetChanged: {
        if (root.surfaceState === "expanded") {
            root.cardContentProgress = 0;
            Qt.callLater(function() { root.cardContentProgress = 1; });
        }
    }

    implicitHeight: root.surfaceHeight
    clip: false

    function isEnabled(widget) {
        return config && config.enabled_widgets
            && config.enabled_widgets.indexOf(widget) >= 0;
    }

    function cardWidth(widget) {
        var widths = {
            media: 650, volume: 560, battery: 520, calendar: 520,
            performance: 680, tasks: 600, timer: 580, recorder: 560,
            system_info: 520, workspaces: 620, projects: 720, power: 560,
            notifications: 680
        };
        return widths[widget] || 560;
    }

    function cardHeight(widget) {
        var heights = {
            media: 420, volume: 360, battery: 310, calendar: 430,
            performance: 380, tasks: 430, timer: 350, recorder: 340,
            system_info: 300, workspaces: 390, projects: 460, power: 370,
            notifications: 520
        };
        return heights[widget] || 360;
    }

    function horizontalGap() {
        return rightWidth > 0 ? 24 : 12;
    }

    function rightWidgetAvailable(widget) {
        if (!isEnabled(widget)) return false;
        if (widget === "volume") return hasAudio;
        if (widget === "battery") return hasBattery;
        if (widget === "timer") return timerRunning;
        if (widget === "recorder") return recordingActive;
        if (widget === "projects") return projects.length > 0;
        return widget === "power" && power && power.status === "ready";
    }

    function rightWidgetGlyph(widget) {
        if (widget === "volume") return "\uf028";
        if (widget === "battery") return battery.percent < 20 ? "\uf244" : "\uf240";
        if (widget === "timer") return "\uf017";
        if (widget === "recorder") return "\uf03d";
        if (widget === "projects") return "\uf1d8";
        return "\uf011";
    }

    function groupX(which) {
        var total = leftWidth + rightWidth + compactWidth + horizontalGap();
        if (config.layout === "spread") {
            return which === "left" ? 12 : (width - rightWidth - 12);
        }
        var base = (width - total) / 2;
        if (which === "left") return base;
        if (which === "center") return base + leftWidth + 12;
        return base + leftWidth + 12 + compactWidth + (rightWidth > 0 ? 12 : 0);
    }

    function centerTargetX() {
        if (config.layout === "spread") return (width - compactWidth) / 2;
        return (width - leftWidth - compactWidth - rightWidth - horizontalGap()) / 2
            + leftWidth + 12;
    }

    function showTooltip(widget, text, hovered) {
        if (hovered) {
            tooltipWidget = widget;
            tooltipText = text;
        } else if (tooltipWidget === widget) {
            tooltipWidget = "";
            tooltipText = "";
        }
        hoverIntent(widget, hovered);
    }

    function trayAction(row, action, button, delta, horizontal) {
        var point = button.mapToItem(root, button.width / 2, button.height);
        root.trayRequested(row.id, row.slot, root.trayRevision, action,
            point.x, point.y, delta, horizontal);
    }

    Behavior on compactWidth {
        SpringAnimation {
            spring: Motion.spring(Motion.primary, root.speed, root.reduceMotion)
            damping: Motion.damping(Motion.primary, root.reduceMotion)
            mass: Motion.primary.mass
        }
    }
    Behavior on compactHeight {
        SpringAnimation {
            spring: Motion.spring(Motion.primary, root.speed, root.reduceMotion)
            damping: Motion.damping(Motion.primary, root.reduceMotion)
            mass: Motion.primary.mass
        }
    }

    IslandGlass {
        id: unified
        visible: root.config.layout === "one"
        x: Math.min(root.groupX("left"), root.centerTargetX())
        y: 0
        width: root.leftWidth + root.compactWidth + root.rightWidth + root.horizontalGap()
        height: root.config.layout === "one" ? Math.max(36, root.compactHeight) : 0
        palette: root.palette
        reduceMotion: root.reduceMotion
        raised: root.expandedHere
        interactive: false
        cornerRadius: height / 2
        Behavior on x {
            SpringAnimation { spring: Motion.spring(Motion.primary, root.speed, root.reduceMotion); damping: Motion.damping(Motion.primary, root.reduceMotion); mass: Motion.primary.mass }
        }
        Behavior on width {
            SpringAnimation { spring: Motion.spring(Motion.primary, root.speed, root.reduceMotion); damping: Motion.damping(Motion.primary, root.reduceMotion); mass: Motion.primary.mass }
        }
        Behavior on height {
            SpringAnimation { spring: Motion.spring(Motion.primary, root.speed, root.reduceMotion); damping: Motion.damping(Motion.primary, root.reduceMotion); mass: Motion.primary.mass }
        }
    }

    Item {
        id: leftGroup
        x: root.groupX("left")
        y: 0
        width: root.leftWidth
        height: Math.max(36, root.config.bar_height)
        opacity: root.expandedHere ? 0.72 : 1
        Behavior on x {
            SpringAnimation { spring: Motion.spring(Motion.primary, root.speed, root.reduceMotion); damping: Motion.damping(Motion.primary, root.reduceMotion); mass: Motion.primary.mass }
        }
        Behavior on opacity {
            NumberAnimation { duration: Motion.duration(Motion.content.duration, root.speed, root.reduceMotion); easing.type: Easing.OutCubic }
        }

        IslandGlass {
            anchors.fill: parent
            palette: root.palette
            reduceMotion: root.reduceMotion
            visible: root.config.layout !== "one"
            interactive: true
            raised: false
        }
        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 5
            Repeater {
                model: root.workspaces.filter(function(row) {
                    return row.output_id === root.outputId;
                })
                delegate: Item {
                    required property var modelData
                    width: modelData.active ? 22 : 15
                    height: 30
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        anchors.centerIn: parent
                        width: modelData.active ? 20 : 8
                        height: modelData.active ? 8 : 8
                        radius: 5
                        color: modelData.active ? root.palette.accent
                            : Qt.rgba(root.palette.foreground.r, root.palette.foreground.g,
                                root.palette.foreground.b, modelData.urgent ? 0.8 : 0.34)
                        border.width: modelData.urgent ? 1 : 0
                        border.color: root.palette.red
                        Behavior on width {
                            SpringAnimation { spring: Motion.spring(Motion.press, root.speed, root.reduceMotion); damping: Motion.damping(Motion.press, root.reduceMotion); mass: Motion.press.mass }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: false
                        text: modelData.name
                    }
                    HoverHandler {
                        onHoveredChanged: root.showTooltip("workspace-" + modelData.id,
                            "Workspace " + modelData.name, hovered)
                    }
                    TapHandler {
                        onTapped: {
                            root.outputActivated();
                            root.workspaceRequested(modelData.id);
                        }
                    }
                }
            }
            IslandIcon {
                id: appsIcon
                palette: root.palette
                glyph: "\uf00a"
                label: "Applications"
                enabled: true
                onClicked: root.actionRequested("launcher")
                onHoveredChanged: root.showTooltip("launcher", "Applications", hovered)
            }
            IslandIcon {
                palette: root.palette
                glyph: "\uf002"
                label: "Search"
                onClicked: root.actionRequested("launcher")
                onHoveredChanged: root.showTooltip("search", "Search applications", hovered)
            }
        }
    }

    Item {
        id: rightGroup
        x: root.groupX("right")
        y: 0
        width: root.rightWidth
        height: Math.max(36, root.config.bar_height)
        visible: root.rightWidth > 0
        opacity: root.expandedHere ? 0.72 : 1
        Behavior on x {
            SpringAnimation { spring: Motion.spring(Motion.primary, root.speed, root.reduceMotion); damping: Motion.damping(Motion.primary, root.reduceMotion); mass: Motion.primary.mass }
        }
        Behavior on width {
            SpringAnimation { spring: Motion.spring(Motion.primary, root.speed, root.reduceMotion); damping: Motion.damping(Motion.primary, root.reduceMotion); mass: Motion.primary.mass }
        }
        Behavior on opacity {
            NumberAnimation { duration: Motion.duration(Motion.content.duration, root.speed, root.reduceMotion); easing.type: Easing.OutCubic }
        }
        IslandGlass {
            anchors.fill: parent
            palette: root.palette
            reduceMotion: root.reduceMotion
            visible: root.config.layout !== "one"
            interactive: true
        }
            Row {
                anchors.centerIn: parent
                spacing: 3
            Repeater {
                model: root.trayItems.slice(0, 5)
                delegate: Item {
                    required property var modelData
                    width: 26
                    height: 28
                    Image {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: modelData.icon
                        sourceSize: Qt.size(24, 24)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: modelData.icon.length === 0
                        text: (modelData.title || modelData.id || "T").slice(0, 1).toUpperCase()
                        color: root.palette.foregroundMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }
                    HoverHandler {
                        onHoveredChanged: root.showTooltip("tray-" + modelData.slot,
                            modelData.title || modelData.id || "Tray", hovered)
                    }
                    TapHandler {
                        onTapped: root.trayAction(modelData,
                            modelData.only_menu ? "menu" : "activate", parent, 0, false)
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => root.trayAction(modelData,
                            mouse.button === Qt.RightButton ? "menu" : "secondary",
                            parent, 0, false)
                        onWheel: wheel => {
                            var horizontal = Math.abs(wheel.angleDelta.x)
                                > Math.abs(wheel.angleDelta.y);
                            root.trayAction(modelData, "scroll", parent,
                                horizontal ? wheel.angleDelta.x : wheel.angleDelta.y,
                                horizontal);
                            wheel.accepted = true;
                        }
                    }
                }
            }
            Repeater {
                model: root.rightWidgets
                delegate: IslandIcon {
                    required property string modelData
                    visible: root.rightWidgetAvailable(modelData)
                    palette: root.palette
                    glyph: root.rightWidgetGlyph(modelData)
                    label: modelData
                    active: modelData === "timer"
                    alert: modelData === "recorder"
                    color: modelData === "battery" && root.battery.state === "Charging"
                        ? root.palette.green : root.palette.foreground
                    onClicked: root.widgetRequested(modelData)
                    onWheelAdjusted: if (modelData === "volume")
                        root.volumeWheel(delta)
                    onHoveredChanged: root.showTooltip(modelData, modelData, hovered)
                }
            }
        }
    }

    Item {
        id: centerHost
        x: root.centerTargetX()
        y: root.centerY
        width: root.compactWidth
        height: root.compactHeight
        z: 10
        Behavior on x {
            SpringAnimation { spring: Motion.spring(Motion.primary, root.speed, root.reduceMotion); damping: Motion.damping(Motion.primary, root.reduceMotion); mass: Motion.primary.mass }
        }
        Behavior on y {
            SpringAnimation { spring: Motion.spring(Motion.primary, root.speed, root.reduceMotion); damping: Motion.damping(Motion.primary, root.reduceMotion); mass: Motion.primary.mass }
        }
        Behavior on width {
            SpringAnimation { spring: Motion.spring(Motion.primary, root.speed, root.reduceMotion); damping: Motion.damping(Motion.primary, root.reduceMotion); mass: Motion.primary.mass }
        }
        Behavior on height {
            SpringAnimation { spring: Motion.spring(Motion.primary, root.speed, root.reduceMotion); damping: Motion.damping(Motion.primary, root.reduceMotion); mass: Motion.primary.mass }
        }

        IslandGlass {
            id: centerGlass
            anchors.fill: parent
            palette: root.palette
            reduceMotion: root.reduceMotion
            raised: root.expandedHere || root.surfaceState === "dashboard"
            interactive: true
            cornerRadius: Math.min(height / 2, 28)
            onHoveredChangedExternally: hovered => root.hoverIntent("island", hovered)
        }

        Item {
            id: compactContent
            anchors.fill: parent
            opacity: root.expandedHere || root.surfaceState === "dashboard"
                || root.surfaceState === "attention" ? 0 : 1
            scale: root.expandedHere || root.surfaceState === "dashboard"
                || root.surfaceState === "attention" ? 0.96 : 1
            Behavior on opacity {
                NumberAnimation { duration: Motion.duration(Motion.content.duration, root.speed, root.reduceMotion); easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                SpringAnimation { spring: Motion.spring(Motion.hover, root.speed, root.reduceMotion); damping: Motion.damping(Motion.hover, root.reduceMotion); mass: Motion.hover.mass }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8
                Item {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 28
                    Image {
                        anchors.centerIn: parent
                        width: root.hasMedia ? 24 : 18
                        height: width
                        source: root.hasMedia ? root.mediaItems[0].art_url : ""
                        visible: root.hasMedia && !!root.mediaItems[0].art_url
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        layer.enabled: true
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !parent.children[0].visible
                        text: root.surfaceState === "activity" || root.surfaceState === "split"
                            ? (root.primaryIsTimer ? "\uf017" : "\uf001") : "\uf111"
                        color: root.palette.accent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 17
                    }
                    Behavior on width {
                        SpringAnimation { spring: Motion.spring(Motion.hover, root.speed, root.reduceMotion); damping: Motion.damping(Motion.hover, root.reduceMotion); mass: Motion.hover.mass }
                    }
                }
                RollingClock {
                    Layout.fillWidth: true
                    text: {
                        var ignored = root.nowToken;
                        return Qt.formatTime(new Date(), "HH:mm");
                    }
                    color: root.palette.foreground
                    pixelSize: 14
                    speed: Number(root.config.animation_speed)
                    reduceMotion: root.reduceMotion
                }
                Row {
                    Layout.preferredWidth: 54
                    spacing: 3
                    Repeater {
                        model: 5
                        delegate: Rectangle {
                            required property int index
                            width: 4
                            height: root.surfaceState === "activity" || root.surfaceState === "split"
                                ? 7 + Math.abs(Math.sin(root.phase + index)) * 10 : 4
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.palette.accent
                            opacity: root.surfaceState === "attention" ? 0.4 : 0.82
                            Behavior on height {
                                SpringAnimation { spring: Motion.spring(Motion.press, root.speed, root.reduceMotion); damping: Motion.damping(Motion.press, root.reduceMotion); mass: Motion.press.mass }
                            }
                        }
                    }
                }
            }

            TapHandler {
                onTapped: {
                    root.outputActivated();
                    root.dashboardRequested();
                }
            }
            WheelHandler {
                enabled: root.hasAudio
                onWheel: event => root.volumeWheel(event.angleDelta.y)
            }
        }

        Item {
            id: attentionContent
            anchors.fill: parent
            visible: root.surfaceState === "attention"
            opacity: visible ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Motion.duration(Motion.content.duration, root.speed, root.reduceMotion); easing.type: Easing.OutCubic }
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10
                Text {
                    text: root.attentionGlyph
                    color: root.palette.accent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Text {
                        text: root.attentionTitle
                        color: root.palette.foreground
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root.attentionDetail
                        color: root.palette.foregroundMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
                IslandSlider {
                    id: attentionSlider
                    islandPalette: root.palette
                    reduceMotion: root.reduceMotion
                    visible: root.attentionValue >= 0
                    Layout.preferredWidth: 110
                    from: 0
                    to: 100
                    value: root.attentionValue
                    onPressedChanged: if (!pressed) {
                        root.intent("attention.value", {value: value});
                        value = Qt.binding(function() { return root.attentionValue; });
                    }
                }
            }
        }

        Loader {
            id: cardLoader
            anchors.fill: parent
            anchors.margins: 1
            active: root.cardOpenHere
            opacity: active ? root.cardContentProgress : 0
            scale: active ? 1 : 0.96
            sourceComponent: IslandCard {
                palette: root.palette
                widget: root.cardWidget
                mediaItems: root.mediaItems
                audioData: root.audioData
                performance: root.performance
                battery: root.battery
                systemInfo: root.systemInfo
                recording: root.recording
                power: root.power
                notifications: root.notifications
                tasks: root.tasks
                workspaces: root.workspaces
                projects: root.projects
                runs: root.runs
                outputId: root.outputId
                selectedProjectId: root.selectedProjectId
                powerConfirmation: root.powerConfirmation
                nowToken: root.nowToken
                timerRemaining: root.timerRemaining
                timerTotal: root.timerTotal
                timerRunning: root.timerRunning
                timerName: root.timerName
                reduceMotion: root.reduceMotion
                onIntent: (action, args) => root.intent(action, args)
                onCollapseRequested: root.collapseRequested()
            }
            Behavior on opacity {
                NumberAnimation { duration: Motion.duration(Motion.content.duration, root.speed, root.reduceMotion); easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                SpringAnimation { spring: Motion.spring(Motion.hover, root.speed, root.reduceMotion); damping: Motion.damping(Motion.hover, root.reduceMotion); mass: Motion.hover.mass }
            }
        }

        Loader {
            id: dashboardLoader
            anchors.fill: parent
            anchors.margins: 1
            active: root.dashboardHere
            opacity: active ? 1 : 0
            scale: active ? 1 : 0.96
            sourceComponent: DashboardView {
                palette: root.palette
                currentTab: root.dashboardTab
                reduceMotion: root.reduceMotion
                enabledWidgets: root.config.enabled_widgets
                textScale: Number(root.config.text_scale) || 1
                nowToken: root.nowToken
                mediaItems: root.mediaItems
                audioData: root.audioData
                performance: root.performance
                battery: root.battery
                systemInfo: root.systemInfo
                recording: root.recording
                power: root.power
                tasks: root.tasks
                workspaces: root.workspaces
                projects: root.projects
                runs: root.runs
                outputId: root.outputId
                selectedProjectId: root.selectedProjectId
                powerConfirmation: root.powerConfirmation
                timerRemaining: root.timerRemaining
                timerTotal: root.timerTotal
                timerRunning: root.timerRunning
                timerName: root.timerName
                onTabRequested: index => root.tabRequested(index)
                onIntent: (action, args) => root.intent(action, args)
                onCollapseRequested: root.collapseRequested()
            }
            Behavior on opacity { NumberAnimation { duration: (root.reduceMotion ? 150 : 200) * root.speed; easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { spring: 10 / root.speed; damping: 0.78; mass: 0.8 } }
        }

        Loader {
            id: launcherLoader
            anchors.fill: parent
            anchors.margins: 1
            active: root.launcherHere
            opacity: active ? 1 : 0
            scale: active ? 1 : 0.96
            sourceComponent: Launcher {
                palette: root.palette
                adapter: root.launcherAdapter
                reduceMotion: root.reduceMotion
                speed: root.speed
                onCloseRequested: root.collapseRequested()
                onActivateRequested: (item, action) =>
                    root.launcherActivateRequested(item, action)
            }
            Behavior on opacity { NumberAnimation { duration: (root.reduceMotion ? 150 : 200) * root.speed; easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { spring: 10 / root.speed; damping: 0.78; mass: 0.8 } }
        }
    }

    IslandGlass {
        id: satellite
        visible: root.surfaceState === "split"
        x: root.centerTargetX() + root.compactWidth + 12
        y: 0
        width: 42
        height: 36
        z: 11
        palette: root.palette
        reduceMotion: root.reduceMotion
        raised: true
        Text {
            anchors.centerIn: parent
            text: root.secondaryIsTimer ? "\uf017" : "\uf03d"
            color: root.palette.accent
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
        }
        TapHandler {
            onTapped: root.widgetRequested(root.secondaryIsTimer ? "timer" : "recorder")
        }
        HoverHandler {
            onHoveredChanged: root.hoverIntent("satellite", hovered)
        }
        Behavior on x {
            SpringAnimation { spring: Motion.spring(Motion.attentionIn, root.speed, root.reduceMotion); damping: Motion.damping(Motion.attentionIn, root.reduceMotion); mass: Motion.attentionIn.mass }
        }
        Behavior on scale {
            SpringAnimation { spring: Motion.spring(Motion.attentionIn, root.speed, root.reduceMotion); damping: Motion.damping(Motion.attentionIn, root.reduceMotion); mass: Motion.attentionIn.mass }
        }
        scale: visible ? 1 : 0.4
        opacity: visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Motion.duration(Motion.attentionIn.duration, root.speed, root.reduceMotion); easing.type: Easing.OutCubic }
        }
    }

    IslandGlass {
        id: tooltip
        visible: root.tooltipWidget.length > 0 && !root.expandedHere
        x: Math.max(0, Math.min(root.width - width, root.centerTargetX() + root.compactWidth / 2 - width / 2))
        y: Math.max(0, root.config.bar_height + 4)
        implicitWidth: tooltipLabel.implicitWidth + 24
        implicitHeight: tooltipLabel.implicitHeight + 16
        width: implicitWidth
        height: implicitHeight
        palette: root.palette
        reduceMotion: root.reduceMotion
        raised: true
        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0.96
        Text {
            id: tooltipLabel
            anchors.centerIn: parent
            text: root.tooltipText
            color: root.palette.foreground
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
        }
        Behavior on y {
            SpringAnimation { spring: Motion.spring(Motion.hover, root.speed, root.reduceMotion); damping: Motion.damping(Motion.hover, root.reduceMotion); mass: Motion.hover.mass }
        }
        Behavior on opacity {
            NumberAnimation { duration: Motion.duration(120, root.speed, root.reduceMotion); easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            SpringAnimation { spring: Motion.spring(Motion.hover, root.speed, root.reduceMotion); damping: Motion.damping(Motion.hover, root.reduceMotion); mass: Motion.hover.mass }
        }
    }
}
