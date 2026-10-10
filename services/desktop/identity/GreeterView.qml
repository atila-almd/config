import QtQuick
import WorkstationShared 1.0

// Pure presentation. Greetd, keyboard observations and launch policy remain
// in shell.qml; the locker uses the same AuthForm with a separate controller.
Item {
    id: root
    required property var colors
    property real textScale: 1
    property string heading: "Welcome back"
    property string brandText: "WORKSTATION"
    property string identityMarkSource: ""
    property string account: ""
    property bool accountEditable: true
    property string accountPlaceholder: "Account name"
    property string prompt: "Password"
    property string message: ""
    property bool messageIsError: false
    property bool responseRequired: false
    property bool responseVisible: false
    property bool busy: false
    property bool ready: true
    property bool capsLock: false
    property string keyboardLayout: ""
    property int resetToken: 0
    property string submitLabel: "Continue"
    property bool retryAllowed: false
    signal submitted(string response)
    signal accountSubmitted(string accountName)
    signal cancelled()
    signal retryRequested()
    signal inputStateRequested()

    Rectangle {
        anchors.fill: parent
        color: root.colors.background
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(root.width - 48 * root.textScale, 560 * root.textScale)
        height: Math.min(root.height - 64 * root.textScale, 720 * root.textScale)
        radius: 18 * root.textScale
        color: root.colors.surface
        border.color: root.colors.surface_alt
        border.width: 1

        AuthForm {
            anchors.fill: parent
            anchors.margins: 1
            colors: root.colors
            paneBackground: "transparent"
            textScale: root.textScale
            heading: root.heading
            brandText: root.brandText
            identityMarkSource: root.identityMarkSource
            account: root.account
            accountEditable: root.accountEditable
            accountPlaceholder: root.accountPlaceholder
            prompt: root.prompt
            message: root.message
            messageIsError: root.messageIsError
            responseRequired: root.responseRequired
            responseVisible: root.responseVisible
            busy: root.busy
            ready: root.ready
            capsLock: root.capsLock
            keyboardLayout: root.keyboardLayout
            resetToken: root.resetToken
            submitLabel: root.submitLabel
            retryAllowed: root.retryAllowed
            onSubmitted: response => root.submitted(response)
            onAccountSubmitted: accountName => root.accountSubmitted(accountName)
            onCancelled: root.cancelled()
            onRetryRequested: root.retryRequested()
            onInputStateRequested: root.inputStateRequested()
        }
    }
}
