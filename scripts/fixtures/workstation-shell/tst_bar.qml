import QtQuick
import QtTest
import "../../../.config/quickshell/workstation/surfaces"

TestCase {
    id: test
    name: "BarPresentation"
    when: windowShown
    width: 1400; height: 200
    property var bar
    property var colors: ({background:"#111111",background_alt:"#181818",surface:"#222222",surface_alt:"#333333",foreground:"#ffffff",foreground_muted:"#cccccc",muted:"#888888",selection:"#334477",accent:"#aaccff",red:"#ff8888"})
    Component { id: factory; Bar { width: 1300; height: implicitHeight; colors: test.colors; outputId: "DP-1"; workspaces: []; trayItems: [] } }
    SignalSpy { id: workspace; signalName: "workspaceRequested" }
    SignalSpy { id: action; signalName: "actionRequested" }
    SignalSpy { id: tray; signalName: "trayRequested" }
    function init() {
        bar = createTemporaryObject(factory, test);
        verify(bar !== null);
        workspace.target = bar; workspace.clear();
        action.target = bar; action.clear();
        tray.target = bar; tray.clear();
        waitForRendering(bar);
    }
    function test_outputs_and_keyboard_intent() {
        bar.workspaces = [{id:"-99",name:"work",output_id:"DP-1",active:true,focused:true,urgent:false}, {id:"2",name:"2",output_id:"HDMI-1",active:true,focused:false,urgent:true}];
        var button = findChild(bar, "workspace--99");
        verify(button !== null);
        compare(findChild(bar, "workspace-2"), null);
        button.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(workspace.count, 1);
        compare(workspace.signalArguments[0][0], "-99");
        bar.workspaces = [];
        compare(findChild(bar, "workspace--99"), null);
    }
    function test_tray_identity_and_intents() {
        bar.trayRevision = 7;
        bar.trayItems = [{id:"duplicate",slot:1,title:"Application",tooltip:"",icon:"",only_menu:true,has_menu:true}];
        var button = findChild(bar, "tray-1");
        verify(button !== null);
        button.clicked();
        compare(tray.count, 1);
        compare(Array.prototype.slice.call(tray.signalArguments[0], 0, 4), ["duplicate",1,7,"menu"]);
    }
    function test_scaling_and_action() {
        bar.width = 650; bar.textScale = 1.5;
        verify(bar.implicitHeight >= 68);
        verify(!findChild(bar, "barTerminal").visible);
        findChild(bar, "barProjects").clicked();
        compare(action.signalArguments[0][0], "projects");
        findChild(bar, "barTools").clicked();
        compare(action.signalArguments[1][0], "tools");
    }
}
