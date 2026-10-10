.pragma library

function keyboardState(text) {
    var v = JSON.parse(text);
    if (!Array.isArray(v.keyboards)) throw new Error("Invalid keyboard state");
    var active = v.keyboards.filter(function(k) { return k.main === true; });
    if (active.length !== 1 || typeof active[0].capsLock !== "boolean" || typeof active[0].active_keymap !== "string")
        throw new Error("Keyboard state unavailable");
    return {schema_version: 1, status: "ready", caps_lock: active[0].capsLock, layout: active[0].active_keymap};
}

function argv(text) {
    var value = JSON.parse(text);
    if (!Array.isArray(value) || value.length === 0 || value.length > 256)
        throw new Error("Enter a nonempty JSON array of arguments.");
    for (var i = 0; i < value.length; ++i) {
        if (typeof value[i] !== "string" || value[i].indexOf("\u0000") !== -1)
            throw new Error("Every argument must be a string without NUL.");
    }
    if (!value[0].length) throw new Error("The command is empty.");
    return value;
}

function snapshot(text) {
    var v = JSON.parse(text);
    if (v.schema_version !== 1) throw new Error("Unsupported data version.");
    if (v.type === "result") {
        if (v.status !== "ok") throw new Error("Subscription rejected.");
        return null;
    }
    if (v.type !== "snapshot" || ["projects", "agent_runs", "audio", "media", "network", "outputs", "recording", "appearance", "power", "notifications"].indexOf(v.topic) < 0
            || typeof v.revision !== "string" || typeof v.observed_at !== "string"
            || ["ready", "error", "unavailable"].indexOf(v.status) < 0)
        throw new Error("Invalid data response.");
    if (v.status !== "ready") {
        if (v.data !== null) throw new Error("Unavailable data must be null.");
        return v;
    }
    if (["projects", "agent_runs"].indexOf(v.topic) < 0) {
        controlData(v.topic, v.data);
        return v;
    }
    if (!v.data || !Array.isArray(v.data.items) || v.data.items.length > 2048)
        throw new Error("Invalid collection.");
    if (v.topic === "projects" && v.data.selected_id !== null && typeof v.data.selected_id !== "string")
        throw new Error("Invalid selection.");
    var seen = Object.create(null);
    v.data.items.forEach(function(row) {
        if (!row || typeof row.id !== "string" || !row.id.length
                || typeof row.label !== "string" || seen[row.id])
            throw new Error("Invalid row.");
        seen[row.id] = true;
        if (v.topic === "projects") {
            if (typeof row.directory_available !== "boolean") throw new Error("Invalid project.");
        } else {
            if (["running", "succeeded", "failed", "interrupted", "state-lost"].indexOf(row.state) < 0)
                throw new Error("Invalid run state.");
            if (typeof row.unit !== "string" || typeof row.started_at !== "string"
                    || (row.project_id !== null && typeof row.project_id !== "string")
                    || (row.ended_at !== null && typeof row.ended_at !== "string")
                    || (row.exit_status !== null && (typeof row.exit_status !== "number"
                        || !isFinite(row.exit_status) || Math.floor(row.exit_status) !== row.exit_status))
                    || row.provider_usage !== null)
                throw new Error("Invalid run metadata.");
            ["cpu_usage_ns", "memory_bytes", "max_rss_bytes"].forEach(function(key) {
                if (row[key] !== null && (typeof row[key] !== "string" || !/^\d+$/.test(row[key])))
                    throw new Error("Invalid counter.");
            });
            ["wall_seconds", "user_cpu_seconds", "system_cpu_seconds"].forEach(function(key) {
                if (row[key] !== null && (typeof row[key] !== "string" || !/^\d+(\.\d+)?$/.test(row[key])))
                    throw new Error("Invalid duration.");
            });
        }
    });
    return v;
}

