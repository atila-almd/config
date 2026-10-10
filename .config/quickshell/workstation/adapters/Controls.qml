pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import WorkstationShared 1.0

Item {
    id: root
    property bool observing: false
    property bool preview: false
    property string section: "audio"
    property var fixture: ({})
    property var sharedSnapshots: ({})
    property var outputSnapshot: Contract.unavailable("outputs")
    property var helperCommand: [Quickshell.env("HOME") + "/.local/bin/blend_bin/workstation-controls", "dispatch"]
    property string message: ""
    property string exportedSettings: ""
    property string pendingId: ""
    property string pendingAction: ""
    property int sequence: 0
    property var result: null
    property bool invalidResult: false
    readonly property bool busy: pendingId.length > 0
    readonly property Audio audioBackend: audioLoader.item as Audio
    readonly property Media mediaBackend: mediaLoader.item as Media
    readonly property bool nativeLoaded: audioLoader.active || mediaLoader.active
    readonly property var snapshots: {
        var values = {};
        ["network", "appearance", "recording", "power", "notifications"].forEach(function(topic) {
            values[topic] = root.sharedSnapshots[topic] || Contract.unavailable(topic);
        });
        values.audio = audioBackend ? audioBackend.snapshot : Contract.unavailable("audio");
        values.media = mediaBackend ? mediaBackend.snapshot : Contract.unavailable("media");
        values.outputs = observing ? outputSnapshot : Contract.unavailable("outputs");
        return preview ? fixture : values;
    }
    readonly property var settings: snapshots.appearance && snapshots.appearance.status === "ready" ? snapshots.appearance.data.settings : ({schema_version: 1})
    Loader { id: audioLoader; active: root.observing && root.section === "audio" && !root.preview; sourceComponent: Audio { observing: true } }
    Loader { id: mediaLoader; active: root.observing && root.section === "media" && !root.preview; sourceComponent: Media { observing: true } }
    function dispatch(action, args) {
        if (preview) { message = "Preview: changes are disabled."; return false; }
        if (busy) { message = "Wait for the current change to finish."; return false; }
        if (!observing) { message = "Open controls before requesting a change."; return false; }
        try {
            Contract.controlIntent(action, args, snapshots);
            if (action.indexOf("audio.set_") === 0 && (!audioBackend || !audioBackend.available(args.id))) throw new Error("Audio device is no longer available.");
            if (action.indexOf("media.") === 0 && (!mediaBackend || !mediaBackend.available(args.id, action))) throw new Error("The media action is no longer available.");
            if (JSON.stringify(args).length > 4096) throw new Error("Control request is too large.");
        } catch (error) { message = String(error.message); return false; }
        pendingId = "controls-" + (++sequence);
        pendingAction = action;
        result = null;
        invalidResult = false;
        exportedSettings = "";
        message = "Applying…";
        worker.command = helperCommand.concat([JSON.stringify({schema_version: 1, request_id: pendingId, action: action, args: args})]);
        worker.running = true;
        return true;
    }
    function complete(exitCode, exitStatus) {
        if (!busy) return;
        if (invalidResult || !result || exitStatus !== 0 || (result.status !== "error" && exitCode !== 0)) {
            message = "The control command failed or returned an invalid response.";
        } else if (result.status === "error") {
            message = result.error.message;
        } else if (result.status === "cancelled") {
            message = "Cancelled.";
        } else {
            message = "Change requested.";
            if (pendingAction === "settings.export") {
                try { exportedSettings = JSON.stringify(Contract.settings(result.data), null, 2); message = "Control center layout exported below."; }
                catch (error) { message = "The exported settings were invalid."; }
            }
        }
        pendingId = "";
        pendingAction = "";
        worker.command = [];
    }
    // This controller outlives the lazy window. Admitted theme transactions must
    // finish their helper-owned acknowledgement/rollback even after it hides.
    Process {
        id: worker
        stdout: SplitParser {
            onRead: data => {
                if (!root.busy) return;
                try {
                    if (data.length > 65536 || root.result) throw new Error("Invalid result size/count");
                    root.result = Contract.commandResult(data, root.pendingId);
                } catch (error) { root.invalidResult = true; }
            }
        }
        stderr: SplitParser { onRead: {} }
        // FailedToStart has no exited signal in Quickshell 0.3.1.
        onRunningChanged: if (!running && root.busy) Qt.callLater(function() {
            if (!worker.running && root.busy) root.complete(-1, -1);
        })
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => root.complete(exitCode, exitStatus)
        // qmllint enable signal-handler-parameters
    }
}
