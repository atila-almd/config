-- Isolated pre-login compositor configuration. It must not grow desktop
-- autostart, user-service, private-theme or owner-home dependencies.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

hl.config({
    input = {
        kb_layout = "us",
        numlock_by_default = true,
        follow_mouse = 0,
    },
    general = {
        gaps_in = 0,
        gaps_out = 0,
        border_size = 0,
    },
    decoration = {
        rounding = 0,
        blur = {
            enabled = false,
        },
    },
    animations = {
        enabled = false,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        disable_hyprland_guiutils_check = true,
        force_default_wallpaper = -1,
    },
})
