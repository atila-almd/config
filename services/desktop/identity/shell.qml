pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Greetd
import Quickshell.Wayland
import WorkstationShared 1.0
import "GreeterContract.js" as GreeterContract

// Pre-login only. This configuration never imports the desktop Hyprland
// configuration, starts a user service, or reads private theme state.
ShellRoot {
    id: root
    Component.onCompleted: Quickshell.watchFiles = false

    readonly property string identityRoot: Quickshell.env("WORKSTATION_IDENTITY_ROOT")
        || "/etc/blendos-workstation/identity"
    readonly property string themePath: Quickshell.env("WORKSTATION_GREETER_THEME_FIXTURE")
        || identityRoot + "/public-theme.json"
    readonly property real textScale: root.readScale()
    readonly property bool loginAvailable: Greetd.available === true
    readonly property var emergencyTheme: ({
        schema_version: 1,
        release_id: "greeter-emergency",
        theme_id: "greeter-emergency",
        mode: "dark",
        colors: {
            background: "#111111", background_alt: "#181818", surface: "#222222",
            surface_alt: "#333333", foreground: "#ffffff", foreground_muted: "#cccccc",
            muted: "#888888", selection: "#334477", accent: "#aaccff", red: "#ff8888",
            orange: "#ffbb88", yellow: "#ffee99", green: "#aaddaa", cyan: "#99dddd",
            blue: "#aaccff", magenta: "#ddaaff"
        }
    })

    property var theme: emergencyTheme
    property string stage: "account"
    property string username: ""
    property string prompt: "Password"
    property string statusMessage: ""
    property bool statusIsError: false
    property bool responseRequired: false
    property bool responseVisible: false
    property bool busy: false
    property bool failed: false
    property bool launching: false
    property int resetToken: 0

    KeyboardState { id: keyboard }

    function readScale() {
        var value = Number(Quickshell.env("WORKSTATION_GREETER_TEXT_SCALE") || "1");
        return isFinite(value) ? Math.max(1, Math.min(2, value)) : 1;
    }

    function markPath() {
        return root.identityRoot + "/mark-"
            + (root.theme.mode === "light" ? "light" : "dark") + ".svg";
    }

    function resetToAccount(message, error) {
        root.stage = "account";
        root.username = "";
        root.prompt = "Password";
        root.responseRequired = false;
        root.responseVisible = false;
        root.busy = false;
        root.failed = false;
        root.launching = false;
        root.statusMessage = message || "";
        root.statusIsError = error === true;
        root.resetToken++;
    }

    function startSession() {
        if (!root.loginAvailable || root.launching) return;
        root.launching = true;
        root.busy = true;
        root.statusMessage = "Starting Workstation…";
        root.statusIsError = false;
        try {
            Greetd.launch(GreeterContract.handoff());
        } catch (error) {
            root.launching = false;
            root.fail("The Workstation session could not start.");
        }
    }

    function beginAuthentication(accountName) {
        if (!root.loginAvailable || root.busy) return;
        var normalized;
        try { normalized = GreeterContract.username(accountName); }
        catch (error) {
            root.statusMessage = error.message || "Enter a valid account name.";
            root.statusIsError = true;
            root.failed = true;
            root.resetToken++;
            return;
        }
        root.username = normalized;
        root.stage = "auth";
        root.prompt = "Password";
        root.statusMessage = "Starting authentication…";
        root.statusIsError = false;
        root.responseRequired = false;
        root.responseVisible = false;
        root.busy = true;
        root.failed = false;
        root.resetToken++;
        try { Greetd.createSession(normalized); }
        catch (error) { root.fail("The login service could not create a session."); }
    }

    function cancelAuthentication() {
        if (root.stage !== "account") {
            try { Greetd.cancelSession(); } catch (error) {}
        }
        root.resetToAccount("Authentication cancelled.", false);
    }

    function retryAuthentication() {
        if (root.busy) return;
        try { Greetd.cancelSession(); } catch (error) {}
        root.resetToAccount("Enter the account name to try again.", false);
    }

    function fail(message) {
        root.busy = false;
        root.launching = false;
        root.responseRequired = false;
        root.responseVisible = false;
        root.failed = true;
        root.statusMessage = message;
        root.statusIsError = true;
        root.resetToken++;
    }

    FileView {
        id: themeFile
        path: root.themePath
        printErrors: false
        onLoaded: {
            try {
                root.theme = Contract.theme(text());
                root.statusMessage = "";
                root.statusIsError = false;
            } catch (error) {
                root.theme = root.emergencyTheme;
                root.statusMessage = "Public login theme is invalid; using the emergency palette.";
                root.statusIsError = true;
            }
        }
        onLoadFailed: {
            root.theme = root.emergencyTheme;
            root.statusMessage = "Public login theme is unavailable; using the emergency palette.";
            root.statusIsError = true;
        }
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            root.stage = "auth";
            root.busy = false;
            root.failed = error === true;
            root.prompt = String(message || "Password");
            root.statusMessage = error === true ? root.prompt : "";
            root.statusIsError = error === true;
            root.responseRequired = responseRequired === true;
            root.responseVisible = echoResponse === true;
            root.resetToken++;
        }
        function onAuthFailure(message) {
            root.fail(String(message || "Authentication failed. Try again."));
        }
        function onReadyToLaunch() {
            root.startSession();
        }
        function onError() {
            root.fail("The login service reported an error. Try again.");
        }
        function onLaunched() {
            root.busy = true;
            root.statusMessage = "Workstation is starting…";
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: greeterWindow
            required property var modelData
            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            aboveWindows: true
            focusable: true
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            GreeterView {
                anchors.fill: parent
                colors: root.theme.colors
                textScale: root.textScale
                heading: root.stage === "account" ? "Welcome back" : "Enter your password"
                brandText: "WORKSTATION"
                identityMarkSource: root.markPath()
                account: root.username
                accountEditable: root.stage === "account"
                prompt: root.prompt
                message: root.statusMessage || (!root.loginAvailable
                    ? "Login service unavailable. Use a TTY for recovery."
                    : "")
                messageIsError: root.statusIsError || !root.loginAvailable
                responseRequired: root.responseRequired
                responseVisible: root.responseVisible
                busy: root.busy
                ready: root.loginAvailable
                capsLock: keyboard.snapshot.caps_lock === true
                keyboardLayout: keyboard.snapshot.layout || "Unavailable"
                resetToken: root.resetToken
                submitLabel: root.stage === "account" ? "Continue" : "Unlock"
                retryAllowed: root.failed && root.stage === "auth" && !root.busy
                onSubmitted: response => {
                    if (root.stage === "auth" && root.responseRequired && root.loginAvailable) {
                        root.busy = true;
                        root.statusMessage = "";
                        root.statusIsError = false;
                        root.resetToken++;
                        Greetd.respond(response);
                    }
                }
                onAccountSubmitted: accountName => root.beginAuthentication(accountName)
                onCancelled: root.cancelAuthentication()
                onRetryRequested: root.retryAuthentication()
                onInputStateRequested: keyboard.refresh()
            }
        }
    }
}
