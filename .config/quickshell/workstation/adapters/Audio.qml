import QtQuick
import Quickshell.Services.Pipewire
import WorkstationShared 1.0
import "../models/AudioLabels.js" as AudioLabels

Item {
    id: root
    property bool observing: false
    readonly property bool ready: observing && Pipewire.ready
    readonly property var nodes: ready ? Pipewire.nodes.values.filter(function(node) { return !!node.audio && !node.isStream; }) : []
    PwObjectTracker { objects: root.nodes }
    readonly property var values: ({
        default_output_id: ready && Pipewire.defaultAudioSink ? String(Pipewire.defaultAudioSink.id) : null,
        default_input_id: ready && Pipewire.defaultAudioSource ? String(Pipewire.defaultAudioSource.id) : null,
        items: nodes.map(function(node) {
            var volume = node.ready ? node.audio.volume : null;
            return {id: String(node.id), direction: node.isSink ? "output" : "input", label: AudioLabels.nodeLabel(node),
                volume: typeof volume === "number" && isFinite(volume) && volume >= 0 && volume <= 1 ? volume : null,
                muted: node.ready ? node.audio.muted : null, available: node.ready};
        })
    })
    property int revision: 0
    property var snapshot: Contract.unavailable("audio")
    function publish() { snapshot = Contract.envelope("audio", ++revision, values, ready); }
    onValuesChanged: publish()
    onReadyChanged: publish()
    Component.onCompleted: publish()
    function available(id) {
        return ready && nodes.some(function(node) { return String(node.id) === id && node.ready; });
    }
}
