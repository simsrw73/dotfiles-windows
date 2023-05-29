local wezterm = require "wezterm"
-- local wezterm = require "./catppuccin"

local colors = {
    rosewater = "#f5e0dc",
    flamingo = "#f2cdcd",
    pink = "#f5c2e7",
    mauve = "#cba6f7",
    red = "#f38ba8",
    maroon = "#eba0ac",
    peach = "#fab387",
    yellow = "#f9e2af",
    green = "#a6e3a1",
    teal = "#94e2d5",
    sky = "#89dceb",
    sapphire = "#74c7ec",
    blue = "#89b4fa",
    lavender = "#b4befe",
    text = "#cdd6f4",
    subtext1 = "#bac2de",
    subtext0 = "#a6adc8",
    overlay2 = "#9399b2",
    overlay1 = "#7f849c",
    overlay0 = "#6c7086",
    surface2 = "#585b70",
    surface1 = "#45475a",
    Base = "#313244",
    base = "#1e1e2e",
    mantle = "#181825",
    crust = "#11111b",
}

local config = {
    default_prog = { 'pwsh' },
    color_scheme = "Catppuccin Mocha",
    colors = {
        background = 'black',
        tab_bar = {
            background = colors.crust,
            inactive_tab_edge = colors.overlay0,
            active_tab = {
                bg_color = colors.Base,
                fg_color = colors.text,
            },
            inactive_tab = {
                bg_color = colors.mantle,
                fg_color = colors.text,
            },
            inactive_tab_hover = {
                bg_color = colors.base,
                fg_color = colors.text,
            },
            new_tab = {
                bg_color = colors.Base,
                fg_color = colors.text,
            },
            new_tab_hover = {
                bg_color = colors.surface1,
                fg_color = colors.text,
                italic = true,
            },
        },
    },
    -- window_decorations = "NONE",
    window_background_opacity = 0.7,
    font = wezterm.font_with_fallback {
        'MesloLGM NF',
        'Consolas',
    },
    initial_cols = 100,
    initial_rows = 25,
    window_frame = {
        font = wezterm.font { family = 'SegoeUI', weight = 'Bold' },
        font_size = 10.0,
        active_titlebar_bg = '#181825',
        inactive_titlebar_bg = colors.surface2,
    },
    keys = {
        {
            key = 'C',
            mods = 'CTRL',
            action = wezterm.action.CopyTo 'ClipboardAndPrimarySelection',
        },
        {
            key = 'V',
            mods = 'CTRL',
            action = wezterm.action.PasteFrom 'Clipboard'
        },
    },
}

return config