function theme(text) {
    var v = JSON.parse(text);
    if (v.schema_version !== 1 || typeof v.theme_id !== "string"
            || typeof v.release_id !== "string" || !/^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$/.test(v.release_id)
            || ["light", "dark"].indexOf(v.mode) < 0 || !v.colors)
        throw new Error("Invalid theme release.");
    var keys = ["accent", "selection", "muted", "background", "background_alt",
        "surface", "surface_alt", "foreground", "foreground_muted", "red", "orange",
        "yellow", "green", "cyan", "blue", "magenta"];
    keys.forEach(function(key) {
        if (typeof v.colors[key] !== "string" || !/^#[0-9a-fA-F]{6}$/.test(v.colors[key]))
            throw new Error("Invalid theme color.");
    });
    return v;
}

function unavailable(topic, code) {
    return {schema_version: 1, type: "snapshot", topic: topic, revision: "unavailable",
        observed_at: new Date().toISOString(), status: "unavailable", data: null,
        error: {code: code || "backend_unavailable", message: "Unavailable"}};
}

function envelope(topic, revision, data, ready) {
    if (!ready) return unavailable(topic);
    controlData(topic, data);
    return {schema_version: 1, type: "snapshot", topic: topic, revision: String(revision),
        observed_at: new Date().toISOString(), status: "ready", data: data, error: null};
}

function collection(data) {
    if (!data || !Array.isArray(data.items) || data.items.length > 2048)
        throw new Error("Invalid collection.");
    var ids = Object.create(null);
    data.items.forEach(function(row) {
        if (!row || typeof row.id !== "string" || !row.id.length || row.id.length > 256 || ids[row.id])
            throw new Error("Invalid device identity.");
        ids[row.id] = true;
    });
}

function controlData(topic, data) {
    if (!data || typeof data !== "object" || Array.isArray(data)) throw new Error("Invalid control data.");
    if (["audio", "media", "outputs"].indexOf(topic) >= 0) collection(data);
    if (topic === "audio") {
        ["default_output_id", "default_input_id"].forEach(function(key) {
            if (data[key] !== null && typeof data[key] !== "string") throw new Error("Invalid default audio device.");
        });
        data.items.forEach(function(row) {
            if (!/^\d+$/.test(row.id) || ["input", "output"].indexOf(row.direction) < 0
                    || typeof row.label !== "string" || typeof row.available !== "boolean"
                    || (row.muted !== null && typeof row.muted !== "boolean")
                    || (row.volume !== null && (typeof row.volume !== "number" || !isFinite(row.volume) || row.volume < 0 || row.volume > 1)))
                throw new Error("Invalid audio state.");
        });
    } else if (topic === "media") {
        data.items.forEach(function(row) {
            if (!/^org\.mpris\.MediaPlayer2\.[A-Za-z0-9_.-]+$/.test(row.id)
                    || typeof row.label !== "string" || ["playing", "paused", "stopped"].indexOf(row.state) < 0
                    || (row.title !== null && typeof row.title !== "string") || (row.artist !== null && typeof row.artist !== "string"))
                throw new Error("Invalid player state.");
            ["can_play", "can_pause", "can_next", "can_previous"].forEach(function(key) {
                if (typeof row[key] !== "boolean") throw new Error("Invalid player capability.");
            });
        });
    } else if (topic === "outputs") {
        data.items.forEach(function(row) {
            if (typeof row.label !== "string" || typeof row.focused !== "boolean") throw new Error("Invalid output.");
            ["x", "y", "width", "height", "scale"].forEach(function(key) {
                if (typeof row[key] !== "number" || !isFinite(row[key])) throw new Error("Invalid output geometry.");
            });
            if (row.width <= 0 || row.height <= 0 || row.scale <= 0) throw new Error("Invalid output size.");
        });
    } else if (topic === "network") {
        collection(data);
        data.items.forEach(function(row) {
            if (typeof row.interface !== "string" || typeof row.label !== "string"
                    || ["connected", "connecting", "disconnected", "failed", "unavailable"].indexOf(row.state) < 0
                    || (row.carrier !== null && typeof row.carrier !== "boolean")) throw new Error("Invalid wired network state.");
        });
    } else if (topic === "recording") {
        if ((data.run_id !== null && typeof data.run_id !== "string") || typeof data.can_stop !== "boolean"
                || ["idle", "starting", "recording", "stopping", "completed", "failed", "unknown"].indexOf(data.state) < 0)
            throw new Error("Invalid recording state.");
    } else if (topic === "power") {
        if (!Array.isArray(data.actions) || data.actions.length > 5) throw new Error("Invalid power actions.");
        var powerIds = {};
        data.actions.forEach(function(row) {
            if (!row || ["lock", "suspend", "logout", "reboot", "shutdown"].indexOf(row.id) < 0 || powerIds[row.id]
                    || typeof row.available !== "boolean" || ["yes", "challenge", "no", "na", "unknown"].indexOf(row.authorization) < 0)
                throw new Error("Invalid power capability.");
            powerIds[row.id] = true;
        });
    } else if (topic === "appearance") {
        ["theme_id", "release_id", "wallpaper_id"].forEach(function(key) {
            if (data[key] !== null && typeof data[key] !== "string") throw new Error("Invalid appearance identity.");
        });
        collection({items: data.themes});
        collection({items: data.wallpapers});
        data.themes.forEach(function(row) {
            if (typeof row.label !== "string" || ["light", "dark"].indexOf(row.mode) < 0) throw new Error("Invalid theme entry.");
        });
        data.wallpapers.forEach(function(row) { if (typeof row.label !== "string") throw new Error("Invalid wallpaper entry."); });
        settings(data.settings);
    } else if (topic === "notifications") {
        if (typeof data.dnd !== "boolean"
                || (data.unread_count !== null && (typeof data.unread_count !== "number"
                    || !isFinite(data.unread_count) || Math.floor(data.unread_count) !== data.unread_count
                    || data.unread_count < 0 || data.unread_count > 2048))
                || !Array.isArray(data.items) || data.items.length > 2048)
            throw new Error("Invalid notification state.");
        var notificationIds = Object.create(null);
        data.items.forEach(function(row) {
            if (!row || typeof row.id !== "string" || !/^\d{1,10}$/.test(row.id)
                    || Number(row.id) > 4294967295 || notificationIds[row.id]
                    || typeof row.app_label !== "string" || row.app_label.length > 1024
                    || typeof row.summary !== "string" || row.summary.length > 4096
                    || typeof row.body !== "string" || row.body.length > 8192
                    || ["low", "normal", "critical"].indexOf(row.urgency) < 0
                    || typeof row.timestamp !== "string" || row.timestamp.length > 64
                    || ["history", "displayed"].indexOf(row.state) < 0
                    || !Array.isArray(row.actions) || row.actions.length > 32)
                throw new Error("Invalid notification entry.");
            notificationIds[row.id] = true;
            row.actions.forEach(function(action) {
                if (!action || typeof action.id !== "string" || action.id.length > 128
                        || typeof action.label !== "string" || action.label.length > 1024)
                    throw new Error("Invalid notification action.");
            });
        });
    }
}

function settings(value) {
    if (!value || value.schema_version !== 1 || Object.keys(value).some(function(key) { return ["schema_version", "density", "text_scale"].indexOf(key) < 0; })
            || (value.density !== undefined && ["compact", "spacious"].indexOf(value.density) < 0)
            || (value.text_scale !== undefined && (typeof value.text_scale !== "number" || !isFinite(value.text_scale) || value.text_scale < 1 || value.text_scale > 2)))
        throw new Error("Invalid shell layout settings.");
    return value;
}

function controlIntent(action, args, snapshots) {
    var fields = {"audio.set_volume": ["id", "volume"], "audio.set_mute": ["id", "muted"], "audio.set_default": ["id"],
        "audio.open_mixer": [], "media.play": ["id"], "media.pause": ["id"], "media.next": ["id"], "media.previous": ["id"],
        "network.open": [], "appearance.set_theme": ["id"], "appearance.set_wallpaper": ["id", "theme_id", "release_id"],
        "recording.stop": ["run_id"], "notifications.show": ["id"],
        "notifications.dismiss": ["id"], "notifications.clear": [], "notifications.set_dnd": ["paused"],
        "power.lock": [], "power.suspend": [], "power.logout": ["confirmed"],
        "power.reboot": ["confirmed"], "power.shutdown": ["confirmed"], "settings.update": ["density", "text_scale"],
        "settings.reset": [], "settings.export": []};
    if (!Object.prototype.hasOwnProperty.call(fields, action) || !args || typeof args !== "object" || Array.isArray(args)
            || Object.keys(args).some(function(key) { return fields[action].indexOf(key) < 0; })) throw new Error("Invalid control request.");
    if (action !== "settings.update" && fields[action].some(function(key) { return args[key] === undefined; })) throw new Error("Missing control argument.");
    function data(topic) {
        var value = snapshots[topic];
        if (!value || value.status !== "ready" || !value.data) throw new Error("This control is unavailable.");
        return value.data;
    }
    function row(topic, id) {
        if (typeof id !== "string") throw new Error("Invalid control identity.");
        var found = data(topic).items.filter(function(item) { return item.id === id; });
        if (found.length !== 1) throw new Error("The selected item is no longer available.");
        return found[0];
    }
    if (action.indexOf("audio.set_") === 0) {
        if (!row("audio", args.id).available) throw new Error("Audio device is unavailable.");
        if (action === "audio.set_volume" && (typeof args.volume !== "number" || !isFinite(args.volume) || args.volume < 0 || args.volume > 1)) throw new Error("Invalid volume.");
        if (action === "audio.set_mute" && typeof args.muted !== "boolean") throw new Error("Invalid mute state.");
    } else if (action.indexOf("media.") === 0) {
        var capability = {"media.play": "can_play", "media.pause": "can_pause", "media.next": "can_next", "media.previous": "can_previous"}[action];
        if (!row("media", args.id)[capability]) throw new Error("This media action is unavailable.");
    } else if (action.indexOf("appearance.") === 0) {
        var appearance = data("appearance");
        var candidates = action === "appearance.set_theme" ? appearance.themes : appearance.wallpapers;
        if (typeof args.id !== "string" || !candidates.some(function(item) { return item.id === args.id; })) throw new Error("The appearance selection is no longer available.");
        if (action === "appearance.set_wallpaper" && (args.theme_id !== appearance.theme_id || args.release_id !== appearance.release_id)) throw new Error("The theme changed; choose the wallpaper again.");
    } else if (action.indexOf("notifications.") === 0) {
        if (action === "notifications.set_dnd") {
            if (typeof args.paused !== "boolean") throw new Error("Invalid notification pause state.");
        } else if (action !== "notifications.clear") {
            if (typeof args.id !== "string" || !/^\d{1,10}$/.test(args.id)
                    || Number(args.id) > 4294967295)
                throw new Error("Invalid notification identity.");
            row("notifications", args.id);
        }
    } else if (action === "recording.stop") {
        var recording = data("recording");
        if (!recording.can_stop || args.run_id !== recording.run_id || typeof args.run_id !== "string") throw new Error("The recording is no longer available.");
    } else if (action.indexOf("power.") === 0) {
        var power = action.slice(6);
        if (!data("power").actions.some(function(item) { return item.id === power && item.available; })) throw new Error("This power action is unavailable.");
        if (["logout", "reboot", "shutdown"].indexOf(power) >= 0 && args.confirmed !== true) throw new Error("Confirm this power action first.");
    } else if (action === "settings.update") {
        if (!Object.keys(args).length) throw new Error("No layout change was requested.");
        settings(Object.assign({schema_version: 1}, args));
    }
}

function commandResult(text, requestId) {
    var value = JSON.parse(text);
    if (value.schema_version !== 1 || value.type !== "result" || value.request_id !== requestId
            || ["ok", "cancelled", "error"].indexOf(value.status) < 0)
        throw new Error("Invalid command result.");
    if (value.status === "error" && (!value.error || typeof value.error.code !== "string"
            || typeof value.error.message !== "string" || value.error.message.length > 512))
        throw new Error("Invalid command error.");
    if (value.status !== "error" && value.error !== null) throw new Error("Unexpected command error.");
    return value;
}

// Decimal strings stay exact through the adapter; conversion is display-only.
function bytes(value) {
    if (value === null || value === undefined) return "Unavailable";
    var n = Number(value);
    if (n < 1024) return value + " B";
    var units = ["KiB", "MiB", "GiB", "TiB", "PiB", "EiB"];
    var i = -1;
    do { n /= 1024; ++i; } while (n >= 1024 && i < units.length - 1);
    return n.toFixed(1) + " " + units[i];
}
