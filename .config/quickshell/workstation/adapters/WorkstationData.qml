pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import WorkstationShared 1.0

Item {
    id: root
    required property string socketPath
    property bool observing: false
    property var topics: ["projects", "agent_runs"]
    property bool metrics: true
    property var snapshots: ({})
    property string transportStatus: "Disconnected"
    readonly property var projects: snapshots.projects && snapshots.projects.status === "ready" ? snapshots.projects.data.items : []
    readonly property var runs: snapshots.agent_runs && snapshots.agent_runs.status === "ready" ? snapshots.agent_runs.data.items : []
    readonly property string projectStatus: snapshots.projects ? (snapshots.projects.status === "ready" ? "ready" : "Data unavailable — reconnect to retry") : transportStatus
    readonly property string runStatus: snapshots.agent_runs ? (snapshots.agent_runs.status === "ready" ? "ready" : "Data unavailable — reconnect to retry") : transportStatus
    property string selectedId: ""
    property bool rejected: false
    property var subscribed: []
    property int sequence: 0
    function clear() { snapshots = {}; subscribed = []; transportStatus = "Disconnected"; }
    function reconcile() {
        var retained = {};
        topics.forEach(function(topic) { if (root.snapshots[topic]) retained[topic] = root.snapshots[topic]; });
        snapshots = retained;
        if (!socket.connected || !observing) return;
        var removed = subscribed.filter(function(topic) { return root.topics.indexOf(topic) < 0; });
        if (removed.length) socket.write(JSON.stringify({schema_version: 1, request_id: "unsubscribe-" + (++sequence), op: "unsubscribe", topics: removed}) + "\n");
        if (topics.length) socket.write(JSON.stringify({schema_version: 1, request_id: "subscribe-" + (++sequence), op: "subscribe", topics: topics,
            metrics: metrics && topics.indexOf("agent_runs") >= 0}) + "\n");
        subscribed = topics.slice();
        socket.flush();
    }
    function reconnect() {
        rejected = false;
        socket.connected = false;
        clear();
        if (observing) retry.restart();
    }
    onTopicsChanged: reconcile()
    onMetricsChanged: reconcile()
    onObservingChanged: {
        if (observing) reconnect();
        else { retry.stop(); socket.connected = false; clear(); }
    }
    Component.onCompleted: if (observing) reconnect()
    // Transport retry only. Resource sampling belongs exclusively to the Go service.
    Timer { id: retry; interval: 1000; onTriggered: if (root.observing && !root.rejected) socket.connected = true }
    Socket {
        id: socket
        path: root.socketPath
        onConnectedChanged: {
            if (connected) { root.clear(); root.transportStatus = "Loading…"; root.reconcile(); }
            else { root.clear(); if (root.observing && !root.rejected) retry.restart(); }
        }
        // Quickshell 0.3.1 omits QLocalSocket::LocalSocketError from qmltypes.
        // qmllint disable signal-handler-parameters
        onError: { root.clear(); if (root.observing && !root.rejected) retry.restart(); }
        // qmllint enable signal-handler-parameters
        parser: SplitParser {
            onRead: data => {
                try {
                    if (data.length > 4 * 1024 * 1024) throw new Error("Response too large");
                    var value = Contract.snapshot(data);
                    if (!value || root.topics.indexOf(value.topic) < 0) return;
                    var next = Object.assign({}, root.snapshots);
                    next[value.topic] = value;
                    root.snapshots = next;
                    if (value.topic === "projects" && !root.selectedId && value.status === "ready") root.selectedId = value.data.selected_id || "";
                } catch (error) {
                    root.rejected = true;
                    retry.stop();
                    socket.connected = false;
                    root.clear();
                    root.transportStatus = "Invalid data response — reconnect to retry";
                }
            }
        }
    }
}
