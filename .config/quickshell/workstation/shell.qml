//@ pragma UseQApplication
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "adapters"
import "surfaces"
import "models/IslandConfig.js" as IslandConfig
import "models/IslandMotion.js" as Motion
import WorkstationShared 1.0

ShellRoot {
    id: root

    readonly property bool preview: Quickshell.env("WORKSTATION_SHELL_PREVIEW") === "1"
    readonly property bool previewControls: preview
        && Quickshell.env("WORKSTATION_SHELL_PREVIEW_CONTROLS") === "1"
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME")
        || home + "/.local/state"
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME")
        || home + "/.config"
    readonly property string configPath: configHome
        + "/quickshell/workstation/island.json"
    property var theme: null
    property var config: IslandConfig.defaults
    property var fixture: ({})
    property string message: ""

    property string surfaceState: "compact"
    property string cardWidget: "calendar"
    property int dashboardTab: 0
    property string expandedOutputId: ""
    property string activeOutputId: ""
    property string hoveredOutputId: ""
    property string hoveredKey: ""
    property string hoverOpenKey: ""
    property string attentionKind: ""
    property string attentionGlyph: "\uf129"
    property string attentionTitle: ""
    property string attentionDetail: ""
    property real attentionValue: -1
    property bool attentionMuted: false
    property string attentionOutputId: ""
    property string attentionExpiresAt: ""
    property var attentionQueue: []
    property bool debugMode: false
    property string debugPrimary: ""
    property string debugSecondary: ""
    property int nowToken: 0
    property real phase: 0
    property int timerRemaining: 0
    property int timerTotal: 0
    property bool timerRunning: false
    property string timerName: ""
    property string controlSection: "audio"
    property real observedVolume: -1
    property int observedOutputMuted: -1
    property real observedInputVolume: -1
    property int observedInputMuted: -1
    property real observedBatteryPercent: -1
    property string observedBatteryState: ""
    property bool powerConfirmation: false
    property string powerConfirmationId: ""
    property bool configReady: false
    property bool themeReady: false
    property string selectedProject: ""

    readonly property bool darkTheme: config.theme_mode === "dark" ? true
        : config.theme_mode === "light" ? false : (theme ? theme.mode === "dark" : true)
    readonly property bool reduceMotion: config.reduce_motion === true
    readonly property var audioSnapshot: preview
        ? (fixture.audio || Contract.unavailable("audio")) : sources.audioSnapshot
    readonly property var mediaSnapshot: preview
        ? (fixture.media || Contract.unavailable("media")) : sources.mediaSnapshot
    readonly property var audioData: {
        var data = snapshotData(root.audioSnapshot, {items: []});
        return {
            status: root.audioSnapshot ? root.audioSnapshot.status : "unavailable",
            default_output_id: data.default_output_id || null,
            default_input_id: data.default_input_id || null,
            items: data.items || []
        };
    }
    readonly property var mediaItems: snapshotData(mediaSnapshot, {items: []}).items || []
    readonly property var performance: preview && fixture.performance
        ? fixture.performance : sources.performance
    readonly property var battery: preview && fixture.battery
        ? fixture.battery : sources.battery
    readonly property var systemInfo: preview && fixture.system_info
        ? fixture.system_info : sources.systemInfo
    readonly property var recordingSnapshot: preview
        ? (fixture.recording || Contract.unavailable("recording"))
        : (backend.snapshots.recording || Contract.unavailable("recording"))
    readonly property var powerSnapshot: preview
        ? (fixture.power || Contract.unavailable("power"))
        : (backend.snapshots.power || Contract.unavailable("power"))
    readonly property var notificationsSnapshot: preview
        ? (fixture.notifications || Contract.unavailable("notifications"))
        : (backend.snapshots.notifications || Contract.unavailable("notifications"))
    readonly property var tasks: tasksStore.items
    readonly property var workspaces: desktopBackend
        ? desktopBackend.workspaceSnapshot.items : []
    readonly property var projects: preview
        ? ((fixture.projects && fixture.projects.data)
            ? fixture.projects.data.items : (fixture.projects || []))
        : backend.projects
    readonly property var runs: preview
        ? ((fixture.agent_runs && fixture.agent_runs.data)
            ? fixture.agent_runs.data.items : (fixture.agent_runs || []))
        : backend.runs
    readonly property string selectedProjectId: selectedProject
    readonly property bool mediaPlaying: mediaItems.some(function(row) {
        return row.state === "playing";
    })
    readonly property bool recorderRunning: recordingSnapshot
        && recordingSnapshot.status === "ready" && recordingSnapshot.data
        && ["starting", "recording", "stopping"].indexOf(recordingSnapshot.data.state) >= 0
    readonly property bool timerActive: timerRunning && timerRemaining > 0
    readonly property var activities: root.activityList()
    readonly property string activitySignature: activities.join("|")
    readonly property string primaryActivity: activities.length ? activities[0] : ""
    readonly property string secondaryActivity: activities.length > 1 ? activities[1] : ""

    IslandPalette {
        id: islandPalette
        source: root.theme ? root.theme.colors : ({})
        dark: root.darkTheme
        speed: Number(root.config.animation_speed) || 1
    }

    IslandSources {
        id: sources
        observing: !root.preview
        onBrightnessAttention: percent => root.enqueueAttention(
            "brightness", "Brightness", Math.round(percent) + "%", "\uf185", percent)
    }

    TasksStore { id: tasksStore }

    Desktop {
        id: desktopBackend
        observeOutputs: !root.preview
    }

    WorkstationData {
        id: backend
        socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "")
            + "/blendos-workstation/data.sock"
        observing: !root.preview
        topics: root.dataTopics()
        metrics: IslandConfig.enabled(root.config, "projects")
    }

    ElephantLauncher {
        id: launcherBackend
        socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "")
            + "/blendos-workstation/launcher.sock"
        observing: !root.preview && root.surfaceState === "launcher"
        onActivated: (success, detail) => {
            if (success) root.collapse();
            else root.message = detail;
        }
    }

    Controls {
        id: controlsBackend
        observing: !root.preview
        preview: root.preview
        section: root.controlSection
        fixture: root.fixture
        sharedSnapshots: backend.snapshots
        outputSnapshot: desktopBackend
            ? desktopBackend.outputSnapshot : Contract.unavailable("outputs")
    }

    FileView {
        id: themeFile
        path: root.stateHome + "/blendos-workstation/theme/current/workstation-shell.json"
        printErrors: false
        watchChanges: true
        onLoaded: root.loadTheme()
        onFileChanged: root.loadTheme()
        onLoadFailed: {
            if (!root.theme) {
                root.message = "Theme release unavailable; activate a workstation theme.";
                console.error(root.message);
                Qt.exit(1);
            }
        }
    }

    FileView {
        id: configFile
        path: root.configPath
        printErrors: false
        watchChanges: true
        onLoaded: root.reloadConfig()
        onFileChanged: root.reloadConfig()
        onLoadFailed: {
            root.config = IslandConfig.defaults;
            root.configReady = true;
        }
    }

    FileView {
        id: fixtureFile
        path: root.preview ? Quickshell.env("WORKSTATION_SHELL_FIXTURE") : ""
        printErrors: false
        onLoaded: {
            try {
                var value = JSON.parse(text());
                root.fixture = value && typeof value === "object" ? value : ({});
            } catch (error) {
                console.error("Invalid workstation preview fixture.");
                Qt.quit();
            }
        }
        onLoadFailed: if (root.preview) {
            console.error("Preview fixture unavailable.");
            Qt.quit();
        }
    }

    Timer {
        id: scheduler
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            ++root.nowToken;
            root.phase += Math.PI / 8;
            sources.tick();
            if (root.timerRunning) {
                if (root.timerRemaining > 0) --root.timerRemaining;
                if (root.timerRemaining <= 0) {
                    root.timerRemaining = 0;
                    root.timerRunning = false;
                    root.enqueueAttention("timer-finished", "Timer finished",
                        root.timerName || "Focus session complete", "\uf017", -1);
                }
            }
        }
    }

    Timer {
        id: hoverOpen
        interval: Motion.scaled(Motion.hoverIntentDelay, root.config.animation_speed)
        repeat: false
        onTriggered: {
            if (!root.hoverOpenKey.length || root.hoverOpenKey !== root.hoveredKey)
                return;
            var widget = root.hoverOpenKey === "island"
                ? root.hoverWidget() : root.hoverOpenKey;
            if (widget.length) root.openCard(widget, root.hoveredOutputId);
        }
    }

    Timer {
        id: collapseGrace
        interval: Motion.scaled(Motion.hoverGrace, root.config.animation_speed)
        repeat: false
        onTriggered: if (!root.hoveredKey.length && (root.surfaceState === "expanded"
                || root.surfaceState === "launcher"))
            root.collapse()
    }

    Timer {
        id: attentionHold
        interval: Motion.scaled(Motion.attentionHold, root.config.animation_speed)
        repeat: false
        onTriggered: {
            if (root.hoveredKey.length) attentionHold.restart();
            else root.finishAttention();
        }
    }

    Process {
        id: launchAction
        stdout: SplitParser { onRead: {} }
        stderr: SplitParser { onRead: {} }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            root.message = exitCode === 0 && exitStatus === 0
                ? "Launch requested." : "Launch failed.";
            command = [];
        }
        // qmllint enable signal-handler-parameters
    }

    function snapshotData(snapshot, fallback) {
        if (!snapshot || snapshot.status !== "ready" || !snapshot.data)
            return fallback;
        return snapshot.data;
    }

    function reloadConfig() {
        root.config = IslandConfig.normalize(configFile.text());
        root.configReady = true;
        if (root.surfaceState === "expanded" && !widgetEnabled(root.cardWidget))
            root.collapse();
    }

    function loadTheme() {
        try {
            root.theme = Contract.theme(themeFile.text());
            root.themeReady = true;
            root.message = "";
        } catch (error) {
            root.message = "Theme release is invalid.";
            if (!root.theme) Qt.exit(1);
        }
    }

    function widgetEnabled(widget) {
        return IslandConfig.enabled(root.config, widget);
    }

    function dataTopics() {
        var result = ["recording", "power"];
        if (IslandConfig.enabled(root.config, "projects"))
            result = result.concat(["projects", "agent_runs"]);
        if (root.surfaceState === "expanded" && root.cardWidget === "notifications")
            result.push("notifications");
        return result;
    }

    function activityList() {
        if (root.debugMode) {
            var debug = [];
            if (root.debugPrimary.length) debug.push(root.debugPrimary);
            if (root.debugSecondary.length) debug.push(root.debugSecondary);
            return debug;
        }
        var result = [];
        if (root.mediaPlaying && widgetEnabled("media")) result.push("media");
        if (root.timerActive && widgetEnabled("timer")) result.push("timer");
        if (root.recorderRunning && widgetEnabled("recorder")) result.push("recorder");
        return result;
    }

    function hoverWidget() {
        if (root.primaryActivity.length) return root.primaryActivity;
        if (root.cardWidget && widgetEnabled(root.cardWidget)
                && root.surfaceState === "expanded") return root.cardWidget;
        return "";
    }

    function widgetAvailable(widget) {
        if (!widgetEnabled(widget)) return false;
        if (widget === "media") return root.mediaItems.length > 0;
        if (widget === "volume") return root.audioSnapshot.status === "ready"
            && root.audioData.items && root.audioData.items.length > 0;
        if (widget === "battery") return root.battery && root.battery.status === "ready";
        if (widget === "performance") return root.performance
            && root.performance.status === "ready";
        if (widget === "recorder") return root.recordingSnapshot.status === "ready";
        if (widget === "power") return root.powerSnapshot.status === "ready";
        if (widget === "notifications") return true;
        if (widget === "workspaces") return root.workspaces.length > 0;
        if (widget === "projects") return root.projects.length > 0;
        return ["calendar", "tasks", "timer", "system_info"].indexOf(widget) >= 0;
    }

    function dashboardTabCount() {
        var count = 1;
        if (widgetAvailable("media")) ++count;
        if (widgetAvailable("performance")) ++count;
        if (widgetAvailable("workspaces")) ++count;
        return count;
    }

    function clampDashboardTab() {
        root.dashboardTab = Math.max(0, Math.min(
            root.dashboardTabCount() - 1, root.dashboardTab));
    }

    function defaultOutputId() {
        var rows = desktopBackend && desktopBackend.outputSnapshot
            && desktopBackend.outputSnapshot.status === "ready"
            ? desktopBackend.outputSnapshot.data.items : [];
        for (var i = 0; i < rows.length; ++i)
            if (rows[i].focused) return rows[i].id;
        return Quickshell.screens.length ? Quickshell.screens[0].name : "";
    }

    function openCard(widget, outputId) {
        if (!widgetAvailable(widget)) return false;
        root.activeOutputId = outputId || root.activeOutputId || root.defaultOutputId();
        root.expandedOutputId = root.activeOutputId;
        root.cardWidget = widget;
        root.dashboardTab = 0;
        root.debugMode = false;
        hoverOpen.stop();
        collapseGrace.stop();
        attentionHold.stop();
        if (root.surfaceState !== "expanded")
            root.surfaceState = "expanded";
        return true;
    }

    function openDashboard(outputId) {
        root.activeOutputId = outputId || root.activeOutputId || root.defaultOutputId();
        root.expandedOutputId = root.activeOutputId;
        root.dashboardTab = 0;
        root.debugMode = false;
        hoverOpen.stop();
        collapseGrace.stop();
        attentionHold.stop();
        root.surfaceState = "dashboard";
    }

    function openLauncher(outputId) {
        root.activeOutputId = outputId || root.activeOutputId || root.defaultOutputId();
        root.expandedOutputId = root.activeOutputId;
        root.debugMode = false;
        root.powerConfirmation = false;
        root.powerConfirmationId = "";
        hoverOpen.stop();
        collapseGrace.stop();
        attentionHold.stop();
        root.surfaceState = "launcher";
        launcherBackend.query = "";
    }

    function collapse() {
        hoverOpen.stop();
        collapseGrace.stop();
        root.expandedOutputId = "";
        root.powerConfirmation = false;
        root.powerConfirmationId = "";
        if (root.surfaceState === "attention") {
            root.finishAttention();
            return;
        }
        root.surfaceState = root.activities.length > 1 ? "split"
            : root.activities.length === 1 ? "activity" : "compact";
    }

    function handleHover(outputId, key, hovered) {
        if (hovered) {
            root.activeOutputId = outputId;
            root.hoveredOutputId = outputId;
            root.hoveredKey = key;
            root.hoverOpenKey = key;
            collapseGrace.stop();
            if (key === "island" || widgetAvailable(key)) hoverOpen.restart();
        } else if (root.hoveredOutputId === outputId && root.hoveredKey === key) {
            root.hoveredKey = "";
            root.hoverOpenKey = "";
            hoverOpen.stop();
            if (root.surfaceState === "expanded" || root.surfaceState === "dashboard"
                    || root.surfaceState === "launcher")
                collapseGrace.restart();
        }
    }

    function reconcileActivity() {
        if (root.surfaceState === "attention" || root.surfaceState === "expanded"
                || root.surfaceState === "dashboard" || root.surfaceState === "launcher") return;
        root.surfaceState = root.activities.length > 1 ? "split"
            : root.activities.length === 1 ? "activity" : "compact";
    }

    function enqueueAttention(kind, title, detail, glyph, value, muted, outputId) {
        var event = {
            kind: String(kind), title: String(title), detail: String(detail),
            glyph: glyph || "\uf129", value: value === undefined ? -1 : Number(value),
            muted: muted === true, outputId: outputId ? String(outputId) : "",
            expiresAt: new Date(Date.now()
                + Motion.scaled(Motion.attentionHold, root.config.animation_speed)).toISOString()
        };
        if (root.surfaceState === "attention" && root.attentionKind === event.kind) {
            root.attentionTitle = event.title;
            root.attentionDetail = event.detail;
            root.attentionGlyph = event.glyph;
            root.attentionValue = event.value;
            root.attentionMuted = event.muted;
            root.attentionOutputId = event.outputId;
            root.attentionExpiresAt = event.expiresAt;
            attentionHold.restart();
            return;
        }
        if (root.surfaceState === "attention") {
            root.attentionQueue = root.attentionQueue.concat([event]);
            return;
        }
        root.showAttention(event);
    }

    function showAttention(event) {
        root.attentionKind = event.kind;
        root.attentionTitle = event.title;
        root.attentionDetail = event.detail;
        root.attentionGlyph = event.glyph;
        root.attentionValue = event.value;
        root.attentionMuted = event.muted === true;
        root.attentionOutputId = event.outputId || "";
        root.attentionExpiresAt = event.expiresAt || "";
        root.surfaceState = "attention";
        attentionHold.restart();
    }

    function finishAttention() {
        if (root.attentionQueue.length) {
            var queue = root.attentionQueue.slice();
            var next = queue.shift();
            root.attentionQueue = queue;
            root.showAttention(next);
            return;
        }
        root.attentionKind = "";
        root.attentionTitle = "";
        root.attentionDetail = "";
        root.attentionValue = -1;
        root.attentionMuted = false;
        root.attentionOutputId = "";
        root.attentionExpiresAt = "";
        root.reconcileActivity();
    }

    function selectedAudioOutput() {
        var rows = root.audioData.items || [];
        var preferred = root.audioData.default_output_id;
        for (var i = 0; i < rows.length; ++i)
            if (rows[i].direction === "output" && rows[i].id === preferred) return rows[i];
        for (var j = 0; j < rows.length; ++j)
            if (rows[j].direction === "output") return rows[j];
        return null;
    }

    function selectedAudioInput() {
        var rows = root.audioData.items || [];
        var preferred = root.audioData.default_input_id;
        for (var i = 0; i < rows.length; ++i)
            if (rows[i].direction === "input" && rows[i].id === preferred) return rows[i];
        for (var j = 0; j < rows.length; ++j)
            if (rows[j].direction === "input") return rows[j];
        return null;
    }

    function observeVolume() {
        var output = root.selectedAudioOutput();
        if (output) {
            var outputValue = output.volume === null ? NaN : Number(output.volume);
            var outputMuted = output.muted === true ? 1 : output.muted === false ? 0 : -1;
            var outputVolumeChanged = isFinite(outputValue) && outputValue >= 0
                && root.observedVolume >= 0
                && Math.abs(outputValue - root.observedVolume) >= 0.005;
            var outputMuteChanged = outputMuted >= 0 && root.observedOutputMuted >= 0
                && outputMuted !== root.observedOutputMuted;
            if (outputVolumeChanged || outputMuteChanged) {
                var outputPercent = isFinite(outputValue) && outputValue >= 0
                    ? Math.round(outputValue * 100) + "%" : "—";
                var outputDetail = outputMuted === 1
                    ? "Muted" + (outputPercent === "—" ? "" : " · " + outputPercent)
                    : outputPercent;
                root.enqueueAttention("volume", "Volume", outputDetail,
                    outputMuted === 1 || (isFinite(outputValue) && outputValue <= 0)
                        ? "\uf026" : "\uf028",
                    isFinite(outputValue) ? outputValue * 100 : -1,
                    outputMuted === 1);
            }
            if (isFinite(outputValue) && outputValue >= 0) root.observedVolume = outputValue;
            if (outputMuted >= 0) root.observedOutputMuted = outputMuted;
        }

        var input = root.selectedAudioInput();
        if (!input) return;
        var inputValue = input.volume === null ? NaN : Number(input.volume);
        var inputMuted = input.muted === true ? 1 : input.muted === false ? 0 : -1;
        var inputVolumeChanged = isFinite(inputValue) && inputValue >= 0
            && root.observedInputVolume >= 0
            && Math.abs(inputValue - root.observedInputVolume) >= 0.005;
        var inputMuteChanged = inputMuted >= 0 && root.observedInputMuted >= 0
            && inputMuted !== root.observedInputMuted;
        if (inputVolumeChanged || inputMuteChanged) {
            var inputPercent = isFinite(inputValue) && inputValue >= 0
                ? Math.round(inputValue * 100) + "%" : "—";
            var inputDetail = inputMuted === 1
                ? "Muted" + (inputPercent === "—" ? "" : " · " + inputPercent)
                : inputPercent;
            root.enqueueAttention("microphone", "Microphone", inputDetail,
                inputMuted === 1 ? "\uf131" : "\uf130",
                isFinite(inputValue) ? inputValue * 100 : -1,
                inputMuted === 1);
        }
        if (isFinite(inputValue) && inputValue >= 0) root.observedInputVolume = inputValue;
        if (inputMuted >= 0) root.observedInputMuted = inputMuted;
    }

    function observeBattery() {
        if (!root.battery || root.battery.status !== "ready") return;
        var percent = Number(root.battery.percent);
        var state = String(root.battery.state || "");
        if (root.observedBatteryState.length && state !== root.observedBatteryState)
            root.enqueueAttention("battery", state, Math.round(percent) + "%", "\uf240", -1);
        if (isFinite(percent) && percent > 0 && percent <= 10
                && (root.observedBatteryPercent < 0 || root.observedBatteryPercent > 10))
            root.enqueueAttention("battery-low", "Battery low", Math.round(percent) + "%",
                "\uf244", -1);
        root.observedBatteryPercent = percent;
        root.observedBatteryState = state;
    }

    function dispatchControl(action, args, section) {
        if (root.preview) {
            root.message = "Preview: changes are disabled.";
            return;
        }
        root.controlSection = section || root.controlSection;
        Qt.callLater(function() {
            if (!controlsBackend.dispatch(action, args))
                root.message = controlsBackend.message;
        });
    }

    function launch(args) {
        if (root.preview || launchAction.running) {
            if (root.preview) root.message = "Preview: launch actions are disabled.";
            return;
        }
        launchAction.command = [root.home + "/.local/bin/blend_bin/workstation-project",
            "dispatch"].concat(args);
        launchAction.running = true;
    }

    function desktopIntent(intent) {
        if (root.preview) {
            root.message = "Preview: actions are disabled.";
            return;
        }
        var commands = {
            terminal: "session-terminal",
            lock: "session-lock"
        };
        if (intent === "launcher") {
            root.openLauncher(root.activeOutputId);
            return;
        }
        if (!commands[intent]) return;
        var argv = [root.home + "/.local/bin/blend_bin/" + commands[intent]];
        if (intent === "terminal") {
            argv = ["systemd-run", "--user", "--collect", "--quiet",
                "--service-type=exec", "--property=PartOf=graphical-session.target",
                "--property=Requisite=graphical-session.target",
                "--property=After=graphical-session.target", "--"].concat(argv);
        }
        Quickshell.execDetached(argv);
    }

    function handleIntent(action, args) {
        if (action === "media.toggle") {
            var player = null;
            for (var i = 0; i < root.mediaItems.length; ++i)
                if (root.mediaItems[i].id === args.id) player = root.mediaItems[i];
            if (!player) return;
            dispatchControl(player.state === "playing" ? "media.pause" : "media.play",
                {id: args.id}, "media");
        } else if (action === "media.seek") {
            root.message = "Seeking is unavailable through the current media helper.";
        } else if (action === "media.previous" || action === "media.next") {
            dispatchControl(action, {id: args.id}, "media");
        } else if (action === "audio.volume") {
            dispatchControl("audio.set_volume",
                {id: args.id, volume: Number(args.volume)}, "audio");
        } else if (action === "audio.mute") {
            dispatchControl("audio.set_mute",
                {id: args.id, muted: args.muted === true}, "audio");
        } else if (action === "attention.value") {
            if (root.attentionKind === "volume") {
                var output = root.selectedAudioOutput();
                if (output) dispatchControl("audio.set_volume", {
                    id: output.id,
                    volume: Math.max(0, Math.min(1, args.value / 100))
                }, "audio");
            } else if (root.attentionKind === "microphone") {
                var input = root.selectedAudioInput();
                if (input) dispatchControl("audio.set_volume", {
                    id: input.id,
                    volume: Math.max(0, Math.min(1, args.value / 100))
                }, "audio");
            } else {
                root.message = "Brightness is controlled by the existing brightness keys.";
            }
        } else if (action.indexOf("notifications.") === 0) {
            dispatchControl(action, args, "notifications");
        } else if (action === "task.add") {
            tasksStore.add(args.title);
        } else if (action === "task.complete") {
            tasksStore.setDone(args.id, args.done === true);
        } else if (action === "timer.start") {
            root.timerTotal = Math.max(1, Math.floor(Number(args.seconds) || 0));
            root.timerRemaining = root.timerTotal;
            root.timerName = String(args.name || "Focus");
            root.timerRunning = true;
            root.debugMode = false;
            root.reconcileActivity();
        } else if (action === "timer.toggle") {
            if (!root.timerRemaining) {
                root.timerTotal = 1500;
                root.timerRemaining = 1500;
                root.timerName = "Pomodoro";
            }
            root.timerRunning = !root.timerRunning;
            root.reconcileActivity();
        } else if (action === "timer.stop") {
            root.timerRunning = false;
            root.timerRemaining = 0;
            root.timerTotal = 0;
            root.reconcileActivity();
        } else if (action === "recorder.start") {
            if (!root.preview)
                Quickshell.execDetached([root.home + "/.local/bin/blend_bin/workstation-record",
                    "start"]);
        } else if (action === "recorder.stop") {
            var recording = root.recordingSnapshot.data;
            if (recording && recording.run_id)
                dispatchControl("recording.stop", {run_id: recording.run_id}, "recording");
        } else if (action === "workspace.activate") {
            if (desktopBackend) desktopBackend.activateWorkspace(args.id);
        } else if (action === "project.select") {
            root.selectedProject = String(args.id || "");
            backend.selectedId = root.selectedProject;
        } else if (action === "project.open") {
            if (root.selectedProject.length)
                root.launch(["open", root.selectedProject, args.mode || "terminal"]);
        } else if (action.indexOf("power.") === 0) {
            root.handlePower(action.slice(6), args);
        }
    }

    function handlePower(id, args) {
        if (["logout", "reboot", "shutdown"].indexOf(id) >= 0
                && !(args && args.confirmed === true)) {
            root.powerConfirmation = true;
            root.powerConfirmationId = id;
            return;
        }
        dispatchControl("power." + id,
            ["logout", "reboot", "shutdown"].indexOf(id) >= 0
                ? {confirmed: true} : {}, "power");
        root.powerConfirmation = false;
        root.powerConfirmationId = "";
    }

    function cardForSection(section) {
        var map = {
            audio: "volume", media: "media", recording: "recorder",
            power: "power", outputs: "performance", settings: "dashboard"
        };
        var widget = map[section] || "dashboard";
        if (widget === "dashboard") openDashboard(root.activeOutputId);
        else openCard(widget, root.activeOutputId);
    }

    function debug(name) {
        hoverOpen.stop();
        collapseGrace.stop();
        if (name === "compact") {
            root.debugMode = false;
            root.surfaceState = "compact";
        } else if (name === "activity-media") {
            root.debugMode = true;
            root.debugPrimary = "media";
            root.debugSecondary = "";
            root.surfaceState = "activity";
        } else if (name === "activity-timer") {
            root.debugMode = true;
            root.debugPrimary = "timer";
            root.debugSecondary = "";
            root.surfaceState = "activity";
        } else if (name === "attention") {
            root.debugMode = false;
            root.enqueueAttention("debug", "Island attention", "Debug event", "\uf129", -1);
        } else if (name === "split") {
            root.debugMode = true;
            root.debugPrimary = "media";
            root.debugSecondary = "timer";
            root.surfaceState = "split";
        } else if (name === "expanded") {
            root.debugMode = false;
            root.activeOutputId = root.activeOutputId || root.defaultOutputId();
            root.expandedOutputId = root.activeOutputId;
            root.cardWidget = "calendar";
            root.surfaceState = "expanded";
        } else if (name === "dashboard") {
            root.openDashboard(root.activeOutputId);
        } else {
            root.message = "Unknown Island debug state.";
        }
    }

    function status() {
        return JSON.stringify({
            schema_version: 1,
            state: root.surfaceState,
            layout: root.config.layout,
            card: root.cardWidget,
            dashboard_tab: root.dashboardTab,
            active_output: root.activeOutputId,
            expanded_output: root.expandedOutputId,
            theme_id: root.theme ? root.theme.theme_id : null,
            theme_mode: root.darkTheme ? "dark" : "light",
            config_ready: root.configReady,
            widgets: root.config.enabled_widgets,
            message: root.message
        });
    }

    onActivitySignatureChanged: Qt.callLater(function() {
        root.reconcileActivity();
    })
    onAudioDataChanged: root.observeVolume()
    onBatteryChanged: root.observeBattery()
    onMediaItemsChanged: root.clampDashboardTab()
    onPerformanceChanged: root.clampDashboardTab()
    onWorkspacesChanged: root.clampDashboardTab()

    Component.onCompleted: {
        root.activeOutputId = root.defaultOutputId();
        root.selectedProject = backend.selectedId || "";
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.surfaceState === "expanded" || root.surfaceState === "dashboard"
            || root.surfaceState === "launcher"
        onActivated: root.collapse()
    }

    Variants {
        model: root.theme ? Quickshell.screens : []
        delegate: PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData
            anchors {
                top: true
                left: true
                right: true
            }
            margins.top: Number(root.config.top_margin) || 8
            implicitHeight: islandBar.implicitHeight
            exclusiveZone: 0
            aboveWindows: true
            focusable: root.expandedOutputId === modelData.name
                && (root.surfaceState === "expanded" || root.surfaceState === "dashboard"
                    || root.surfaceState === "launcher")
            visible: !!root.theme
            color: "transparent"

            IslandBar {
                id: islandBar
                anchors.fill: parent
                palette: islandPalette
                config: root.config
                outputId: modelData.name
                surfaceState: root.surfaceState
                cardWidget: root.cardWidget
                expandedOutputId: root.expandedOutputId
                launcherAdapter: launcherBackend
                dashboardTab: root.dashboardTab
                workspaces: root.workspaces
                trayItems: root.desktopBackend ? root.desktopBackend.traySnapshot.items : []
                trayRevision: root.desktopBackend ? root.desktopBackend.traySnapshot.revision : 0
                mediaItems: root.mediaItems
                audioData: root.audioData
                performance: root.performance
                battery: root.battery
                systemInfo: root.systemInfo
                recording: root.recordingSnapshot
                power: root.powerSnapshot
                notifications: root.notificationsSnapshot
                tasks: root.tasks
                projects: root.projects
                runs: root.runs
                selectedProjectId: root.selectedProject
                powerConfirmation: root.powerConfirmationId
                nowToken: root.nowToken
                phase: root.phase
                timerRemaining: root.timerRemaining
                timerTotal: root.timerTotal
                timerRunning: root.timerRunning
                timerName: root.timerName
                primaryIsTimer: root.primaryActivity === "timer"
                secondaryIsTimer: root.secondaryActivity === "timer"
                recordingActive: root.recorderRunning
                reduceMotion: root.reduceMotion
                speed: Number(root.config.animation_speed) || 1
                onWidgetRequested: widget => {
                    root.activeOutputId = modelData.name;
                    root.openCard(widget, modelData.name);
                }
                onDashboardRequested: {
                    root.activeOutputId = modelData.name;
                    root.openDashboard(modelData.name);
                }
                onCollapseRequested: root.collapse()
                onActionRequested: action => root.desktopIntent(action)
                onLauncherActivateRequested: (item, action) =>
                    launcherBackend.activate(item, action)
                onWorkspaceRequested: id => root.desktopBackend
                    && root.desktopBackend.activateWorkspace(id)
                onTrayRequested: (id, slot, revision, action, x, y, delta, horizontal) => {
                    if (root.desktopBackend)
                        root.desktopBackend.trayAction(id, slot, revision, action,
                            barWindow, x, y, delta, horizontal);
                }
                onHoverIntent: (key, hovered) => root.handleHover(
                    modelData.name, key, hovered)
                onOutputActivated: root.activeOutputId = modelData.name
                onVolumeWheel: delta => {
                    var output = root.selectedAudioOutput();
                    if (output && output.volume !== null)
                        root.dispatchControl("audio.set_volume", {
                            id: output.id,
                            volume: Math.max(0, Math.min(1,
                                output.volume + (delta > 0 ? 0.02 : -0.02)))
                        }, "audio");
                }
                onTabRequested: index => {
                    root.dashboardTab = Math.max(0, Math.min(
                        root.dashboardTabCount() - 1, index));
                }
                onIntent: (action, args) => root.handleIntent(action, args)
            }

            MouseArea {
                anchors.fill: parent
                z: -10
                visible: root.expandedOutputId === modelData.name
                    && (root.surfaceState === "expanded" || root.surfaceState === "dashboard"
                        || root.surfaceState === "launcher")
                onClicked: root.collapse()
            }
        }
    }

    IpcHandler {
        target: "theme"
        function reload(): void { themeFile.reload(); }
        function current(): string {
            return root.theme ? root.theme.theme_id : "unavailable";
        }
        function release(): string {
            return root.theme ? root.theme.release_id : "unavailable";
        }
    }

    IpcHandler {
        target: "island"
        function show(): void { root.openDashboard(root.activeOutputId); }
        function hide(): void { root.collapse(); }
        function toggle(): void {
            if (root.surfaceState === "compact" || root.surfaceState === "activity"
                    || root.surfaceState === "split")
                root.openDashboard(root.activeOutputId);
            else root.collapse();
        }
        function card(name: string): void { root.openCard(name, root.activeOutputId); }
        function dashboard(): void { root.openDashboard(root.activeOutputId); }
        function launcher(): void { root.openLauncher(root.activeOutputId); }
        function collapse(): void { root.collapse(); }
        function debug(name: string): void { root.debug(name); }
        function layout(name: string): void {
            if (["grouped", "spread", "one"].indexOf(name) >= 0) {
                var value = Object.assign({}, root.config);
                value.layout = name;
                root.config = IslandConfig.normalize(JSON.stringify(value));
            }
        }
        function attention(kind: string, title: string, detail: string): void {
            root.enqueueAttention(kind, title, detail, "\uf129", -1);
        }
        function configReload(): void { configFile.reload(); }
        function status(): string { return root.status(); }
    }

    IpcHandler {
        target: "panel"
        function show(): void { root.openDashboard(root.activeOutputId); }
        function hide(): void { root.collapse(); }
        function toggle(): void {
            if (root.surfaceState === "dashboard") root.collapse();
            else root.openDashboard(root.activeOutputId);
        }
        function close(): void { root.collapse(); }
        function status(): string { return root.status(); }
    }

    IpcHandler {
        target: "controls"
        function show(): void { root.openDashboard(root.activeOutputId); }
        function hide(): void { root.collapse(); }
        function toggle(): void { root.cardForSection("settings"); }
        function section(name: string): bool {
            root.cardForSection(name);
            return true;
        }
        function status(): string { return root.status(); }
    }
}
