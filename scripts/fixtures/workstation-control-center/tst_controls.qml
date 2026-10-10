import QtQuick
import QtTest
import "../../../.config/quickshell/workstation/surfaces"
import "../../../.config/quickshell/workstation/models/AudioLabels.js" as AudioLabels

TestCase {
    id: test
    name: "ControlCenter"
    when: windowShown
    width: 1180; height: 1200
    visible: true
    property var panel
    property bool captured: false
    property var dark: ({background:"#111111",background_alt:"#181818",surface:"#222222",surface_alt:"#333333",foreground:"#ffffff",foreground_muted:"#cccccc",muted:"#888888",selection:"#334477",accent:"#aaccff",red:"#ff8888"})
    property var light: ({background:"#ffffff",background_alt:"#eeeeee",surface:"#dddddd",surface_alt:"#cccccc",foreground:"#111111",foreground_muted:"#555555",muted:"#777777",selection:"#ccddee",accent:"#224477",red:"#bb2233"})
    Component { id: factory; ControlCenter { width:1100; height:1050; colors:test.dark } }
    SignalSpy { id: actions; signalName:"intent" }
    SignalSpy { id: sections; signalName:"sectionRequested" }
    SignalSpy { id: settings; signalName:"settingsRequested" }
    SignalSpy { id: closed; signalName:"closeRequested" }
    function ready(data) { return {schema_version:1,status:"ready",data:data,error:null,revision:"one"}; }
    function snapshots() {
        return {
            audio:ready({default_output_id:"speaker",default_input_id:"mic",items:[
                {id:"speaker",direction:"output",label:"Speakers",volume:0.4,muted:false,available:true},
                {id:"headphones",direction:"output",label:"Headphones",volume:0.2,muted:false,available:true},
                {id:"mic",direction:"input",label:"Microphone",volume:0.7,muted:true,available:true}]}),
            media:ready({items:[{id:"player1",label:"Media player",title:"A track",artist:"An artist",state:"paused",can_play:true,can_pause:false,can_previous:true,can_next:true}]}),
            network:ready({items:[{id:"wired",label:"Wired connection",interface:"enp0s3",state:"connected",carrier:true}]}),
            outputs:ready({items:[{id:"Virtual-1",label:"Virtual-1",x:0,y:0,width:1920,height:1080,scale:1,focused:true}]}),
            appearance:ready({theme_id:"dark",release_id:"release-one",wallpaper_id:"first",themes:[{id:"dark",label:"Dark",mode:"dark"},{id:"light",label:"Light",mode:"light"}],wallpapers:[{id:"first",label:"Mountain"},{id:"second",label:"Forest"}]}),
            recording:ready({run_id:"rec1",state:"recording",can_stop:true}),
            power:ready({actions:[{id:"lock",available:true},{id:"suspend",available:true},{id:"logout",available:true},{id:"reboot",available:true},{id:"shutdown",available:true}]})
        };
    }
    function init() {
        panel=createTemporaryObject(factory,test); verify(panel!==null);
        panel.snapshots=snapshots();
        actions.target=panel; actions.clear(); sections.target=panel; sections.clear();
        settings.target=panel; settings.clear(); closed.target=panel; closed.clear();
        waitForRendering(panel);
    }
    function child(name) { var item=findChild(panel,name); verify(item!==null,"Missing "+name); return item; }
    function verifyFocusVisible(item) {
        var viewport=child("controlScroll"); var point=item.mapToItem(viewport,0,0);
        verify(item.activeFocus,"Expected keyboard focus");
        verify(point.y >= -1 && point.y+item.height <= viewport.height+1,"Focused control stays inside the scrolled viewport");
    }
    function test_tab_scrolling_at_200_percent() {
        panel.width=500; panel.height=600; panel.settings={density:"spacious",text_scale:2};
        waitForRendering(panel);
        child("audioVolume-speaker").forceActiveFocus();
        for(var step=0;step<40 && !child("audioMixer").activeFocus;step++) keyClick(Qt.Key_Tab);
        verifyFocusVisible(child("audioMixer")); verify(child("controlScroll").contentY>0);
        keyClick(Qt.Key_Space); compare(actions.signalArguments[0][0],"audio.open_mixer");
        for(step=0;step<40 && !child("audioVolume-speaker").activeFocus;step++) keyClick(Qt.Key_Tab,Qt.ShiftModifier);
        verifyFocusVisible(child("audioVolume-speaker"));
        panel.section="settings"; waitForRendering(panel);
        child("density-compact").forceActiveFocus();
        for(step=0;step<30 && !child("settingsExport").activeFocus;step++) keyClick(Qt.Key_Tab);
        verifyFocusVisible(child("settingsExport"));
        keyClick(Qt.Key_Space); compare(settings.signalArguments[0][0],"settings.export");
        keyClick(Qt.Key_Tab,Qt.ShiftModifier); verifyFocusVisible(child("settingsReset"));
        keyClick(Qt.Key_Space); compare(settings.signalArguments[1][0],"settings.reset");
        for(step=0;step<30 && !child("density-compact").activeFocus;step++) keyClick(Qt.Key_Tab,Qt.ShiftModifier);
        verifyFocusVisible(child("density-compact"));
        panel.exportedSettings=Array(20).join("Exported text\n"); waitForRendering(panel);
        for(step=0;step<30 && !child("settingsExportText").activeFocus;step++) keyClick(Qt.Key_Tab);
        var exported=child("settingsExportText"), viewport=child("controlScroll");
        verify(exported.activeFocus); verify(exported.height>viewport.height);
        compare(Math.round(exported.mapToItem(viewport,0,0).y),0);
        keyClick(Qt.Key_Escape); compare(closed.count,1);
    }
    function test_selected_label_functions() {
        compare(AudioLabels.friendlyDeviceLabel("Built-in Audio Speakers Output"),"Speakers");
        compare(AudioLabels.friendlyDeviceLabel("sof-soundwire Microphones Input"),"Microphone");
        compare(AudioLabels.nodeLabel({ready:true,properties:{"node.nick":"Built-in Audio Microphones Input"},name:"alsa_input"}),"Microphone");
        compare(AudioLabels.nodeLabel({ready:false,properties:{"node.nick":"Unready secret"},description:"USB Headset Input"}),"USB Headset");
        compare(AudioLabels.nodeProps(null),{}); compare(AudioLabels.nodeLabel(null),"Unknown");
        compare(AudioLabels.nodeLabel({ready:true,nickname:"Preferred",description:"Fallback"}),"Preferred");
    }
    function test_audio_authoritative_failures() {
        var slider=child("audioVolume-speaker");
        compare(slider.value,0.4);
        slider.forceActiveFocus(); keyClick(Qt.Key_Right);
        compare(actions.count,1); compare(actions.signalArguments[0][0],"audio.set_volume");
        verify(actions.signalArguments[0][1].volume>0.4);
        panel.message="Device disappeared before the command completed.";
        compare(slider.value,0.4); // unchanged failed backend snapshot is authoritative
        var next=snapshots(); next.audio.data.items[0].volume=0.8; panel.snapshots=next;
        compare(child("audioVolume-speaker").value,0.8);
        child("audioMute-mic").clicked(); compare(actions.signalArguments[1][0],"audio.set_mute");
        compare(actions.signalArguments[1][1],{id:"mic",muted:false});
        compare(child("audioMute-mic").text,"Unmute");
        child("audioDefault-headphones").clicked(); compare(actions.signalArguments[2][1],{id:"headphones"});
        compare(child("audioDefault-headphones").text,"Use as default");
        panel.busy=true; verify(!child("audioMute-speaker").enabled);
    }
    function test_missing_disappearing_and_unknown_devices() {
        var next=snapshots(); next.audio.data.items=next.audio.data.items.slice(2);
        next.audio.data.items[0].volume=null; next.audio.data.items[0].muted=null; panel.snapshots=next;
        compare(findChild(panel,"audioVolume-speaker"),null);
        verify(!child("audioVolume-mic").visible); verify(!child("audioMute-mic").enabled);
        panel.snapshots={audio:{status:"error",data:null,error:{code:"unavailable",message:"Backend unavailable"}}};
        compare(findChild(panel,"audioMute-mic"),null); verify(child("controlStatus").visible);
        compare(actions.count,0);
    }
    function test_media_explicit_commands() {
        panel.section="media";
        child("media-play-player1").clicked(); compare(actions.signalArguments[0][0],"media.play");
        verify(!child("media-pause-player1").enabled);
        child("media-next-player1").clicked(); compare(actions.signalArguments[1][0],"media.next");
        panel.snapshots={media:ready({items:[]})}; compare(findChild(panel,"media-play-player1"),null);
    }
    function test_sections_keyboard_escape_and_unloading() {
        child("section-media").forceActiveFocus(); keyClick(Qt.Key_Space);
        compare(sections.signalArguments[0][0],"media");
        panel.section="media"; compare(findChild(panel,"audioVolume-speaker"),null);
        child("media-play-player1").forceActiveFocus(); keyClick(Qt.Key_Escape); compare(closed.count,1);
    }
    function test_theme_recording_and_confirmation() {
        panel.section="appearance"; child("wallpaper-second").clicked();
        compare(actions.signalArguments[0][1],{id:"second",theme_id:"dark",release_id:"release-one"});
        child("theme-light").clicked(); compare(actions.signalArguments[1][0],"appearance.set_theme");
        panel.section="recording"; child("recordingStop").clicked(); compare(actions.signalArguments[2][1],{run_id:"rec1"});
        panel.section="power"; child("power-shutdown").clicked(); compare(actions.count,3);
        child("powerCancel").clicked(); compare(panel.confirmation,"");
        child("power-reboot").clicked(); child("powerConfirm").clicked();
        compare(actions.signalArguments[3][0],"power.reboot"); compare(actions.signalArguments[3][1],{confirmed:true});
        child("power-logout").clicked(); child("powerConfirm").forceActiveFocus(); keyClick(Qt.Key_Escape);
        compare(panel.confirmation,""); compare(closed.count,0);
    }
    function test_settings_recovery_and_no_optimistic_update() {
        panel.section="settings"; panel.snapshots={appearance:{status:"error",data:null,error:{code:"corrupt_settings",message:"Unreadable settings"}}};
        verify(child("controlStatus").visible); verify(child("controlStatus").text.indexOf("Unreadable settings") >= 0);
        child("density-compact").clicked(); compare(settings.signalArguments[0][1],{density:"compact"});
        compare(panel.settings,{}); child("settingsReset").clicked(); compare(settings.signalArguments[1][0],"settings.reset");
        child("settingsExport").clicked(); compare(settings.signalArguments[2][1],{});
        panel.exportedSettings='{"schema_version":1,"density":"compact"}';
        compare(child("settingsExportText").text,panel.exportedSettings); verify(child("settingsExportText").readOnly);
        child("textScale-2").clicked(); compare(settings.signalArguments[3][1],{text_scale:2}); compare(panel.textScale,1);
    }
    function test_render_data() {
        return [{tag:"audio-full-dark",section:"audio",width:1100,scale:1,density:"spacious",light:false,state:"full"},
            {tag:"audio-compact-light-200",section:"audio",width:620,scale:2,density:"compact",light:true,state:"full"},
            {tag:"media-spacious-dark-200",section:"media",width:850,scale:2,density:"spacious",light:false,state:"full"},
            {tag:"media-empty-dark",section:"media",width:850,scale:1,density:"spacious",light:false,state:"empty"},
            {tag:"network-error-light",section:"network",width:850,scale:1.5,density:"spacious",light:true,state:"error"},
            {tag:"appearance-dark",section:"appearance",width:850,scale:1,density:"spacious",light:false,state:"full"},
            {tag:"settings-light-200",section:"settings",width:620,scale:2,density:"compact",light:true,state:"full"}];
    }
    function test_render(row) {
        panel.width=row.width; panel.settings={density:row.density,text_scale:row.scale}; panel.colors=row.light?light:dark; panel.section=row.section;
        if(row.state==="empty") panel.snapshots={media:ready({items:[]})};
        if(row.state==="error") panel.snapshots={network:{status:"error",data:null,error:{code:"backend_error",message:"Network service unavailable"}}};
        waitForRendering(panel); captured=false;
        verify(panel.grabToImage(function(result) { test.captured=result.saveToFile("controls-"+row.tag+".png"); }));
        tryCompare(test,"captured",true);
        verify(child("controlClose").width>0); compare(panel.textScale,row.scale);
        compare(child("section-"+row.section).palette.brightText,panel.colors.foreground);
    }
}
