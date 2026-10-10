-- Hyprland Lua configuration.
-- See https://wiki.hypr.land/Configuring/Start/
-- Component choices are declared in ../../components.tsv and checked by
-- scripts/validate-component-contract.sh.

-- Monitor
local monitor_mode = "preferred"
local monitor_scale = "auto"
local dmi_product_file = io.open("/sys/class/dmi/id/product_name", "r")
if dmi_product_file then
    local dmi_product = dmi_product_file:read("*l") or ""
    dmi_product_file:close()
    if dmi_product == "VirtualBox" then
        -- VirtualBox marks 640x480 preferred despite advertising 1080p and
        -- exposes synthetic display DPI that makes auto scaling oversized.
        monitor_mode = "1920x1080@60"
        monitor_scale = 1
    end
end

hl.monitor({
    output = "",
    mode = monitor_mode,
    position = "auto",
    scale = monitor_scale,
})

-- Programs
local terminal = "session-terminal"
local fileManager = "nemo"

-- Environment
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Look and feel
hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 20,
        border_size = 2,
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
        },
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.1696,
        },
    },
    animations = {
        enabled = true,
    },
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = false,
    },
})

-- Appearance is rendered atomically outside the repository. Keep this small
-- fallback so a missing or malformed Local State release cannot stop the
-- compositor from starting; the generated file contains only hl.config data.
local theme_state_home = os.getenv("XDG_STATE_HOME")
if theme_state_home == nil or theme_state_home == "" then
    theme_state_home = (os.getenv("HOME") or "") .. "/.local/state"
end
local theme_file = theme_state_home .. "/blendos-workstation/theme/current/hyprland-theme.lua"
local fallback_theme = {
    general = {
        col = {
            active_border = {
                colors = {
                    "rgba(33ccffee)",
                    "rgba(00ff99ee)",
                },
                angle = 45,
            },
            inactive_border = "rgba(595959aa)",
        },
    },
    decoration = {
        shadow = {
            color = 0xee1a1a1a,
        },
    },
}
local theme_loaded, generated_theme = pcall(dofile, theme_file)
if theme_loaded and type(generated_theme) == "table" then
    hl.config(generated_theme)
else
    hl.config(fallback_theme)
end

-- Curves and animations
hl.curve("easeOutQuint", {
    type = "bezier",
    points = { { 0.23, 1 }, { 0.32, 1 } },
})
hl.curve("easeInOutCubic", {
    type = "bezier",
    points = { { 0.65, 0.05 }, { 0.36, 1 } },
})
hl.curve("linear", {
    type = "bezier",
    points = { { 0, 0 }, { 1, 1 } },
})
hl.curve("almostLinear", {
    type = "bezier",
    points = { { 0.5, 0.5 }, { 0.75, 1 } },
})
hl.curve("quick", {
    type = "bezier",
    points = { { 0.15, 0 }, { 0.1, 1 } },
})

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })

-- Input
hl.config({
    input = {
        kb_layout = "us",
        kb_variant = "",
        kb_model = "",
        -- Keep the physical Super key and make Caps Lock an additional Super.
        kb_options = "caps:super",
        kb_rules = "",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})

-- Keybindings
local mainMod = "SUPER"

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd("session-lock"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("session-workstation-shell --launcher"))
-- Desktop controls and dedicated searches share the existing launcher backend.
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("session-workstation-shell --launcher"))
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.exec_cmd("session-walker --provider menus:workstation"), { description = "Workstation tools" })
hl.bind(mainMod .. " + ALT + Space", hl.dsp.exec_cmd("session-walker --provider menus:workstation"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("session-workstation-shell --dashboard"), { description = "Island dashboard" })
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("session-workstation-shell --card timer"), { description = "Island timer" })
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("session-workstation-shell --controls power"))
hl.bind(mainMod .. " + CTRL + C", hl.dsp.exec_cmd("session-walker --provider menus:workstation-capture"))
hl.bind(mainMod .. " + CTRL + V", hl.dsp.exec_cmd("walker -m clipboard"))
hl.bind(mainMod .. " + CTRL + E", hl.dsp.exec_cmd("walker -m symbols"))
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("walker -m windows"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("zen-browser"))
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("workstation-keybindings"))
hl.bind(mainMod .. " + CTRL + P", hl.dsp.exec_cmd("workstation-project choose"), { description = "Open project terminal" })
hl.bind(mainMod .. " + CTRL + A", hl.dsp.exec_cmd("workstation-controls audio"), { description = "Audio devices and mixer" })
hl.bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd("session-workstation-shell --controls network"), { description = "Network state and connection editor" })
hl.bind(mainMod .. " + CTRL + D", hl.dsp.exec_cmd("workstation-controls display"), { description = "Display controls" })
hl.bind(mainMod .. " + CTRL + O", hl.dsp.exec_cmd("workstation-controls power"), { description = "Power controls" })
hl.bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd("workstation-controls settings"), { description = "Control center layout" })
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("session-workstation-shell --card notifications"), { description = "Notification history" })
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("dunstctl close-all"))
hl.bind(mainMod .. " + CTRL + N", hl.dsp.exec_cmd("dunstctl set-paused toggle"))
hl.bind(mainMod .. " + CTRL + Space", hl.dsp.exec_cmd("workstation-wallpaper next"))
hl.bind(mainMod .. " + CTRL + SHIFT + Space", hl.dsp.exec_cmd("workstation-theme choose"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Toggle fullscreen" })
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Toggle maximized window" })

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Arrange an editor, terminal and browser using the existing dwindle layout.
-- These actions operate on the focused window and never close applications.
for _, direction in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mainMod .. " + SHIFT + " .. direction, hl.dsp.window.move({ direction = direction }), { description = "Move window " .. direction })
end
hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true, description = "Shrink window width" })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true, description = "Grow window width" })
hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true, description = "Shrink window height" })
hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true, description = "Grow window height" })

for workspace = 1, 10 do
    local key = workspace % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("PRINT", hl.dsp.exec_cmd("workstation-capture region"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("workstation-capture window"))
hl.bind("CTRL + PRINT", hl.dsp.exec_cmd("workstation-capture output"))
hl.bind("ALT + PRINT", hl.dsp.exec_cmd("workstation-capture clipboard"))
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("workstation-capture color"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Window rules
hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move = "20 monitor_h-120",
    float = true,
})
