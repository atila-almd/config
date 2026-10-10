pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import WorkstationShared 1.0
import "../components"
import "../models/IslandMotion.js" as Motion

// Cards are deliberately passive. The shell owns timers, processes, native
// subscriptions and side effects; this surface only renders snapshots and
// emits intents back to the Island state machine.
Item {
    id: root
    required property var palette
    required property string widget
    property var mediaItems: []
    property var audioData: ({items: []})
    property var performance: ({})
    property var battery: ({})
    property var systemInfo: ({})
    property var recording: ({status: "unavailable", data: null})
    property var power: ({status: "unavailable", data: null})
    property var notifications: ({status: "unavailable", data: null})
    property var tasks: []
    property var workspaces: []
    property var projects: []
    property var runs: []
    property string outputId: ""
    property string selectedProjectId: ""
    property string powerConfirmation: ""
    property int nowToken: 0
    property int timerRemaining: 0
    property int timerTotal: 0
    property bool timerRunning: false
    property string timerName: ""
    property real reveal: 0
    property bool reduceMotion: false
    signal intent(string action, var args)
    signal collapseRequested()

    readonly property var notificationData: root.notifications
        && root.notifications.status === "ready" && root.notifications.data
        ? root.notifications.data
        : ({dnd: false, unread_count: null, items: []})

    opacity: root.reveal
    scale: 0.96 + root.reveal * 0.04
    y: (1 - root.reveal) * 8
    Component.onCompleted: Qt.callLater(function() { root.reveal = 1; })
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
    Behavior on y {
        SpringAnimation {
            spring: Motion.spring(Motion.primary, root.palette.speed, root.reduceMotion)
            damping: Motion.damping(Motion.primary, root.reduceMotion)
            mass: Motion.primary.mass
        }
    }

    function mediaPlayer() {
        var playing = root.mediaItems.filter(function(row) { return row.state === "playing"; });
        return (playing.length ? playing[0] : root.mediaItems[0]) || null;
    }

    function outputAudio() {
        var rows = root.audioData && Array.isArray(root.audioData.items) ? root.audioData.items : [];
        var defaultId = root.audioData ? root.audioData.default_output_id : null;
        for (var i = 0; i < rows.length; ++i)
            if (rows[i].id === defaultId && rows[i].direction === "output") return rows[i];
        for (var j = 0; j < rows.length; ++j)
            if (rows[j].direction === "output") return rows[j];
        return null;
    }

    function inputAudio() {
        var rows = root.audioData && Array.isArray(root.audioData.items) ? root.audioData.items : [];
        var defaultId = root.audioData ? root.audioData.default_input_id : null;
        for (var i = 0; i < rows.length; ++i)
            if (rows[i].id === defaultId && rows[i].direction === "input") return rows[i];
        for (var j = 0; j < rows.length; ++j)
            if (rows[j].direction === "input") return rows[j];
        return null;
    }

    function formatTime(seconds) {
        var value = Math.max(0, Math.floor(Number(seconds) || 0));
        var minutes = Math.floor(value / 60);
        var rest = value % 60;
        return (minutes < 10 ? "0" : "") + minutes + ":" + (rest < 10 ? "0" : "") + rest;
    }

    function formatUptime(seconds) {
        var value = Math.max(0, Math.floor(Number(seconds) || 0));
        var days = Math.floor(value / 86400);
        value %= 86400;
        var hours = Math.floor(value / 3600);
        value %= 3600;
        var minutes = Math.floor(value / 60);
        return (days ? days + "d " : "") + hours + "h " + minutes + "m";
    }

    function formatBytes(bytes) {
        var value = Number(bytes);
        if (!isFinite(value)) return "Unavailable";
        var units = ["B", "KiB", "MiB", "GiB", "TiB"];
        var index = 0;
        while (value >= 1024 && index < units.length - 1) {
            value /= 1024;
            ++index;
        }
        return value.toFixed(index ? 1 : 0) + " " + units[index];
    }

    function calendarCells(year, month) {
        var ignored = root.nowToken;
        var first = new Date(year, month, 1);
        var start = (first.getDay() + 6) % 7;
        var result = [];
        var today = new Date();
        for (var i = 0; i < 42; ++i) {
            var date = new Date(year, month, i - start + 1);
            result.push({
                day: date.getDate(),
                inMonth: date.getMonth() === month,
                today: date.getFullYear() === today.getFullYear()
                    && date.getMonth() === today.getMonth()
                    && date.getDate() === today.getDate()
            });
        }
        return result;
    }

    function monthTitle(year, month) {
        return new Date(year, month, 1).toLocaleDateString(undefined, {
            month: "long", year: "numeric"
        });
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.widget === "media" ? mediaCard
            : root.widget === "volume" ? volumeCard
            : root.widget === "battery" ? batteryCard
            : root.widget === "calendar" ? calendarCard
            : root.widget === "performance" ? performanceCard
            : root.widget === "tasks" ? tasksCard
            : root.widget === "timer" ? timerCard
            : root.widget === "recorder" ? recorderCard
            : root.widget === "system_info" ? systemCard
            : root.widget === "workspaces" ? workspacesCard
            : root.widget === "projects" ? projectsCard
            : root.widget === "power" ? powerCard
            : root.widget === "notifications" ? notificationsCard : emptyCard
    }

    Component {
        id: emptyCard
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            IslandCardHeader {
                palette: root.palette
                glyph: "\uf013"
                title: "Island"
                subtitle: "No card content available"
                onClicked: root.collapseRequested()
            }
        }
    }

    Component {
        id: mediaCard
        ColumnLayout {
            id: mediaView
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            property var player: root.mediaPlayer()

            IslandCardHeader {
                palette: root.palette
                glyph: "\uf001"
                title: "Media"
                subtitle: mediaView.player ? (mediaView.player.artist || mediaView.player.label) : "No player"
                value: mediaView.player ? (mediaView.player.state === "playing" ? "Playing" : "Paused") : ""
                onClicked: root.collapseRequested()
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 18
                Rectangle {
                    Layout.preferredWidth: 148
                    Layout.preferredHeight: 148
                    radius: 16
                    color: root.palette.surface
                    clip: true
                    Image {
                        id: albumArt
                        anchors.fill: parent
                        visible: !!mediaView.player && !!mediaView.player.art_url
                        source: mediaView.player ? mediaView.player.art_url : ""
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !albumArt.visible
                        text: "\uf001"
                        color: root.palette.foregroundMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 42
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: mediaView.player ? (mediaView.player.title || "Untitled") : "No track metadata"
                        color: root.palette.foreground
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: mediaView.player ? (mediaView.player.artist || "Unknown artist") : ""
                        color: root.palette.foregroundMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    IslandProgress {
                        islandPalette: root.palette
                        Layout.fillWidth: true
                        visible: !!mediaView.player && mediaView.player.length_supported
                        from: 0
                        to: Math.max(1, mediaView.player ? mediaView.player.length : 1)
                        value: Math.max(0, Math.min(to, mediaView.player ? mediaView.player.position : 0))
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: !!mediaView.player && mediaView.player.length_supported
                        Text {
                            text: root.formatTime(mediaView.player ? mediaView.player.position : 0)
                            color: root.palette.foregroundMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.formatTime(mediaView.player ? mediaView.player.length : 0)
                            color: root.palette.foregroundMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                    }
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                IslandButton {
                    palette: root.palette
                    glyph: "\uf048"
                    minimumWidth: 42
                    enabled: mediaView.player && mediaView.player.can_previous
                    onClicked: root.intent("media.previous", {id: mediaView.player.id})
                }
                IslandButton {
                    palette: root.palette
                    glyph: mediaView.player && mediaView.player.state === "playing" ? "\uf04c" : "\uf04b"
                    minimumWidth: 52
                    enabled: mediaView.player && (mediaView.player.can_play || mediaView.player.can_pause)
                    onClicked: root.intent("media.toggle", {id: mediaView.player.id})
                }
                IslandButton {
                    palette: root.palette
                    glyph: "\uf051"
                    minimumWidth: 42
                    enabled: mediaView.player && mediaView.player.can_next
                    onClicked: root.intent("media.next", {id: mediaView.player.id})
                }
            }
        }
    }

    Component {
        id: volumeCard
        ColumnLayout {
            id: volumeView
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            property var output: root.outputAudio()
            property var input: root.inputAudio()

            IslandCardHeader {
                palette: root.palette
                glyph: "\uf028"
                title: "Volume"
                subtitle: volumeView.output ? volumeView.output.label : "PipeWire unavailable"
                value: volumeView.output && volumeView.output.volume !== null
                    ? Math.round(volumeView.output.volume * 100) + "%" : "—"
                onClicked: root.collapseRequested()
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 22
                IslandRing {
                    Layout.preferredWidth: 132
                    Layout.preferredHeight: 132
                    speed: root.palette.speed
                    reduceMotion: root.reduceMotion
                    value: volumeView.output && volumeView.output.volume !== null ? volumeView.output.volume : 0
                    trackColor: root.palette.surfaceAlt
                    fillColor: root.palette.accent
                    lineWidth: 9
                    Text {
                        anchors.centerIn: parent
                        text: volumeView.output && volumeView.output.volume !== null
                            ? Math.round(volumeView.output.volume * 100) + "%" : "—"
                        color: root.palette.foreground
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 24
                        font.bold: true
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    IslandSlider {
                        id: volumeSlider
                        islandPalette: root.palette
                        reduceMotion: root.reduceMotion
                        Layout.fillWidth: true
                        from: 0
                        to: 1
                        value: volumeView.output && volumeView.output.volume !== null
                            ? volumeView.output.volume : 0
                        enabled: !!volumeView.output
                        onPressedChanged: if (!pressed) {
                            if (volumeView.output)
                                root.intent("audio.volume", {
                                    id: volumeView.output.id, volume: value
                                });
                            value = Qt.binding(function() {
                                return volumeView.output && volumeView.output.volume !== null
                                    ? volumeView.output.volume : 0;
                            });
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        IslandButton {
                            palette: root.palette
                            text: volumeView.output && volumeView.output.muted ? "Unmute" : "Mute"
                            glyph: "\uf130"
                            enabled: !!volumeView.output
                            onClicked: if (volumeView.output)
                                root.intent("audio.mute", {
                                    id: volumeView.output.id, muted: !volumeView.output.muted
                                })
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Scroll the island to adjust"
                            color: root.palette.foregroundMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                    }
                }
            }
            RowLayout {
                visible: !!volumeView.input
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: "Mic"
                    color: root.palette.foregroundMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }
                IslandSlider {
                    id: micSlider
                    Layout.fillWidth: true
                    islandPalette: root.palette
                    reduceMotion: root.reduceMotion
                    from: 0
                    to: 1
                    value: volumeView.input && volumeView.input.volume !== null
                        ? volumeView.input.volume : 0
                    enabled: !!volumeView.input
                    onPressedChanged: if (!pressed) {
                        if (volumeView.input)
                            root.intent("audio.volume", {
                                id: volumeView.input.id, volume: value
                            });
                        value = Qt.binding(function() {
                            return volumeView.input && volumeView.input.volume !== null
                                ? volumeView.input.volume : 0;
                        });
                    }
                }
                IslandButton {
                    palette: root.palette
                    text: volumeView.input && volumeView.input.muted ? "Unmute" : "Mute"
                    glyph: "\uf130"
                    enabled: !!volumeView.input
                    onClicked: if (volumeView.input)
                        root.intent("audio.mute", {
                            id: volumeView.input.id, muted: !volumeView.input.muted
                        })
                }
            }
        }
    }

    Component {
        id: batteryCard
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            IslandCardHeader {
                palette: root.palette
                glyph: "\uf240"
                title: "Battery"
                subtitle: root.battery.state || "Battery unavailable"
                value: root.battery.percent !== null ? Math.round(root.battery.percent) + "%" : "—"
                onClicked: root.collapseRequested()
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 26
                IslandRing {
                    Layout.preferredWidth: 154
                    Layout.preferredHeight: 154
                    speed: root.palette.speed
                    reduceMotion: root.reduceMotion
                    value: root.battery.percent !== null ? root.battery.percent / 100 : 0
                    trackColor: root.palette.surfaceAlt
                    fillColor: root.battery.state === "Charging" ? root.palette.green : root.palette.accent
                    lineWidth: 10
                    phase: root.battery.state === "Charging" ? root.phase : 0
                    Text {
                        anchors.centerIn: parent
                        text: root.battery.percent !== null ? Math.round(root.battery.percent) + "%" : "—"
                        color: root.palette.foreground
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 24
                        font.bold: true
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        text: root.battery.state === "Charging" ? "Charging" : "On battery"
                        color: root.palette.foreground
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Text {
                        visible: root.battery.rate_known
                        text: "Power " + Number(root.battery.rate).toFixed(1) + " W"
                        color: root.palette.foregroundMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }
                    Text {
                        visible: root.battery.capacity !== null
                        text: Number(root.battery.energy || 0).toFixed(1) + " / "
                            + Number(root.battery.capacity || 0).toFixed(1) + " Wh"
                        color: root.palette.foregroundMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }

    Component {
        id: calendarCard
        Item {
            id: calendarView
            anchors.fill: parent
            property int year: new Date().getFullYear()
            property int month: new Date().getMonth()
            property var cells: root.calendarCells(year, month)
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    IslandCardHeader {
                        Layout.fillWidth: true
                        palette: root.palette
                        glyph: "\uf073"
                        title: "Calendar"
                        subtitle: root.monthTitle(calendarView.year, calendarView.month)
                        onClicked: root.collapseRequested()
                    }
                    IslandButton {
                        palette: root.palette
                        glyph: "\uf104"
                        minimumWidth: 36
                        onClicked: {
                            if (calendarView.month === 0) {
                                calendarView.month = 11;
                                --calendarView.year;
                            } else {
                                --calendarView.month;
                            }
                        }
                    }
                    IslandButton {
                        palette: root.palette
                        glyph: "\uf105"
                        minimumWidth: 36
                        onClicked: {
                            if (calendarView.month === 11) {
                                calendarView.month = 0;
                                ++calendarView.year;
                            } else {
                                ++calendarView.month;
                            }
                        }
                    }
                }
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]
                        delegate: Text {
                            required property string modelData
                            width: 34
                            text: modelData
                            horizontalAlignment: Text.AlignHCenter
                            color: root.palette.foregroundMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                    }
                }
                GridLayout {
                    Layout.alignment: Qt.AlignHCenter
                    columns: 7
                    rowSpacing: 6
                    columnSpacing: 8
                    Repeater {
                        model: calendarView.cells
                        delegate: Rectangle {
                            required property var modelData
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 30
                            radius: 15
                            color: modelData.today ? root.palette.accent : "#00000000"
                            border.width: modelData.today ? 0 : 1
                            border.color: modelData.inMonth
                                ? Qt.rgba(root.palette.foreground.r, root.palette.foreground.g,
                                    root.palette.foreground.b, 0.08) : "#00000000"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                color: modelData.today ? root.palette.background
                                    : (modelData.inMonth ? root.palette.foreground : root.palette.muted)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                font.bold: modelData.today
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: performanceCard
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            IslandCardHeader {
                palette: root.palette
                glyph: "\uf201"
                title: "Performance"
                subtitle: "Live facts from /proc"
                onClicked: root.collapseRequested()
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14
                Loader {
                    id: cpuTile
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: perfTile
                    onLoaded: {
                        item.palette = root.palette;
                        item.title = "CPU";
                        item.value = Qt.binding(function() {
                            return root.performance.cpu !== null
                                ? Math.round(root.performance.cpu) + "%" : "—";
                        });
                        item.detail = Qt.binding(function() {
                            return root.performance.load !== null
                                ? "load " + Number(root.performance.load).toFixed(2)
                                : "load unavailable";
                        });
                        item.values = Qt.binding(function() {
                            return root.performance.cpu_samples || [];
                        });
                        item.lineColor = root.palette.accent;
                    }
                }
                Loader {
                    id: memoryTile
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: perfTile
                    onLoaded: {
                        item.palette = root.palette;
                        item.title = "Memory";
                        item.value = Qt.binding(function() {
                            return root.performance.memory !== null
                                ? Math.round(root.performance.memory) + "%" : "—";
                        });
                        item.detail = Qt.binding(function() {
                            return root.performance.memory_used !== null
                                ? root.formatBytes(root.performance.memory_used) + " / "
                                    + root.formatBytes(root.performance.memory_total)
                                : "memory unavailable";
                        });
                        item.values = Qt.binding(function() {
                            return root.performance.memory_samples || [];
                        });
                        item.lineColor = root.palette.cyan;
                    }
                }
            }
        }
    }

    Component {
        id: tasksCard
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14
            IslandCardHeader {
                palette: root.palette
                glyph: "\uf00c"
                title: "Tasks"
                subtitle: root.tasks.length ? root.tasks.length + " local tasks" : "Local shell storage"
                value: root.tasks.filter(function(item) { return !item.done; }).length + " open"
                onClicked: root.collapseRequested()
            }
            RowLayout {
                Layout.fillWidth: true
                TextField {
                    id: taskInput
                    Layout.fillWidth: true
                    placeholderText: "New task"
                    color: root.palette.foreground
                    placeholderTextColor: root.palette.foregroundMuted
                    onAccepted: {
                        root.intent("task.add", {title: text});
                        clear();
                    }
                }
                IslandButton {
                    palette: root.palette
                    glyph: "\uf067"
                    text: "New"
                    enabled: taskInput.text.length > 0
                    onClicked: {
                        root.intent("task.add", {title: taskInput.text});
                        taskInput.clear();
                    }
                }
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: root.tasks
                delegate: Rectangle {
                    id: taskRow
                    required property var modelData
                    width: ListView.view.width
                    property bool settledDone: false
                    height: settledDone ? 0 : 42
                    radius: 12
                    clip: true
                    opacity: settledDone ? 0 : 1
                    color: Qt.rgba(root.palette.surface.r, root.palette.surface.g,
                        root.palette.surface.b, 0.32)
                    Component.onCompleted: if (modelData.done) collapseAnimation.start()
                    onModelDataChanged: {
                        if (modelData.done) {
                            settledDone = false;
                            collapseAnimation.restart();
                        } else {
                            collapseAnimation.stop();
                            settledDone = false;
                        }
                    }
                    SequentialAnimation {
                        id: collapseAnimation
                        PauseAnimation { duration: Motion.scaled(400, root.palette.speed) }
                        ScriptAction { script: taskRow.settledDone = true }
                    }
                    Behavior on height {
                        SpringAnimation {
                            spring: Motion.spring(Motion.primary, root.palette.speed,
                                root.reduceMotion)
                            damping: Motion.damping(Motion.primary, root.reduceMotion)
                            mass: Motion.primary.mass
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Motion.duration(Motion.content.duration,
                                root.palette.speed, root.reduceMotion)
                            easing.type: Easing.OutCubic
                        }
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10
                        CheckBox {
                            id: taskCheck
                            checked: modelData.done
                            onClicked: root.intent("task.complete", {
                                id: modelData.id, done: checked
                            })
                            indicator: Rectangle {
                                implicitWidth: 22
                                implicitHeight: 22
                                x: taskCheck.leftPadding
                                y: (taskCheck.height - height) / 2
                                radius: 7
                                color: taskCheck.checked
                                    ? root.palette.accent : Qt.rgba(root.palette.surfaceAlt.r,
                                        root.palette.surfaceAlt.g, root.palette.surfaceAlt.b, 0.45)
                                border.width: 1
                                border.color: taskCheck.checked
                                    ? root.palette.accent : root.palette.rim
                                Text {
                                    anchors.centerIn: parent
                                    visible: taskCheck.checked
                                    text: "\uf00c"
                                    color: root.palette.background
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.title
                            color: root.palette.foreground
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            font.strikeout: modelData.done
                        }
                        Text {
                            text: modelData.due || "today"
                            color: root.palette.foregroundMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                    }
                }
            }
            Text {
                visible: root.tasks.length === 0
                text: "No tasks yet."
                color: root.palette.foregroundMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
            }
        }
    }

    Component {
        id: timerCard
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            IslandCardHeader {
                palette: root.palette
                glyph: "\uf017"
                title: "Timer / Pomodoro"
                subtitle: root.timerName || "Focus"
                value: root.formatTime(root.timerRemaining)
                onClicked: root.collapseRequested()
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 26
                IslandRing {
                    Layout.preferredWidth: 170
                    Layout.preferredHeight: 170
                    speed: root.palette.speed
                    reduceMotion: root.reduceMotion
                    value: root.timerTotal > 0 ? root.timerRemaining / root.timerTotal : 0
                    trackColor: root.palette.surfaceAlt
                    fillColor: root.palette.orange
                    lineWidth: 10
                    Text {
                        anchors.centerIn: parent
                        text: root.formatTime(root.timerRemaining)
                        color: root.palette.foreground
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 25
                        font.bold: true
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        text: root.timerRunning ? "Running"
                            : (root.timerRemaining > 0 ? "Held" : "Ready")
                        color: root.palette.foreground
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        IslandButton {
                            palette: root.palette
                            text: root.timerRunning ? "Hold" : "Resume"
                            glyph: root.timerRunning ? "\uf04c" : "\uf04b"
                            onClicked: root.intent("timer.toggle", {})
                        }
                        IslandButton {
                            palette: root.palette
                            text: "Stop"
                            glyph: "\uf04d"
                            enabled: root.timerRemaining > 0
                            onClicked: root.intent("timer.stop", {})
                        }
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        IslandButton {
                            palette: root.palette
                            text: "25 min"
                            onClicked: root.intent("timer.start", {
                                seconds: 1500, name: "Pomodoro"
                            })
                        }
                        IslandButton {
                            palette: root.palette
                            text: "5 min"
                            onClicked: root.intent("timer.start", {
                                seconds: 300, name: "Break"
                            })
                        }
                    }
                }
            }
        }
    }

    Component {
        id: recorderCard
        ColumnLayout {
            id: recorderView
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            property string recordingState: root.recording && root.recording.data
                ? root.recording.data.state : "unavailable"
            IslandCardHeader {
                palette: root.palette
                glyph: "\uf03d"
                title: "Screen recorder"
                subtitle: recorderView.recordingState === "recording"
                    ? "wf-recorder is active" : "Region capture"
                value: recorderView.recordingState
                onClicked: root.collapseRequested()
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                Text {
                    text: "Region"
                    color: root.palette.foreground
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    font.bold: true
                }
                Text {
                    text: "The existing recorder selects a Wayland region."
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    color: root.palette.foregroundMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }
                IslandButton {
                    palette: root.palette
                    text: recorderView.recordingState === "recording" ? "Stop" : "Record"
                    glyph: recorderView.recordingState === "recording" ? "\uf04d" : "\uf03d"
                    destructive: recorderView.recordingState === "recording"
                    onClicked: root.intent(recorderView.recordingState === "recording"
                        ? "recorder.stop" : "recorder.start", {})
                }
            }
        }
    }

    Component {
        id: systemCard
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            IslandCardHeader {
                palette: root.palette
                glyph: "\uf2bd"
                title: "System info"
                subtitle: root.systemInfo.hostname || "Workstation"
                onClicked: root.collapseRequested()
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 20
                Rectangle {
                    Layout.preferredWidth: 88
                    Layout.preferredHeight: 88
                    radius: 44
                    color: root.palette.accent
                    Text {
                        anchors.centerIn: parent
                        text: (root.systemInfo.hostname || "W").slice(0, 1).toUpperCase()
                        color: root.palette.background
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 34
                        font.bold: true
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        text: root.systemInfo.distro || "blendOS"
                        color: root.palette.foreground
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Text {
                        text: "WM  ·  " + (root.systemInfo.compositor || "Hyprland")
                        color: root.palette.foregroundMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }
                    Text {
                        text: "Uptime  ·  " + root.formatUptime(root.systemInfo.uptime_seconds)
                        color: root.palette.foregroundMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }

    Component {
        id: workspacesCard
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14
            IslandCardHeader {
                palette: root.palette
                glyph: "\uf00a"
                title: "Workspaces"
                subtitle: "Hyprland overview · thumbnails unavailable"
                onClicked: root.collapseRequested()
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8
                Repeater {
                    model: root.workspaces
                    delegate: IslandButton {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData.name + (modelData.urgent ? "  !" : "")
                        glyph: modelData.focused ? "\uf111" : "\uf10c"
                        active: modelData.active
                        destructive: modelData.urgent
                        onClicked: root.intent("workspace.activate", {id: modelData.id})
                    }
                }
            }
        }
    }

    Component {
        id: projectsCard
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12
            IslandCardHeader {
                palette: root.palette
                glyph: "\uf1d8"
                title: "Projects & agents"
                subtitle: root.projects.length ? "Choose a project" : "No registered projects"
                value: root.runs.length ? root.runs.length + " runs" : ""
                onClicked: root.collapseRequested()
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.projects
                    delegate: IslandButton {
                        required property var modelData
                        width: ListView.view.width
                        text: modelData.label
                        glyph: modelData.directory_available ? "\uf07b" : "\uf071"
                        active: modelData.id === root.selectedProjectId
                        enabled: modelData.directory_available
                        onClicked: root.intent("project.select", {id: modelData.id})
                    }
                }
                ColumnLayout {
                    Layout.preferredWidth: 220
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignTop
                    Text {
                        text: "Recent runs"
                        color: root.palette.foregroundMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: root.runs
                        delegate: Text {
                            required property var modelData
                            width: ListView.view.width
                            text: modelData.label + " · " + modelData.state
                            color: modelData.state === "failed"
                                ? root.palette.red : root.palette.foreground
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                IslandButton {
                    palette: root.palette
                    text: "Terminal"
                    glyph: "\uf120"
                    enabled: root.selectedProjectId.length > 0
                    onClicked: root.intent("project.open", {
                        id: root.selectedProjectId, mode: "terminal"
                    })
                }
                IslandButton {
                    palette: root.palette
                    text: "Editor"
                    glyph: "\uf121"
                    enabled: root.selectedProjectId.length > 0
                    onClicked: root.intent("project.open", {
                        id: root.selectedProjectId, mode: "editor"
                    })
                }
            }
        }
    }

    Component {
        id: notificationsCard
        ColumnLayout {
            id: notificationView
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12
            property var notificationState: root.notificationData

            IslandCardHeader {
                palette: root.palette
                glyph: "\uf0a2"
                title: "Notifications"
                subtitle: root.notifications.status === "ready"
                    ? (notificationView.notificationState.dnd ? "Paused" : "Dunst history")
                    : "History unavailable"
                value: notificationView.notificationState.unread_count === null
                    ? notificationView.notificationState.items.length + " stored"
                    : notificationView.notificationState.unread_count + " unread"
                onClicked: root.collapseRequested()
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                IslandButton {
                    objectName: "notificationDnd"
                    palette: root.palette
                    text: notificationView.notificationState.dnd ? "Resume" : "Pause"
                    glyph: notificationView.notificationState.dnd ? "\uf144" : "\uf04c"
                    enabled: root.notifications.status === "ready"
                    onClicked: root.intent("notifications.set_dnd", {
                        paused: !notificationView.notificationState.dnd
                    })
                }
                IslandButton {
                    objectName: "notificationClear"
                    palette: root.palette
                    text: "Clear history"
                    glyph: "\uf2ed"
                    enabled: root.notifications.status === "ready"
                        && notificationView.notificationState.items.length > 0
                    destructive: true
                    onClicked: root.intent("notifications.clear", {})
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.notifications.status === "ready"
                        ? "Live popup actions stay with Dunst"
                        : "The notification service is unavailable"
                    color: root.palette.foregroundMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.maximumWidth: 280
                }
            }
            Text {
                objectName: "notificationUnavailable"
                visible: root.notifications.status !== "ready"
                text: "Open this card again after Dunst reconnects."
                color: root.palette.foregroundMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Text {
                objectName: "notificationEmpty"
                visible: root.notifications.status === "ready"
                    && notificationView.notificationState.items.length === 0
                text: "No stored notifications."
                color: root.palette.foregroundMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                Layout.fillWidth: true
            }
            ListView {
                id: notificationList
                objectName: "notificationList"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                clip: true
                spacing: 8
                model: notificationView.notificationState.items
                delegate: Rectangle {
                    id: notificationRow
                    required property var modelData
                    objectName: "notification-" + modelData.id
                    width: ListView.view.width
                    height: notificationBody.implicitHeight + 20
                    radius: 12
                    color: Qt.rgba(root.palette.surface.r, root.palette.surface.g,
                        root.palette.surface.b, 0.34)
                    border.width: 1
                    border.color: root.palette.rim

                    ColumnLayout {
                        id: notificationBody
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: notificationRow.modelData.urgency === "critical"
                                    ? "\uf06a" : "\uf0f3"
                                color: notificationRow.modelData.urgency === "critical"
                                    ? root.palette.red : root.palette.accent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: notificationRow.modelData.summary
                                    color: root.palette.foreground
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: notificationRow.modelData.app_label
                                    color: root.palette.foregroundMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            Text {
                                text: notificationRow.modelData.timestamp
                                color: root.palette.foregroundMuted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                elide: Text.ElideLeft
                                Layout.maximumWidth: 170
                            }
                        }
                        Text {
                            visible: notificationRow.modelData.body.length > 0
                            text: notificationRow.modelData.body
                            textFormat: Text.PlainText
                            color: root.palette.foreground
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            maximumLineCount: 3
                            Layout.fillWidth: true
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }
                            IslandButton {
                                objectName: "notificationShow-" + notificationRow.modelData.id
                                palette: root.palette
                                text: "Show"
                                glyph: "\uf06e"
                                onClicked: root.intent("notifications.show", {
                                    id: notificationRow.modelData.id
                                })
                            }
                            IslandButton {
                                objectName: "notificationDismiss-" + notificationRow.modelData.id
                                palette: root.palette
                                text: "Dismiss"
                                glyph: "\uf00d"
                                destructive: true
                                onClicked: root.intent("notifications.dismiss", {
                                    id: notificationRow.modelData.id
                                })
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: powerCard
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            IslandCardHeader {
                palette: root.palette
                glyph: "\uf011"
                title: "Power"
                subtitle: "Session actions"
                onClicked: root.collapseRequested()
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: 10
                columnSpacing: 10
                Repeater {
                    model: root.power && root.power.data ? root.power.data.actions : []
                    delegate: IslandButton {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData.id === root.powerConfirmation
                            ? "Confirm " + modelData.id
                            : modelData.id.charAt(0).toUpperCase() + modelData.id.slice(1)
                        glyph: modelData.id === "lock" ? "\uf023"
                            : modelData.id === "suspend" ? "\uf186" : "\uf011"
                        destructive: ["reboot", "shutdown", "logout"].indexOf(modelData.id) >= 0
                        enabled: modelData.available
                        onClicked: root.intent("power." + modelData.id, {
                            confirmed: modelData.id === root.powerConfirmation
                        })
                    }
                }
            }
            Text {
                visible: root.powerConfirmation.length > 0
                text: "Choose the same action again to confirm."
                color: root.palette.yellow
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
            }
        }
    }

    Component {
        id: perfTile
        Rectangle {
            id: perfRoot
            property var palette: null
            property string title: ""
            property string value: "—"
            property string detail: ""
            property var values: []
            property color lineColor: "#89b4fa"
            radius: 18
            color: perfRoot.palette && perfRoot.palette.surface
                ? Qt.rgba(perfRoot.palette.surface.r, perfRoot.palette.surface.g,
                    perfRoot.palette.surface.b, 0.34) : "#303040"
            border.color: perfRoot.palette && perfRoot.palette.rim
                ? perfRoot.palette.rim : "#506080"
            border.width: 1
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8
                Text {
                    text: perfRoot.title
                    color: perfRoot.palette && perfRoot.palette.foregroundMuted
                        ? perfRoot.palette.foregroundMuted : "#a6adc8"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }
                Text {
                    text: perfRoot.value
                    color: perfRoot.palette && perfRoot.palette.foreground
                        ? perfRoot.palette.foreground : "#cdd6f4"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 24
                    font.bold: true
                }
                Text {
                    text: perfRoot.detail
                    color: perfRoot.palette && perfRoot.palette.foregroundMuted
                        ? perfRoot.palette.foregroundMuted : "#a6adc8"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                Canvas {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    property var points: perfRoot.values
                    onPointsChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        if (points.length < 2) return;
                        ctx.beginPath();
                        for (var i = 0; i < points.length; ++i) {
                            var x = i / (points.length - 1) * width;
                            var y = height - Math.max(0, Math.min(100, points[i])) / 100 * height;
                            if (i === 0) ctx.moveTo(x, y);
                            else ctx.lineTo(x, y);
                        }
                        ctx.lineWidth = 2;
                        ctx.strokeStyle = perfRoot.lineColor;
                        ctx.stroke();
                    }
                }
            }
        }
    }
}
