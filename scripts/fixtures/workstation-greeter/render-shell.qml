pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Native offscreen render fixture only. It does not connect to greetd or
// launch a compositor/session.
ShellRoot {
    id: root
    readonly property int step: Number(Quickshell.env("WORKSTATION_GREETER_RENDER_CASE") || "0")
    readonly property string report: Quickshell.env("WORKSTATION_GREETER_RENDER_REPORT")
    readonly property var names: ["greeter-dark-account", "greeter-dark-error", "greeter-light-200", "greeter-unavailable"]
    property var colors: null
    readonly property var lightColors: Object.assign({}, root.colors || {}, {
        background: "#ffffff", background_alt: "#eeeeee", surface: "#dddddd",
        surface_alt: "#cccccc", foreground: "#111111", foreground_muted: "#555555",
        selection: "#aabbff", muted: "#777777", accent: "#2458a0", red: "#b00020"
    })
    readonly property var viewColors: root.step === 2 ? root.lightColors : root.colors

    FileView {
        path: Quickshell.env("WORKSTATION_GREETER_THEME_FIXTURE")
        printErrors: false
        onLoaded: {
            root.colors = JSON.parse(text()).colors;
            settle.start();
        }
    }

    FloatingWindow {
        id: window
        visible: !!root.viewColors
        implicitWidth: root.step === 2 ? 1920 : 1280
        implicitHeight: root.step === 2 ? 1080 : 800
        color: root.viewColors ? root.viewColors.background : "black"
        Item {
            id: surface
            anchors.fill: parent
            GreeterView {
                anchors.fill: parent
                colors: root.viewColors
                textScale: root.step === 2 ? 2 : root.step === 3 ? 1.5 : 1
                heading: root.step === 0 ? "Welcome back" : "Enter your password"
                brandText: "WORKSTATION"
                identityMarkSource: root.step === 2
                    ? Quickshell.env("WORKSTATION_IDENTITY_ROOT") + "/mark-light.svg"
                    : Quickshell.env("WORKSTATION_IDENTITY_ROOT") + "/mark-dark.svg"
                account: root.step === 0 || root.step === 3 ? "" : "test-user"
                accountEditable: root.step === 0 || root.step === 3
                prompt: "Password"
                message: root.step === 1 ? "Authentication failed. Try again."
                    : root.step === 3 ? "Login service unavailable. Use a TTY for recovery." : ""
                messageIsError: root.step === 1 || root.step === 3
                responseRequired: root.step === 1 || root.step === 2
                busy: root.step === 3
                ready: root.step !== 3
                capsLock: root.step !== 0
                keyboardLayout: "Portuguese (Brazil)"
                retryAllowed: root.step === 1 || root.step === 2
            }
        }
    }

    Timer {
        id: settle
        interval: 250
        onTriggered: {
            surface.grabToImage(function(result) {
                if (!result.saveToFile(root.report + "/" + root.names[root.step] + ".png")) {
                    console.error("Greeter fixture image write failed");
                    Qt.quit();
                    return;
                }
                Qt.quit();
            });
        }
    }
}
