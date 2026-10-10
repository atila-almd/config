pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "adapters"
import WorkstationShared 1.0

ShellRoot {
    id: root
    property int stage: 0
    property int ticks: 0
    function ensure(value, message) { if (!value) { console.error(message); Qt.exit(1); } }
    Controls { id: controls; observing: true; section: "settings" }
    function request(scenario) {
        controls.observing = true;
        controls.helperCommand = ["bash", Quickshell.env("WORKSTATION_CONTROL_FIXTURE_HELPER"), scenario];
        ensure(controls.dispatch("settings.export", {}), "Fixture request was rejected");
    }
    Component.onCompleted: {
        var media = {items: [{id: "org.mpris.MediaPlayer2.fixture", label: "Player", title: null, artist: null,
            state: "paused", can_play: true, can_pause: false, can_next: false, can_previous: false}]};
        var snapshots = {media: Contract.envelope("media", 1, media, true)};
        Contract.controlIntent("media.play", {id: media.items[0].id}, snapshots);
        var rejected = false;
        try { Contract.controlIntent("media.pause", {id: media.items[0].id}, snapshots); } catch (error) { rejected = true; }
        ensure(rejected, "Unavailable native capability accepted");
        rejected = false;
        try { Contract.controlIntent("media.play", {id: "org.mpris.MediaPlayer2.gone"}, snapshots); } catch (error) { rejected = true; }
        ensure(rejected, "Stale native identity accepted");
        request("ok");
        ensure(!controls.dispatch("settings.reset", {}), "Concurrent command accepted");
        controls.observing = false;
        ensure(controls.busy, "Hiding killed admitted command");
    }
    Timer {
        interval: 30; repeat: true; running: true
        onTriggered: {
            if (++root.ticks > 200) { console.error("Control fixture timed out at stage", root.stage); Qt.exit(1); }
            if (controls.busy) return;
            if (root.stage === 0) {
                root.ensure(JSON.parse(controls.exportedSettings).density === "compact", "Hidden command did not finish");
                root.stage = 1; root.request("error");
            } else if (root.stage === 1) {
                root.ensure(controls.message === "Fixture failure", "Structured command error lost");
                root.stage = 2; root.request("cancelled");
            } else if (root.stage === 2) {
                root.ensure(controls.message === "Cancelled.", "Cancellation lost");
                root.stage = 3; root.request("malformed");
            } else if (root.stage === 3) {
                root.ensure(controls.message.indexOf("invalid response") >= 0, "Malformed response accepted");
                root.stage = 4; controls.helperCommand = ["/nonexistent/workstation-fixture"];
                root.ensure(controls.dispatch("settings.export", {}), "Start failure was not admitted for test");
            } else if (root.stage === 4) {
                root.ensure(controls.message.indexOf("failed") >= 0, "FailedToStart did not settle");
                root.stage = 5; controls.section = "audio";
            } else if (root.stage === 5) {
                root.ensure(!!controls.audioBackend && !controls.mediaBackend, "Audio section lifecycle failed");
                root.stage = 6; controls.section = "media";
            } else if (root.stage === 6) {
                root.ensure(!controls.audioBackend && !!controls.mediaBackend, "Media section lifecycle failed");
                root.stage = 7; controls.observing = false;
            } else {
                root.ensure(!controls.audioBackend && !controls.mediaBackend && !controls.nativeLoaded, "Hidden native adapters survived");
                root.ensure(!controls.dispatch("settings.reset", {}), "Hidden command accepted");
                console.log("Native control protocol, stale capabilities, serialization, hidden completion and section lifecycle passed");
                Qt.quit();
            }
        }
    }
}
