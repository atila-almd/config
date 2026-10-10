import QtQuick
import QtTest
import "../../../services/desktop/identity"

TestCase {
    id: test
    name: "GreeterPresentation"
    when: windowShown
    width: 1280
    height: 800
    property var view
    property var colors: ({background:"#1e1e2e",background_alt:"#181825",surface:"#313244",surface_alt:"#45475a",foreground:"#cdd6f4",foreground_muted:"#a6adc8",muted:"#6c7086",selection:"#45475a",accent:"#89b4fa",red:"#f38ba8",orange:"#fab387",yellow:"#f9e2af",green:"#a6e3a1",cyan:"#94e2d5",blue:"#89b4fa",magenta:"#cba6f7"})
    Component { id: factory; GreeterView { width: 1200; height: 720; colors: test.colors } }
    SignalSpy { id: accountSubmitted; signalName: "accountSubmitted" }
    SignalSpy { id: submitted; signalName: "submitted" }

    function init() {
        view = createTemporaryObject(factory, test);
        verify(view !== null);
        accountSubmitted.target = view; accountSubmitted.clear();
        submitted.target = view; submitted.clear();
        waitForRendering(view);
    }

    function test_account_keyboard_submission() {
        var account = findChild(view, "authAccount");
        verify(account !== null);
        verify(account.enabled);
        account.text = "test-user";
        account.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(accountSubmitted.count, 1);
        compare(accountSubmitted.signalArguments[0][0], "test-user");
    }

    function test_response_and_scale() {
        view.accountEditable = false;
        view.account = "test-user";
        view.responseRequired = true;
        view.textScale = 2;
        var response = findChild(view, "authResponse");
        response.text = "fixture-only";
        response.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(submitted.count, 1);
        compare(submitted.signalArguments[0][0], "fixture-only");
        compare(response.text, "");
        verify(response.width > 0);
    }

    function test_error_and_retry_are_visible() {
        view.message = "Authentication failed. Try again.";
        view.messageIsError = true;
        view.retryAllowed = true;
        compare(findChild(view, "authMessage").text, view.message);
        verify(findChild(view, "authRetry") !== null);
        verify(view.retryAllowed);
    }
}
