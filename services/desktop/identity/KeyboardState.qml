import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import WorkstationShared 1.0

// Native compositor state, refreshed on compositor events and focused-input
// requests. There is no widget-owned polling timer.
QtObject {
    id: root
    property var snapshot: ({schema_version: 1, status: "unavailable", caps_lock: null, layout: null})
    property bool queued: false
    property bool awaiting: false

    function refresh() {
        if (query.running) { root.queued = true; return; }
        root.awaiting = true;
        query.running = true;
    }

    Component.onCompleted: refresh()

    property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout" || event.name === "configreloaded") root.refresh();
        }
    }

    property Process query: Process {
        id: query
        command: ["/usr/bin/hyprctl", "devices", "-j"]
        stdout: StdioCollector { id: output }
        stderr: SplitParser { onRead: {} }
        onRunningChanged: if (!running && root.awaiting) Qt.callLater(function() {
            if (!query.running && root.awaiting) {
                root.awaiting = false;
                root.queued = false;
                root.snapshot = {schema_version: 1, status: "unavailable", caps_lock: null, layout: null};
            }
        })
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            root.awaiting = false;
            try {
                if (exitCode !== 0 || exitStatus !== 0) throw new Error("Unavailable");
                root.snapshot = Contract.keyboardState(output.text);
            } catch (error) {
                root.snapshot = {schema_version: 1, status: "unavailable", caps_lock: null, layout: null};
            }
            if (root.queued) { root.queued = false; root.refresh(); }
        }
        // qmllint enable signal-handler-parameters
    }
}
