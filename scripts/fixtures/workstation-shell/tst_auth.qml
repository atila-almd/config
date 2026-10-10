import QtQuick
import QtQuick.Controls
import QtTest
import WorkstationShared 1.0

TestCase {
    id: test
    name: "AuthenticationPresentation"
    when: windowShown
    width: 700; height: 700
    property var form
    property var colors: ({background:"#111111",background_alt:"#181818",surface:"#222222",surface_alt:"#333333",foreground:"#ffffff",foreground_muted:"#cccccc",muted:"#888888",selection:"#334477",accent:"#aaccff",red:"#ff8888"})
    Component { id: factory; AuthForm { width: 650; height: 650; colors: test.colors } }
    SignalSpy { id: submitted; signalName: "submitted" }
    SignalSpy { id: cancelled; signalName: "cancelled" }
    SignalSpy { id: inputState; signalName: "inputStateRequested" }
    function init() {
        form = createTemporaryObject(factory, test);
        verify(form !== null);
        submitted.target = form; submitted.clear();
        cancelled.target = form; cancelled.clear();
        inputState.target = form; inputState.clear();
        waitForRendering(form);
    }
    function test_keyboard_submit_and_clear() {
        var field = findChild(form, "authResponse");
        compare(field.echoMode, TextInput.Password);
        field.text = "fixture-only";
        field.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(submitted.count, 1);
        compare(submitted.signalArguments[0][0], "fixture-only");
        compare(field.text, "");
    }
    function test_reset_all_views_and_cancel() {
        var field = findChild(form, "authResponse");
        field.text = "discard";
        form.resetToken++;
        compare(field.text, "");
        field.text = "discard";
        field.forceActiveFocus();
        keyClick(Qt.Key_Escape);
        compare(cancelled.count, 1);
        compare(field.text, "");
        compare(submitted.count, 0);
    }
    function test_compositor_gate_busy_and_prompt() {
        var field = findChild(form, "authResponse");
        form.ready = false;
        verify(!field.enabled);
        form.submitResponse();
        compare(submitted.count, 0);
        form.ready = true; form.busy = true;
        verify(!findChild(form, "authSubmit").enabled);
        form.busy = false; form.responseVisible = true; form.prompt = "One time code";
        compare(field.echoMode, TextInput.Normal);
        form.message = "Authentication failed"; form.messageIsError = true;
        compare(findChild(form, "authMessage").color, colors.red);
        form.textScale = 1.5;
        form.width = 420;
        waitForRendering(form);
        verify(field.width > 0 && field.width < form.width);
    }
    function test_authoritative_keyboard_state() {
        var value = Contract.keyboardState(JSON.stringify({keyboards:[{main:true,capsLock:true,active_keymap:"Portuguese (Brazil)"}]}));
        compare(value.caps_lock, true);
        compare(value.layout, "Portuguese (Brazil)");
        [[], [{main:true,capsLock:"false",active_keymap:"US"}], [{main:true,capsLock:false,active_keymap:"US"},{main:true,capsLock:true,active_keymap:"BR"}]].forEach(function(rows) {
            var failed = false;
            try { Contract.keyboardState(JSON.stringify({keyboards:rows})); } catch (error) { failed = true; }
            verify(failed);
        });
    }
    function test_modifier_refresh_data() {
        return [
            {tag: "response", control: "authResponse", responseRequired: true},
            {tag: "submit", control: "authSubmit", responseRequired: true},
            {tag: "clear-after-cancel", control: "authCancel", responseRequired: false},
            {tag: "retry-after-failure", control: "authRetry", responseRequired: false}
        ];
    }
    function test_modifier_refresh(row) {
        form.responseRequired = row.responseRequired;
        form.retryAllowed = !row.responseRequired;
        var control = findChild(form, row.control);
        control.forceActiveFocus();
        verify(control.activeFocus);
        inputState.clear();
        keyClick(Qt.Key_CapsLock);
        compare(inputState.count, 1);
        inputState.clear();
        keyClick(Qt.Key_A);
        compare(inputState.count, 0);
    }
}
