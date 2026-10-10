import QtQuick
import QtQuick.Window
import QtTest
import "../../../.config/quickshell/workstation/surfaces"

TestCase {
    name: "BarPointer"
    when: windowShown
    SignalSpy { id: workspace; target: bar; signalName: "workspaceRequested" }
    SignalSpy { id: action; target: bar; signalName: "actionRequested" }
    // A layer-shell bar has no spare window space for an in-window popup.
    Window {
        width: 1300; height: 48; visible: true
        Bar {
            id: bar
            anchors.fill: parent
            outputId: "DP-1"
            trayItems: []
            colors: ({background:"#111111",background_alt:"#181818",surface:"#222222",surface_alt:"#333333",foreground:"#ffffff",foreground_muted:"#cccccc",muted:"#888888",selection:"#334477",accent:"#aaccff",red:"#ff8888"})
            workspaces: [{id:"1",name:"1",output_id:"DP-1",active:false,focused:false,urgent:false}]
        }
    }
    function test_workspace_click_after_hover() {
        var button = findChild(bar, "workspace-1");
        verify(button !== null);
        // Offscreen platforms disable hover by default; the desktop enables it.
        button.hoverEnabled = true;
        waitForRendering(bar);
        var position = button.mapToItem(bar, button.width / 2, button.height / 2);
        mouseMove(bar, position.x, position.y);
        wait(100);
        mouseClick(bar, position.x, position.y);
        compare(workspace.count, 1);
        compare(workspace.signalArguments[0][0], "1");
    }
    function test_tools_click_after_hover() {
        var button = findChild(bar, "barTools");
        verify(button !== null);
        button.hoverEnabled = true;
        waitForRendering(bar);
        var position = button.mapToItem(bar, button.width / 2, button.height / 2);
        mouseMove(bar, position.x, position.y);
        wait(100);
        mouseClick(bar, position.x, position.y);
        compare(action.count, 1);
        compare(action.signalArguments[0][0], "tools");
    }
}
