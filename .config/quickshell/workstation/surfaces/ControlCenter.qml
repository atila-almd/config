import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import WorkstationShared 1.0
import "../components"

// Pure presentation; Qt 6.2 fixtures need explicit delegate root references.
// qmllint disable unqualified
ThemedPane {
    id: root
    property var snapshots: ({})
    property string section: "audio"
    property var settings: ({})
    property bool busy: false
    property string message: ""
    property string exportedSettings: ""
    property string confirmation: ""
    readonly property string currentTopic: section === "settings" ? "appearance" : section
    readonly property int gap: settings.density === "compact" ? 8 : 16
    readonly property var sections: ["audio", "media", "network", "outputs", "appearance", "recording", "power", "settings"]
    signal intent(string action, var args)
    signal sectionRequested(string section)
    signal settingsRequested(string action, var args)
    signal closeRequested()
    signal projectsRequested()
    signal utilityRequested()
    textScale: typeof settings.text_scale === "number" ? settings.text_scale : 1
    palette.brightText: colors.foreground
    palette.dark: colors.selection
    padding: gap
    focus: true
    onSectionChanged: confirmation = ""
    Keys.onEscapePressed: {
        if (confirmation) confirmation = "";
        else closeRequested();
    }
    function snapshot(topic) { return snapshots[topic] || {status:"unavailable",data:null,error:null}; }
    function ready(topic) { return snapshot(topic).status === "ready" && snapshot(topic).data !== null; }
    function topicData(topic) { return ready(topic) ? snapshot(topic).data : {}; }
    function items(topic) { return topicData(topic).items || []; }
    function request(action, args) { if (!busy) intent(action, args); }
    function powerAvailable(action) {
        return (topicData("power").actions || []).some(function(row) { return row.id === action && row.available; });
    }
    function revealFocus() {
        var item = root.Window.window ? root.Window.window.activeFocusItem : null;
        var ancestor = item;
        while (ancestor && ancestor !== sectionLoader) ancestor = ancestor.parent;
        if (!item || !ancestor) return;
        var point = item.mapToItem(sectionScroll.contentItem, 0, 0);
        var next = sectionScroll.contentY;
        if (item.height >= sectionScroll.height || point.y < next) next = point.y;
        else if (point.y + item.height > next + sectionScroll.height) next = point.y + item.height - sectionScroll.height;
        sectionScroll.contentY = Math.max(0, Math.min(next, sectionScroll.contentHeight - sectionScroll.height));
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() { root.revealFocus(); }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: root.gap
        Flow {
            Layout.fillWidth: true
            spacing: root.gap
            Label { text: "Workstation controls"; font.bold: true }
            Button { objectName: "controlProjects"; text: "Projects"; onClicked: root.projectsRequested() }
            Button { objectName: "controlUtilities"; text: "Utilities"; onClicked: root.utilityRequested() }
            Button { objectName: "controlClose"; text: "Close"; onClicked: root.closeRequested() }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: root.sections
                delegate: Button {
                    required property string modelData
                    objectName: "section-" + modelData
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    highlighted: root.section === modelData
                    onClicked: root.sectionRequested(modelData)
                }
            }
        }
        Label {
            objectName: "controlMessage"
            Layout.fillWidth: true
            text: root.message || (root.busy ? "Applying…" : "")
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            visible: text.length > 0
        }
        Label {
            objectName: "controlStatus"
            Layout.fillWidth: true
            visible: !root.ready(root.currentTopic)
            text: root.snapshot(root.currentTopic).status === "error" ? "Unable to read these controls. " + ((root.snapshot(root.currentTopic).error || {}).message || "Try again after the service recovers.") : "These controls are unavailable."
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            Flickable {
                id: sectionScroll
                objectName: "controlScroll"
                clip: true
                contentWidth: width
                contentHeight: sectionLoader.height
                boundsBehavior: Flickable.StopAtBounds
                onHeightChanged: Qt.callLater(root.revealFocus)
                Loader {
                    id: sectionLoader
                    objectName: "controlSection"
                    width: sectionScroll.width
                    sourceComponent: root.section === "audio" ? audioSection : root.section === "media" ? mediaSection : root.section === "network" ? networkSection : root.section === "outputs" ? outputSection : root.section === "appearance" ? appearanceSection : root.section === "recording" ? recordingSection : root.section === "power" ? powerSection : settingsSection
                }
            }
        }
    }
    Component {
        id: audioSection
        ColumnLayout {
            spacing: root.gap
            Repeater {
                model: ["output", "input"]
                delegate: ColumnLayout {
                    id: directionGroup
                    required property string modelData
                    Layout.fillWidth: true
                    spacing: root.gap
                    Label { text: directionGroup.modelData === "output" ? "Speakers and headphones" : "Microphones"; font.bold: true }
                    Label {
                        visible: !root.items("audio").some(function(row) { return row.direction === directionGroup.modelData; })
                        text: "No " + directionGroup.modelData + " devices available"
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                    Repeater {
                        model: root.items("audio").filter(function(row) { return row.direction === directionGroup.modelData; })
                        delegate: AudioDeviceRow {
                            required property var modelData
                            Layout.fillWidth: true
                            device: modelData
                            busy: root.busy
                            isDefault: root.topicData("audio")["default_" + directionGroup.modelData + "_id"] === modelData.id
                            onVolumeRequested: volume => root.request("audio.set_volume", {id:modelData.id,volume:volume})
                            onMuteRequested: muted => root.request("audio.set_mute", {id:modelData.id,muted:muted})
                            onDefaultRequested: root.request("audio.set_default", {id:modelData.id})
                        }
                    }
                }
            }
            Button { objectName: "audioMixer"; text: "Open audio mixer"; enabled: !root.busy; onClicked: root.request("audio.open_mixer", {}) }
        }
    }
    Component {
        id: mediaSection
        ColumnLayout {
            spacing: root.gap
            Label { visible: root.items("media").length === 0; text: "No media players available" }
            Repeater {
                model: root.items("media")
                delegate: MediaControlRow {
                    required property var modelData
                    Layout.fillWidth: true
                    player: modelData
                    busy: root.busy
                    onTransportRequested: action => root.request("media." + action, {id:modelData.id})
                }
            }
        }
    }
    Component {
        id: networkSection
        ColumnLayout {
            spacing: root.gap
            Label { visible: root.items("network").length === 0; text: "No wired interfaces available" }
            Repeater {
                model: root.items("network")
                delegate: Label {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.label + " · " + modelData.interface + " · " + modelData.state + "\nCable: " + (modelData.carrier === null ? "Unavailable" : modelData.carrier ? "Connected" : "Disconnected")
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                }
            }
            Button { objectName:"networkEditor"; text:"Edit connections"; enabled:!root.busy; onClicked:root.request("network.open", {}) }
        }
    }
    Component {
        id: outputSection
        ColumnLayout {
            spacing: root.gap
            Label { visible: root.items("outputs").length === 0; text: "No output information available" }
            Repeater {
                model: root.items("outputs")
                delegate: Label {
                    required property var modelData
                    Layout.fillWidth: true
                    text: (modelData.label || modelData.id) + (modelData.focused ? " · Focused" : "") + "\n" + modelData.width + " × " + modelData.height + " at " + modelData.x + ", " + modelData.y + " · Scale " + modelData.scale
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                }
            }
        }
    }
    Component {
        id: appearanceSection
        ColumnLayout {
            spacing: root.gap
            Label { text:"Themes"; font.bold:true }
            Repeater {
                model: root.topicData("appearance").themes || []
                delegate: Button {
                    required property var modelData
                    objectName: "theme-" + modelData.id
                    Layout.fillWidth: true
                    text: modelData.label + (root.topicData("appearance").theme_id === modelData.id ? " · Current" : "")
                    enabled: !root.busy && root.topicData("appearance").theme_id !== modelData.id
                    onClicked: root.request("appearance.set_theme", {id:modelData.id})
                }
            }
            Label { text:"Wallpapers"; font.bold:true }
            Repeater {
                model: root.topicData("appearance").wallpapers || []
                delegate: Button {
                    required property var modelData
                    objectName: "wallpaper-" + modelData.id
                    Layout.fillWidth: true
                    text: modelData.label + (root.topicData("appearance").wallpaper_id === modelData.id ? " · Current" : "")
                    enabled: !root.busy && root.topicData("appearance").wallpaper_id !== modelData.id
                    onClicked: root.request("appearance.set_wallpaper", {id:modelData.id,theme_id:root.topicData("appearance").theme_id,release_id:root.topicData("appearance").release_id})
                }
            }
        }
    }
    Component {
        id: recordingSection
        ColumnLayout {
            spacing: root.gap
            Label { text: "Recording: " + (root.topicData("recording").state || "Unavailable"); textFormat:Text.PlainText }
            Button {
                objectName:"recordingStop"
                text:"Stop recording"
                enabled: !root.busy && root.topicData("recording").can_stop === true
                onClicked: root.request("recording.stop", {run_id:root.topicData("recording").run_id})
            }
            Label { Layout.fillWidth:true; wrapMode:Text.Wrap; text:"Start a recording from the capture menu. Audio is included only when requested." }
        }
    }
    Component {
        id: powerSection
        ColumnLayout {
            spacing: root.gap
            Repeater {
                model: root.topicData("power").actions || []
                delegate: Button {
                    required property var modelData
                    objectName:"power-" + modelData.id
                    Layout.fillWidth:true
                    text: modelData.id.charAt(0).toUpperCase() + modelData.id.slice(1)
                    enabled: !root.busy && modelData.available === true
                    onClicked: {
                        if (["logout","reboot","shutdown"].indexOf(modelData.id) >= 0) root.confirmation = modelData.id;
                        else root.request("power." + modelData.id, {});
                    }
                }
            }
            Label { Layout.fillWidth:true; wrapMode:Text.Wrap; visible:!!root.confirmation; text:"Save your work before " + root.confirmation + ". Confirm to continue." }
            Button { objectName:"powerConfirm"; visible:!!root.confirmation; text:"Confirm " + root.confirmation; enabled:!root.busy && root.powerAvailable(root.confirmation); onClicked:{ var action=root.confirmation; root.confirmation=""; root.request("power."+action,{confirmed:true}); } }
            Button { objectName:"powerCancel"; visible:!!root.confirmation; text:"Cancel"; onClicked:root.confirmation="" }
        }
    }
    Component {
        id: settingsSection
        ColumnLayout {
            spacing: root.gap
            Label { text:"Control layout"; font.bold:true }
            Flow {
                Layout.fillWidth:true
                spacing:root.gap
                Repeater {
                    model:["compact","spacious"]
                    delegate: Button {
                        required property string modelData
                        objectName:"density-"+modelData
                        text:modelData
                        highlighted:(root.settings.density || "spacious") === modelData
                        enabled:!root.busy
                        onClicked:root.settingsRequested("settings.update",{density:modelData})
                    }
                }
            }
            Label { text:"Text scale: " + Math.round(root.textScale*100) + "%" }
            Flow {
                Layout.fillWidth:true
                spacing:root.gap
                Repeater {
                    model:[1,1.25,1.5,2]
                    delegate: Button {
                        required property real modelData
                        objectName:"textScale-"+modelData
                        text:Math.round(modelData*100)+"%"
                        highlighted:root.textScale === modelData
                        enabled:!root.busy
                        onClicked:root.settingsRequested("settings.update",{text_scale:modelData})
                    }
                }
            }
            Button { objectName:"settingsReset"; text:"Reset control center layout"; enabled:!root.busy; onClicked:root.settingsRequested("settings.reset",{}) }
            Button { objectName:"settingsExport"; text:"Export control center layout"; enabled:!root.busy; onClicked:root.settingsRequested("settings.export",{}) }
            TextArea {
                objectName:"settingsExportText"
                Layout.fillWidth:true
                visible:root.exportedSettings.length > 0
                text:root.exportedSettings
                readOnly:true
                selectByMouse:true
                wrapMode:TextEdit.Wrap
                Accessible.name:"Exported control center layout; select and copy to save"
            }
            Label { Layout.fillWidth:true; wrapMode:Text.Wrap; text:"Reset and export apply only to control center layout and text scale. Theme selection stays in Appearance." }
        }
    }
}
