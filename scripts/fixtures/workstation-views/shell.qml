pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "surfaces"
import WorkstationShared 1.0

// Source-render fixture only: no backend, PAM context, layer surface or lock.
ShellRoot {
    id: root
    property var colors: null
    readonly property int step: Number(Quickshell.env("WORKSTATION_VIEW_CASE") || "0")
    readonly property string report: Quickshell.env("WORKSTATION_VIEW_REPORT")
    readonly property var names: ["bar-wide-dark", "bar-narrow-dark", "auth-dark", "auth-light", "bar-default-dark"]
    readonly property bool showingBar: step < 2 || step === 4
    readonly property var light: Object.assign({}, colors || {}, {background:"#ffffff",background_alt:"#eeeeee",surface:"#dddddd",surface_alt:"#cccccc",foreground:"#111111",foreground_muted:"#555555",selection:"#aabbff",muted:"#777777",accent:"#2458a0",red:"#b00020"})
    FileView {
        path: Quickshell.env("WORKSTATION_THEME_FIXTURE")
        onLoaded: { root.colors = JSON.parse(text()).colors; settle.start(); }
    }
    FloatingWindow {
        id: window
        visible: !!root.colors
        implicitWidth: root.step === 4 ? 1920 : root.step === 0 ? 1280 : root.step === 1 ? 650 : 640
        implicitHeight: root.step === 4 ? (renderer.item ? renderer.item.implicitHeight : 48) : root.step < 2 ? 80 : 700
        color: root.step === 3 ? root.light.background : root.colors ? root.colors.background : "black"
        Item {
            id: surface
            anchors.fill: parent
            Loader {
                id: renderer
                anchors.fill: parent
                active: !!root.colors
                sourceComponent: root.showingBar ? bar : authentication
            }
        }
    }
    Component {
        id: bar
        Bar {
            colors: root.colors
            textScale: root.step === 1 ? 1.5 : 1
            outputId: "fixture-output"
            clockText: "14:35"
            dateText: "Friday, 11 September 2026"
            workspaces: [{id:"1",name:"1",output_id:"fixture-output",active:true,focused:true,urgent:false},
                {id:"2",name:"2",output_id:"fixture-output",active:false,focused:false,urgent:true},
                {id:"-9",name:"work",output_id:"fixture-output",active:false,focused:false,urgent:false}]
            trayItems: [{id:"fixture",slot:0,title:"Fixture",tooltip:"Fixture application",icon:"",has_menu:true,only_menu:false}]
        }
    }
    Component {
        id: authentication
        AuthForm {
            colors: root.step === 3 ? root.light : root.colors
            account: "Fixture account"
            prompt: "Password"
            capsLock: true
            keyboardLayout: "Portuguese (Brazil)"
            message: root.step === 3 ? "Authentication failed. Try again." : "Enter your password to unlock."
            messageIsError: root.step === 3
            textScale: root.step === 3 ? 1.5 : 1
        }
    }
    Timer {
        id: settle
        interval: 250
        onTriggered: {
            surface.grabToImage(function(result) {
                if (!result.saveToFile(root.report + "/" + root.names[root.step] + ".png")) { console.error("Fixture image write failed"); Qt.quit(); return; }
                Qt.quit();
            });
        }
    }
}
