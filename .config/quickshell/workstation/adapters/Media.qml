import QtQuick
import Quickshell.Services.Mpris
import WorkstationShared 1.0

QtObject {
    id: root
    property bool observing: false
    // MPRIS is the authoritative source for both transport and track state.
    // Position is sampled only while an activity is visible by tickPosition().
    readonly property var players: observing ? Mpris.players.values : []
    readonly property var values: ({items: players.map(function(player) {
        return {id: player.dbusName, label: player.identity || player.dbusName,
            title: player.trackTitle || null, artist: player.trackArtist || null,
            album: player.trackAlbum || null, art_url: player.trackArtUrl || null,
            position: player.positionSupported ? player.position : 0,
            length: player.lengthSupported ? player.length : 0,
            position_supported: player.positionSupported, length_supported: player.lengthSupported,
            state: player.playbackState === MprisPlaybackState.Playing ? "playing" : player.playbackState === MprisPlaybackState.Paused ? "paused" : "stopped",
            can_play: player.canControl && player.canPlay, can_pause: player.canControl && player.canPause,
            can_next: player.canControl && player.canGoNext, can_previous: player.canControl && player.canGoPrevious};
    })})
    property int revision: 0
    property var snapshot: Contract.unavailable("media")
    function publish() { snapshot = Contract.envelope("media", ++revision, values, observing); }
    onValuesChanged: publish()
    onObservingChanged: publish()
    Component.onCompleted: publish()
    function available(id, action) {
        return observing && players.some(function(player) {
            if (player.dbusName !== id || !player.canControl) return false;
            return action === "media.play" ? player.canPlay : action === "media.pause" ? player.canPause
                : action === "media.next" ? player.canGoNext : action === "media.previous" && player.canGoPrevious;
        });
    }
    function tickPosition() {
        players.forEach(function(player) {
            if (player.playbackState === MprisPlaybackState.Playing && player.positionSupported)
                player.positionChanged();
        });
    }
    function invoke(id, action, value) {
        var player = players.find(function(candidate) { return candidate.dbusName === id; });
        if (!player || !player.canControl) return false;
        if (action === "toggle" && player.canTogglePlaying) player.togglePlaying();
        else if (action === "next" && player.canGoNext) player.next();
        else if (action === "previous" && player.canGoPrevious) player.previous();
        else if (action === "seek" && player.canSeek) player.position = Number(value);
        else return false;
        return true;
    }
}
