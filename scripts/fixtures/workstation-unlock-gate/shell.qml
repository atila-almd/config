pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// This fixture is copied beside the real native gate component. No PAM, lock,
// logind or credential is involved; only native QProcess completion behavior.
ShellRoot {
    id: root
    property int index: 0
    property int results: 0
    readonly property var commands: [["/usr/bin/true"], ["/usr/bin/false"], ["/nonexistent/workstation-guard-fixture"], ["/usr/bin/true"]]
    readonly property var expected: [true, false, false, true]
    UnlockGate {
        id: gate
        command: root.commands[root.index]
        onFinished: accepted => {
            root.results++;
            if (pending || accepted !== root.expected[root.index] || root.results !== root.index + 1) {
                console.error("Unlock gate completion contract failed"); Qt.exit(1); return;
            }
            root.index++;
            if (root.index === root.commands.length) { console.log("Unlock gate native success/failure/start-failure/retry passed"); Qt.quit(); }
            else Qt.callLater(gate.request);
        }
    }
    Component.onCompleted: gate.request()
}
