import QtQuick
import QtTest
import "../../../.config/quickshell/workstation/components"
import WorkstationShared 1.0

Item {
  width: 1100
  height: 1000
  TestCase {
    id: test
    name: "ProjectAgentPanel"
    width: 1100
    height: 1000
    when: windowShown
    visible: true
    property var dark: ({background: "#111111", background_alt: "#181818", foreground: "#eeeeee",
        surface: "#222222", surface_alt: "#333333", selection: "#334477", muted: "#888888", foreground_muted: "#aaaaaa"})
    property var light: ({background: "#ffffff", background_alt: "#eeeeee", foreground: "#111111",
        surface: "#dddddd", surface_alt: "#cccccc", selection: "#aabbff", muted: "#777777", foreground_muted: "#555555"})
    property var panel
    Component {
        id: factory
        ProjectAgentPanel { width: 1060; height: 950; colors: test.dark; projects: []; runs: []; projectStatus: "ready"; runStatus: "ready" }
    }
    SignalSpy { id: opened; signalName: "openProject" }
    SignalSpy { id: launched; signalName: "launchAgent" }
    SignalSpy { id: closed; signalName: "closeRequested" }
    function init() {
        panel = createTemporaryObject(factory, test);
        verify(panel !== null);
        opened.target = panel; launched.target = panel; closed.target = panel;
        opened.clear(); launched.clear(); closed.clear();
        waitForRendering(panel);
    }
    function test_empty_and_error() {
        compare(findChild(panel, "projectList").count, 0);
        verify(!findChild(panel, "openTerminal").enabled);
        panel.projectStatus = "Data unavailable";
        verify(!findChild(panel, "openTerminal").enabled);
        compare(panel.palette.window, "#111111");
    }
    function test_select_keyboard_and_open() {
        panel.projects = [{id: "one", label: "One", directory_available: true}, {id: "gone", label: "Gone", directory_available: false}];
        var list = findChild(panel, "projectList");
        tryCompare(list, "count", 2);
        list.forceActiveFocus();
        list.currentIndex = 0;
        keyClick(Qt.Key_Down);
        compare(panel.selectedId, "gone");
        verify(!findChild(panel, "openTerminal").enabled);
        keyClick(Qt.Key_Up);
        compare(panel.selectedId, "one");
        var button = findChild(panel, "openTerminal");
        button.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(opened.count, 1);
        compare(opened.signalArguments[0][0], "one");
        compare(opened.signalArguments[0][1], "terminal");
        keyClick(Qt.Key_Escape);
        compare(closed.count, 1);
    }
    function test_literal_argv_and_validation() {
        panel.projects = [{id: "one", label: "One", directory_available: true}];
        panel.selectedId = "one";
        var field = findChild(panel, "agentArguments");
        var button = findChild(panel, "launchAgent");
        field.text = "echo hello";
        mouseClick(button);
        compare(launched.count, 0);
        field.text = '["printf", "$(touch nope)", "a;b", "two words", ""]';
        mouseClick(button);
        compare(launched.count, 1);
        compare(launched.signalArguments[0][1], ["printf", "$(touch nope)", "a;b", "two words", ""]);
        compare(field.text, "");
    }
    function test_many_rows_theme_and_text() {
        var rows = [];
        for (var i = 0; i < 500; ++i) rows.push({id: "p" + i, label: "Workspace " + i, directory_available: true});
        panel.projects = rows;
        panel.textScale = 2;
        panel.colors = light;
        var list = findChild(panel, "projectList");
        tryCompare(list, "count", 500);
        list.positionViewAtEnd();
        waitForRendering(panel);
        compare(panel.palette.window, "#ffffff");
        var button = findChild(panel, "launchAgent");
        var position = button.mapToItem(panel, 0, 0);
        verify(position.y >= 0 && position.y + button.height <= panel.height, "Launch button bottom " + (position.y + button.height) + " exceeds panel height " + panel.height);
        verify(button.width <= panel.width);
    }
    function test_contract_rejection_and_precision() {
        var base = {schema_version: 1, type: "snapshot", topic: "projects", revision: "r", observed_at: "now", status: "ready", data: {items: [], selected_id: null}};
        compare(Contract.snapshot(JSON.stringify(base)).data.items.length, 0);
        base.schema_version = 2;
        var rejected = false;
        try { Contract.snapshot(JSON.stringify(base)); } catch (error) { rejected = true; }
        verify(rejected);
        base.schema_version = 1;
        base.data.items = [{id: "constructor", label: "Constructor", directory_available: true}];
        compare(Contract.snapshot(JSON.stringify(base)).data.items[0].id, "constructor");
        base.data.items[0].directory_available = "yes";
        rejected = false;
        try { Contract.snapshot(JSON.stringify(base)); } catch (error) { rejected = true; }
        verify(rejected);
        compare(Contract.bytes(null), "Unavailable");
        compare(Contract.bytes("0"), "0 B");
        compare(Contract.bytes("1024"), "1.0 KiB");
        var invalid = ['[]', '[""]', '[1]', '["a\\u0000b"]', '{}'];
        invalid.forEach(function(value) {
            var failed = false;
            try { Contract.argv(value); } catch (error) { failed = true; }
            verify(failed);
        });
    }
    function test_narrow_scaled_layout() {
        panel.width = 600;
        panel.textScale = 2;
        waitForRendering(panel);
        var button = findChild(panel, "launchAgent");
        var position = button.mapToItem(panel, 0, 0);
        verify(position.y >= 0 && position.y + button.height <= panel.height);
        verify(button.width <= panel.width);
    }
}
}
