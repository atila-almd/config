-- VirtualBox-only pre-login monitor profile. The host wrapper selects this
-- file from DMI and keeps physical displays on their preferred mode.
hl.monitor({
    output = "",
    mode = "1920x1080@60",
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
