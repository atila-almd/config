import QtQuick
import Quickshell

ShellRoot {
    Desktop { id: desktop; observeOutputs: true }
    property var snapshot: desktop.traySnapshot
    Component.onCompleted: Qt.callLater(function() {
        if (snapshot.schema_version !== 1 || snapshot.status !== "ready"
                || typeof snapshot.revision !== "number" || !Array.isArray(snapshot.items)) {
            console.error("Invalid native desktop snapshot");
            Qt.exit(1);
            return;
        }
        if (desktop.outputSnapshot.status !== "unavailable" || desktop.outputSnapshot.data !== null) {
            console.error("Missing compositor fabricated output/focus state");
            Qt.exit(1);
            return;
        }
        desktop.observeOutputs = false;
        if (desktop.outputSnapshot.data !== null) {
            console.error("Hidden outputs retained an observed snapshot");
            Qt.exit(1);
            return;
        }
        console.log("Native desktop snapshot initialized");
        Qt.quit();
    })
}
