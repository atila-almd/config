.pragma library

var defaultWidgets = [
    "media", "volume", "battery", "calendar", "performance", "tasks",
    "timer", "recorder", "system_info", "workspaces", "projects", "power",
    "notifications"
];

var defaults = {
    schema_version: 1,
    layout: "grouped",
    theme_mode: "auto",
    enabled_widgets: defaultWidgets,
    widget_order: defaultWidgets,
    animation_speed: 1.0,
    reduce_motion: false,
    bar_height: 40,
    top_margin: 8,
    dashboard_width: 860,
    text_scale: 1.0
};

function clamp(value, minimum, maximum, fallback) {
    var number = Number(value);
    if (!isFinite(number)) return fallback;
    return Math.max(minimum, Math.min(maximum, number));
}

function validWidgets(value) {
    if (!Array.isArray(value)) return defaultWidgets.slice();
    var result = [];
    value.forEach(function(widget) {
        if (typeof widget !== "string" || defaultWidgets.indexOf(widget) < 0 || result.indexOf(widget) >= 0) return;
        result.push(widget);
    });
    return result;
}

function normalize(text) {
    var value = {};
    try { value = JSON.parse(text || "{}"); }
    catch (error) { value = {}; }
    if (!value || typeof value !== "object" || Array.isArray(value)) value = {};

    var enabled = validWidgets(value.enabled_widgets);
    var order = validWidgets(value.widget_order);
    enabled.forEach(function(widget) { if (order.indexOf(widget) < 0) order.push(widget); });

    return {
        schema_version: 1,
        layout: ["grouped", "spread", "one"].indexOf(value.layout) >= 0 ? value.layout : defaults.layout,
        theme_mode: ["auto", "light", "dark"].indexOf(value.theme_mode) >= 0 ? value.theme_mode : defaults.theme_mode,
        enabled_widgets: enabled,
        widget_order: order,
        animation_speed: clamp(value.animation_speed, 0.25, 2.0, defaults.animation_speed),
        reduce_motion: value.reduce_motion === true,
        bar_height: Math.round(clamp(value.bar_height, 32, 64, defaults.bar_height)),
        top_margin: Math.round(clamp(value.top_margin, 4, 24, defaults.top_margin)),
        dashboard_width: Math.round(clamp(value.dashboard_width, 620, 1120, defaults.dashboard_width)),
        text_scale: clamp(value.text_scale, 0.85, 1.35, defaults.text_scale)
    };
}

function duration(base, speed, reduceMotion) {
    if (reduceMotion) return 150;
    return Math.max(1, Math.round(base * speed));
}

function enabled(config, widget) {
    return config && config.enabled_widgets && config.enabled_widgets.indexOf(widget) >= 0;
}
