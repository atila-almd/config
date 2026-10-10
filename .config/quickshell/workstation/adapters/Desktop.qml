import QtQuick
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import WorkstationShared 1.0

// Native event subscriptions terminate here. Views receive plain snapshots and
// send intents; backend objects never cross the presentation boundary.
QtObject {
    id: root
    property bool observeOutputs: false
    readonly property var outputRows: observeOutputs ? Hyprland.monitors.values.filter(function(monitor) {
        return monitor.width > 0 && monitor.height > 0 && monitor.scale > 0;
    }).map(function(monitor) {
        return {id: monitor.name, label: monitor.description || monitor.name, x: monitor.x, y: monitor.y,
            // The native singleton owns focus, including monitors found at startup.
            width: monitor.width, height: monitor.height, scale: monitor.scale, focused: monitor === Hyprland.focusedMonitor};
    }) : []
    property int outputRevision: 0
    property var outputSnapshot: Contract.unavailable("outputs")
    function publishOutputs() { outputSnapshot = Contract.envelope("outputs", ++outputRevision, {items: outputRows}, observeOutputs && outputRows.length > 0); }
    onOutputRowsChanged: publishOutputs()
    onObserveOutputsChanged: publishOutputs()
    readonly property var workspaceSnapshot: ({schema_version: 1, status: Hyprland.monitors.values.length ? "ready" : "unavailable",
        items: Hyprland.workspaces.values.map(function(w) {
            return {id: String(w.id), name: w.name, output_id: w.monitor ? w.monitor.name : "",
                active: w.active, focused: w.focused, urgent: w.urgent};
        })})
    property var publishedTray: ({schema_version: 1, status: "ready", revision: 0, items: []})
    readonly property var traySnapshot: publishedTray
    readonly property var trayRows: SystemTray.items.values.map(function(item, slot) {
        return {id: item.id, slot: slot, title: item.title, tooltip: item.tooltipTitle,
            icon: item.icon, has_menu: item.hasMenu, only_menu: item.onlyMenu};
    })
    // Publish rows and their revision together. Mutating a revision while its
    // snapshot binding reads lazily initialized rows creates a binding loop.
    function publishTray() {
        publishedTray = {schema_version: 1, status: "ready",
            revision: publishedTray.revision + 1, items: trayRows};
    }
    onTrayRowsChanged: publishTray()
    Component.onCompleted: publishTray()
    function activateWorkspace(id) {
        var rows = Hyprland.workspaces.values;
        for (var i = 0; i < rows.length; ++i) {
            if (String(rows[i].id) === id) { rows[i].activate(); return; }
        }
    }
    // StatusNotifier Id can repeat across processes. Collection slot and
    // revision reject stale actions without pretending it is a global ID.
    function trayAction(id, slot, revision, action, window, x, y, delta, horizontal) {
        if (revision !== publishedTray.revision) return;
        var item = SystemTray.items.values[slot];
        if (!item || item.id !== id) return;
        if (action === "activate") item.activate();
        else if (action === "secondary") item.secondaryActivate();
        else if (action === "menu" && item.hasMenu) item.display(window, x, y);
        else if (action === "scroll") item.scroll(delta, horizontal);
    }
}
