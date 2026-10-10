import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property var command: [Quickshell.env("HOME") + "/.local/libexec/blendos-workstation/workstation-lock-guard", "prepare-unlock"]
    property bool pending: false
    signal finished(bool accepted)
    function request() {
        if (root.pending) return;
        root.pending = true;
        worker.running = true;
    }
    function complete(accepted) {
        if (!root.pending) return;
        root.pending = false;
        root.finished(accepted);
    }
    property Process worker: Process {
        id: worker
        command: root.command
        stdout: SplitParser { onRead: {} }
        stderr: SplitParser { onRead: {} }
        // FailedToStart emits runningChanged but no exited signal in QS 0.3.1.
        // Normal completion emits exited synchronously before this deferred check.
        onRunningChanged: if (!running && root.pending) Qt.callLater(function() {
            if (!worker.running && root.pending) root.complete(false);
        })
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => root.complete(exitCode === 0 && exitStatus === 0)
        // qmllint enable signal-handler-parameters
    }
}
