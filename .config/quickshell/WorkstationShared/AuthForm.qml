import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Presentation only. The controller owns authentication and clears every view
// on a new prompt, cancellation or result; no password is a public property.
ThemedPane {
    id: root
    property string heading: "Workstation locked"
    property string brandText: ""
    property string identityMarkSource: ""
    property string account: ""
    property bool accountEditable: false
    property string accountPlaceholder: "Account name"
    property string prompt: "Password"
    property string message: ""
    property bool messageIsError: false
    property bool responseRequired: true
    property bool responseVisible: false
    property bool busy: false
    property bool ready: true
    property bool capsLock: false
    property string keyboardLayout: ""
    property int resetToken: 0
    property string submitLabel: "Unlock"
    property bool retryAllowed: false
    signal submitted(string response)
    signal accountSubmitted(string accountName)
    signal cancelled()
    signal retryRequested()
    signal inputStateRequested()
    padding: 24
    focus: true
    onResetTokenChanged: clearResponse()
    onResponseRequiredChanged: focusInput()
    onAccountEditableChanged: focusInput()
    onReadyChanged: if (ready) focusInput()
    onAccountChanged: if (accountEditable && !accountField.activeFocus) accountField.text = account
    Component.onCompleted: focusInput()
    function clearResponse() {
        response.clear();
        if (accountEditable) accountField.text = root.account;
        focusInput();
    }
    function focusResponse() {
        if (ready && responseRequired) response.forceActiveFocus();
    }
    function focusAccount() {
        if (ready && accountEditable && !responseRequired) accountField.forceActiveFocus();
    }
    function focusInput() {
        if (accountEditable && !responseRequired) focusAccount();
        else focusResponse();
    }
    function submitAccount() {
        if (!root.ready || !root.accountEditable || root.responseRequired || root.busy) return;
        var value = accountField.text.trim();
        if (!value.length) {
            root.inputStateRequested();
            accountField.forceActiveFocus();
            return;
        }
        root.accountSubmitted(value);
        value = "";
    }
    function submitResponse() {
        if (!root.ready || !root.responseRequired || root.busy) return;
        var value = response.text;
        response.clear();
        root.submitted(value);
        value = "";
    }
    Keys.onEscapePressed: {
        clearResponse();
        root.cancelled();
    }
    // Modifier releases bubble from every focused control, including buttons
    // shown after a failed or cancelled authentication conversation.
    Keys.onReleased: event => {
        if ([Qt.Key_CapsLock, Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta].indexOf(event.key) >= 0)
            root.inputStateRequested();
        event.accepted = false;
    }
    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            width: Math.min(root.availableWidth, 460 * root.textScale)
            x: Math.max(0, (root.availableWidth - width) / 2)
            spacing: 16
            Label {
                text: root.brandText
                textFormat: Text.PlainText
                font.letterSpacing: 2 * root.textScale
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: text.length > 0
            }
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 72 * root.textScale
                Layout.preferredHeight: 72 * root.textScale
                visible: root.identityMarkSource.length > 0
                Image {
                    anchors.fill: parent
                    source: root.identityMarkSource
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 256
                    sourceSize.height: 256
                    Accessible.name: "Workstation mark"
                }
            }
            Label {
                text: root.heading
                textFormat: Text.PlainText
                font.pixelSize: 26 * root.textScale
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
            Label {
                text: root.account
                textFormat: Text.PlainText
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                visible: !root.accountEditable && text.length > 0
            }
            TextField {
                id: accountField
                objectName: "authAccount"
                Layout.fillWidth: true
                visible: root.accountEditable
                enabled: root.ready && !root.busy && !root.responseRequired
                text: root.account
                selectByMouse: false
                maximumLength: 256
                Accessible.name: "Account name"
                placeholderText: root.accountPlaceholder
                placeholderTextColor: root.colors.foreground_muted
                onAccepted: root.submitAccount()
                onActiveFocusChanged: if (activeFocus) root.inputStateRequested()
            }
            Label {
                text: root.prompt
                textFormat: Text.PlainText
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                visible: text.length > 0
            }
            TextField {
                id: response
                objectName: "authResponse"
                Layout.fillWidth: true
                enabled: root.ready && root.responseRequired && !root.busy
                echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
                inputMethodHints: root.responseVisible ? Qt.ImhNoPredictiveText : Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                selectByMouse: false
                maximumLength: 4096
                Accessible.name: root.prompt || "Authentication response"
                placeholderText: root.ready ? root.prompt : "Waiting for screen protection"
                placeholderTextColor: root.colors.foreground_muted
                onAccepted: root.submitResponse()
                onActiveFocusChanged: if (activeFocus) root.inputStateRequested()
            }
            Label {
                objectName: "authInputStatus"
                text: (root.capsLock ? "Caps Lock is on. " : "") + (root.keyboardLayout ? "Keyboard: " + root.keyboardLayout : "")
                textFormat: Text.PlainText
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                visible: text.length > 0
            }
            Label {
                objectName: "authMessage"
                text: root.message
                textFormat: Text.PlainText
                color: root.messageIsError ? root.colors.red : root.colors.foreground_muted
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                visible: text.length > 0
                Accessible.name: text
            }
            RowLayout {
                Layout.fillWidth: true
                Button {
                    objectName: "authCancel"
                    text: "Clear"
                    Accessible.name: "Clear response and cancel authentication"
                    onClicked: { root.clearResponse(); root.cancelled(); }
                }
                Button {
                    objectName: "authRetry"
                    text: "Try again"
                    visible: root.retryAllowed
                    onClicked: root.retryRequested()
                }
                Button {
                    objectName: "authSubmit"
                    Layout.fillWidth: true
                    text: root.busy ? (root.responseRequired ? "Authenticating…" : "Starting…") : root.submitLabel
                    enabled: root.ready && !root.busy && (root.accountEditable && !root.responseRequired ? accountField.text.trim().length > 0 : root.responseRequired)
                    onClicked: root.accountEditable && !root.responseRequired ? root.submitAccount() : root.submitResponse()
                }
            }
        }
    }
}
