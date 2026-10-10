pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

// The adapter owns the local JSON bridge. Launcher.qml only receives bounded
// rows and emits typed item activations; Elephant remains the index authority.
Item {
    id: root
    required property string socketPath
    property bool observing: false
    property string query: ""
    property int limit: 30
    property var items: []
    property string status: "unavailable"
    property string message: ""
    property int sequence: 0
    property string requestId: ""
    property bool requestScheduled: false
    property bool rejected: false
    signal activated(bool success, string message)

    function queryPlan() {
        var text = root.query || "";
        var providers = ["desktopapplications", "calc", "websearch"];
        var prefixes = {"/": ["files"], "=": ["calc"], "@": ["websearch"]};
        if (text.length && prefixes[text.charAt(0)]) {
            providers = prefixes[text.charAt(0)];
            text = text.slice(1);
        }
        return {providers: providers, query: text};
    }

    function scheduleQuery() {
        if (root.requestScheduled) return;
        root.requestScheduled = true;
        Qt.callLater(function() {
            root.requestScheduled = false;
            root.requestQuery();
        });
    }

    function requestQuery() {
        if (!root.observing) return;
        if (!socket.connected) {
            root.status = "unavailable";
            root.message = "Launcher backend unavailable; retrying…";
            retry.restart();
            return;
        }
        var plan = root.queryPlan();
        root.requestId = "launcher-" + (++root.sequence);
        root.items = [];
        root.status = "loading";
        root.message = "";
        socket.write(JSON.stringify({
            schema_version: 1,
            request_id: root.requestId,
            op: "query",
            query: plan.query,
            kind: "launcher",
            limit: Math.max(1, Math.min(50, Number(root.limit) || 30)),
            providers: plan.providers
        }) + "\n");
        socket.flush();
    }

    function activate(item, action) {
        if (!root.observing || !item || !item.available || !socket.connected) {
            root.message = "Launcher backend unavailable.";
            return;
        }
        var request = "activate-" + (++root.sequence);
        root.requestId = request;
        root.status = "activating";
        socket.write(JSON.stringify({
            schema_version: 1,
            request_id: request,
            op: "activate",
            provider: String(item.provider || item.kind || ""),
            identifier: String(item.identifier || item.id || ""),
            action: String(action || "")
        }) + "\n");
        socket.flush();
    }

    function reconnect() {
        rejected = false;
        socket.connected = false;
        items = [];
        status = "unavailable";
        message = "";
        if (observing) retry.restart();
    }

    onQueryChanged: if (root.observing) root.scheduleQuery()
    onObservingChanged: {
        if (observing) root.reconnect();
        else {
            retry.stop();
            socket.connected = false;
            items = [];
            status = "unavailable";
        }
    }
    Component.onCompleted: if (observing) root.reconnect()

    Timer {
        id: retry
        interval: 1000
        onTriggered: if (root.observing && !root.rejected) socket.connected = true
    }

    Socket {
        id: socket
        path: root.socketPath
        onConnectedChanged: {
            if (connected) {
                root.rejected = false;
                root.status = "loading";
                root.scheduleQuery();
            } else if (root.observing && !root.rejected) {
                root.status = "unavailable";
                retry.restart();
            }
        }
        // qmllint disable signal-handler-parameters
        onError: {
            root.status = "unavailable";
            if (root.observing && !root.rejected) retry.restart();
        }
        // qmllint enable signal-handler-parameters
        parser: SplitParser {
            onRead: data => {
                try {
                    if (data.length > 4 * 1024 * 1024)
                        throw new Error("Launcher response is too large");
                    var value = JSON.parse(data);
                    if (!value || value.schema_version !== 1
                            || value.request_id !== root.requestId)
                        return;
                    if (value.op === "activate") {
                        if (value.status === "ok") {
                            root.status = "ready";
                            root.message = "";
                            root.activated(true, "");
                        } else {
                            root.status = "error";
                            root.message = value.error && value.error.message
                                ? String(value.error.message) : "Activation failed.";
                            root.activated(false, root.message);
                        }
                        return;
                    }
                    if (value.status === "ready") {
                        root.items = Array.isArray(value.items)
                            ? value.items.slice(0, 50) : [];
                        root.status = "ready";
                        root.message = "";
                    } else {
                        root.items = [];
                        root.status = "error";
                        root.message = value.error && value.error.message
                            ? String(value.error.message) : "Launcher search failed.";
                    }
                } catch (error) {
                    root.rejected = true;
                    retry.stop();
                    socket.connected = false;
                    root.items = [];
                    root.status = "error";
                    root.message = "Launcher returned invalid data.";
                }
            }
        }
    }
}
