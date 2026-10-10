import QtQuick
import Quickshell
import Quickshell.Io

// Tasks are intentionally local shell state. The file is created only after
// the user adds or completes a task; an absent file means an empty list.
Item {
    id: root
    property string stateHome: Quickshell.env("XDG_STATE_HOME") || ((Quickshell.env("HOME") || "") + "/.local/state")
    property string path: stateHome + "/blendos-workstation/island/tasks.json"
    property var items: []
    property string pendingText: ""
    readonly property string directory: path.slice(0, path.lastIndexOf("/"))

    function load() {
        var value = {};
        try { value = JSON.parse(file.text() || "{}"); } catch (error) { value = {}; }
        if (!value || value.schema_version !== 1 || !Array.isArray(value.items)) {
            root.items = [];
            return;
        }
        root.items = value.items.filter(function(item) {
            return item && typeof item.id === "string" && typeof item.title === "string"
                && typeof item.done === "boolean" && item.title.length > 0;
        }).slice(0, 256);
    }
    function save() {
        root.pendingText = JSON.stringify({schema_version: 1, items: root.items});
        if (!mkdir.running) mkdir.running = true;
    }
    function add(title) {
        var clean = String(title || "").replace(/^\s+|\s+$/g, "");
        if (!clean.length) return false;
        root.items = root.items.concat([{id: "task-" + Date.now(), title: clean, done: false, due: "today"}]);
        root.save();
        return true;
    }
    function setDone(id, done) {
        root.items = root.items.map(function(item) {
            return item.id === id ? {id: item.id, title: item.title, done: done, due: item.due || "today"} : item;
        });
        root.save();
    }
    function remove(id) {
        root.items = root.items.filter(function(item) { return item.id !== id; });
        root.save();
    }

    FileView {
        id: file
        path: root.path
        printErrors: false
        watchChanges: true
        atomicWrites: true
        onLoaded: root.load()
        onFileChanged: file.reload()
        onLoadFailed: root.items = []
    }
    Process {
        id: mkdir
        command: ["mkdir", "-p", root.directory]
        stdout: SplitParser { onRead: {} }
        stderr: SplitParser { onRead: {} }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && exitStatus === 0 && root.pendingText.length) {
                var text = root.pendingText;
                root.pendingText = "";
                file.setText(text);
            }
        }
        // qmllint enable signal-handler-parameters
    }
}
