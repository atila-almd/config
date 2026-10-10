pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import WorkstationShared 1.0

ShellRoot {
    id: root
    // Source edits must not replace an in-flight PAM conversation. Palette
    // changes use the explicit theme IPC below and preserve authentication.
    Component.onCompleted: Quickshell.watchFiles = false
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"
    readonly property string identityRoot: Quickshell.env("WORKSTATION_IDENTITY_ROOT")
        || "/usr/share/blendos-workstation/identity"
    // A broken theme must never prevent acquiring the compositor lock.
    property var theme: ({theme_id: "lock-emergency", mode: "dark", colors: {
        background: "#111111", background_alt: "#181818", surface: "#222222", surface_alt: "#333333",
        foreground: "#ffffff", foreground_muted: "#cccccc", muted: "#888888", selection: "#334477", accent: "#aaccff", red: "#ff8888"}})
    property string statusMessage: ""
    property bool failed: false
    readonly property bool unlockPending: prepareUnlock.pending
    property bool authenticatedUnlock: false
    property int resetToken: 0
    KeyboardState { id: keyboard }
    // Acquisition deadline, not polling: a denied/missing protocol must not
    // leave an inert service looking like a usable locker.
    Timer {
        id: acquisitionDeadline
        interval: 10000
        running: true
        onTriggered: if (!lock.secure) {
            console.error("Compositor lock acknowledgement timed out. The lock guard retains sleep protection.");
            Qt.exit(1);
        }
    }
    function beginAuthentication() {
        if (!lock.secure || pam.active || root.unlockPending) return;
        root.failed = false;
        root.statusMessage = "";
        root.resetToken++;
        if (!pam.start()) { root.failed = true; root.statusMessage = "Authentication is unavailable. Try again."; }
    }
    function cancelAuthentication() {
        if (root.unlockPending) return;
        pam.abort();
        root.resetToken++;
        root.failed = true;
        root.statusMessage = "Authentication cancelled. The workstation remains locked.";
    }
    FileView {
        id: themeFile
        path: root.stateHome + "/blendos-workstation/theme/current/workstation-shell.json"
        printErrors: false
        onLoaded: {
            try { root.theme = Contract.theme(text()); }
            catch (error) { root.statusMessage = "Theme unavailable. Authentication remains available."; }
        }
        onLoadFailed: root.statusMessage = "Theme unavailable. Authentication remains available."
    }
    IpcHandler {
        target: "theme"
        function reload(): void { themeFile.reload(); }
        function current(): string { return root.theme.theme_id; }
        function release(): string { return root.theme.release_id || "unavailable"; }
    }
    IpcHandler {
        target: "lock"
        function status(): string {
            return JSON.stringify({schema_version: 1, requested: lock.locked, secure: lock.secure, authenticating: pam.active});
        }
    }
    PamContext {
        id: pam
        config: "workstation-lock"
        onPamMessage: root.resetToken++
        onCompleted: result => {
            root.resetToken++;
            if (result === PamResult.Success && lock.secure) {
                prepareUnlock.request();
            } else {
                root.failed = true;
                root.statusMessage = result === PamResult.Error ? "Authentication is unavailable. Try again." : "Authentication failed. Try again.";
            }
        }
    }
    UnlockGate {
        id: prepareUnlock
        onFinished: accepted => {
            if (accepted && lock.secure) {
                root.authenticatedUnlock = true;
                lock.locked = false;
                Qt.quit();
            } else {
                root.failed = true;
                root.statusMessage = "Sleep protection is unavailable. The workstation remains locked. Try again.";
            }
        }
    }
    WlSessionLock {
        id: lock
        locked: true
        onLockedChanged: if (!locked && !root.authenticatedUnlock) {
            console.error("Compositor refused or ended lock acquisition. End this graphical login from an authenticated TTY to recover an abandoned lock.");
            Qt.exit(1);
        }
        onSecureChanged: if (secure) { acquisitionDeadline.stop(); root.beginAuthentication(); }
        WlSessionLockSurface {
            color: root.theme.colors.background
            AuthForm {
                anchors.fill: parent
                colors: root.theme.colors
                brandText: "WORKSTATION"
                identityMarkSource: root.identityRoot + "/mark-"
                    + (root.theme.mode === "light" ? "light" : "dark") + ".svg"
                account: Quickshell.env("USER")
                prompt: pam.responseRequired ? pam.message : ""
                message: root.statusMessage || (!pam.responseRequired ? pam.message : "")
                messageIsError: root.failed || pam.messageIsError
                responseRequired: pam.responseRequired
                responseVisible: pam.responseVisible
                busy: root.unlockPending || (pam.active && !pam.responseRequired)
                ready: lock.secure
                retryAllowed: root.failed && !pam.active
                resetToken: root.resetToken
                capsLock: keyboard.snapshot.caps_lock === true
                keyboardLayout: keyboard.snapshot.layout || "Unavailable"
                onSubmitted: response => { if (lock.secure && pam.responseRequired) { root.resetToken++; pam.respond(response); } }
                onCancelled: root.cancelAuthentication()
                onRetryRequested: root.beginAuthentication()
                onInputStateRequested: keyboard.refresh()
            }
        }
    }
}
