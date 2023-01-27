local status_ok, feline = pcall(require, "feline")
if not status_ok then
    return
end

local mocha = require("catppuccin.palettes").get_palette "mocha"

local vi_mode_colors = {
    NORMAL = "green",
    OP = "green",
    INSERT = "flamingo",
    REPLACE = "red",
    VISUAL = "teal",
    LINES = "sapphire",
    BLOCK = "lavender",
    COMMAND = "text",
}

local c = {
    vim_mode = {
        provider = {
            name = "vi_mode",
            opts = {
                show_mode_name = true,
            },
        },
        hl = function()
            return {
                fg = require("feline.providers.vi_mode").get_mode_color(),
                bg = "crust",
                style = "bold",
                name = "NeovimModeHLColor",
            }
        end,
        left_sep = "block",
        right_sep = "block",
    },
    gitBranch = {
        provider = "git_branch",
        hl = {
            fg = "sky",
            bg = "crust",
            style = "bold",
        },
        left_sep = "block",
        right_sep = "block",
    },
    gitDiffAdded = {
        provider = "git_diff_added",
        hl = {
            fg = "green",
            bg = "crust",
        },
        left_sep = "block",
        right_sep = "block",
    },
    gitDiffRemoved = {
        provider = "git_diff_removed",
        hl = {
            fg = "red",
            bg = "crust",
        },
        left_sep = "block",
        right_sep = "block",
    },
    gitDiffChanged = {
        provider = "git_diff_changed",
        hl = {
            fg = "text",
            bg = "crust",
        },
        left_sep = "block",
        right_sep = "right_filled",
    },
    separator = {
        provider = "",
    },
    fileinfo = {
        provider = {
            name = "file_info",
            opts = {
                type = "relative-short",
            },
        },
        hl = {
            style = "bold",
        },
        left_sep = " ",
        right_sep = " ",
    },
    diagnostic_errors = {
        provider = "diagnostic_errors",
        hl = {
            fg = "red",
        },
    },
    diagnostic_warnings = {
        provider = "diagnostic_warnings",
        hl = {
            fg = "peach",
        },
    },
    diagnostic_hints = {
        provider = "diagnostic_hints",
        hl = {
            fg = "rosewater",
        },
    },
    diagnostic_info = {
        provider = "diagnostic_info",
    },
    lsp_client_names = {
        provider = "lsp_client_names",
        hl = {
            fg = "subtext0",
            bg = "crust",
            style = "bold",
        },
        left_sep = "left_filled",
        right_sep = "block",
    },
    file_type = {
        provider = {
            name = "file_type",
            opts = {
                filetype_icon = true,
                case = "titlecase",
            },
        },
        hl = {
            fg = "subtext0",
            bg = "crust",
            style = "bold",
        },
        left_sep = "block",
        right_sep = "block",
    },
    file_encoding = {
        provider = "file_encoding",
        hl = {
            fg = "subtext0",
            bg = "crust",
            style = "italic",
        },
        left_sep = "block",
        right_sep = "block",
    },
    position = {
        provider = "position",
        hl = {
            fg = "rosewater",
            bg = "crust",
            style = "bold",
        },
        left_sep = "block",
        right_sep = "block",
    },
    line_percentage = {
        provider = "line_percentage",
        hl = {
            fg = "rosewater",
            bg = "crust",
            style = "bold",
        },
        left_sep = "block",
        right_sep = "block",
    },
    scroll_bar = {
        provider = "scroll_bar",
        hl = {
            fg = "rosewater",
            bg = "crust",
            -- style = "bold",
        },
    },
}

local left = {
    c.vim_mode,
    c.gitBranch,
    c.gitDiffAdded,
    c.gitDiffRemoved,
    c.gitDiffChanged,
    c.separator,
}

local middle = {
    c.fileinfo,
    c.diagnostic_errors,
    c.diagnostic_warnings,
    c.diagnostic_info,
    c.diagnostic_hints,
}

local right = {
    c.lsp_client_names,
    -- c.file_type,
    c.file_encoding,
    c.position,
    -- c.line_percentage,
    c.scroll_bar,
}

local components = {
    active = {
        left,
        middle,
        right,
    },
    inactive = {
        left,
        middle,
        right,
    },
}

local ctp_feline = require('catppuccin.groups.integrations.feline')

-- ctp_feline.setup()

feline.setup({
    components = ctp_feline.get(),
})


-- feline.setup({
--     components = components,
--     theme = mocha,
--     vi_mode_colors = vi_mode_colors,
-- })


-- local status_ok, feline = pcall(require, "feline")
-- if not status_ok then
--     return
-- end


-- local navic = require("nvim-navic")
-- navic.setup({
--     highlight = true,
--     separator = "  ",
--     depth_limit = 0,
--     depth_limit_indicator = "...",
-- })


-- local force_inactive = {
--     filetypes = {},
--     buftypes  = {},
--     bufnames  = {}
-- }

-- local winbar_components = {
--     active   = {
--         provider = function() return navic.get_location() end,
--         enabled  = function() return navic.is_available() end,
--     },
--     inactive = {},
-- }

-- local mocha = require("catppuccin.palettes").get_palette "mocha"

-- local catppuccin = {
--     fg = "#cdd6f4",
--     bg = "#11111b",
--     Rosewater = "#f5e0dc",
--     Flamingo = "#f2cdcd",
--     Pink = "#f5c2e7",
--     Mauve = "#cba6f7",
--     Red = "#f38ba8",
--     Maroon = "#eba0ac",
--     Peach = "#fab387",
--     Yellow = "#f9e2af",
--     Green = "#a6e3a1",
--     Teal = "#94e2d5",
--     Sky = "#89dceb",
--     Sapphire = "#74c7ec",
--     Blue = "#89b4fa",
--     Lavender = "#b4befe",
--     Text = "#cdd6f4",
--     Subtext1 = "#bac2de",
--     Subtext0 = "#a6adc8",
--     Overlay2 = "#9399b2",
--     Overlay1 = "#7f849c",
--     Overlay0 = "#6c7086",
--     Surface2 = "#585b70",
--     Surface1 = "#45475a",
--     Surface0 = "#313244",
--     Base = "#1e1e2e",
--     Mantle = "#181825",
--     Crust = "#11111b",
-- }


-- local c = {
--     vim_mode = {
--         provider = {
--             name = "vi_mode",
--             opts = {
--                 show_mode_name = true,
--             },
--         },
--         hl = function()
--             return {
--                 fg = require("feline.providers.vi_mode").get_mode_color(),
--                 bg = "Crust",
--                 style = "bold",
--                 name = "NeovimModeHLColor",
--             }
--         end,
--         left_sep = "block",
--         right_sep = "block",
--     },
--     gitBranch = {
--         provider = "git_branch",
--         hl = {
--             bg = "Crust",
--             fg = "#b4befe",
--         },
--         left_sep = "block",
--         right_sep = "block",
--     },
--     gitDiffAdded = {
--         provider = "git_diff_added",
--         hl = {
--             bg = "Crust",
--             fg = "#a6e3a1",
--         },
--         left_sep = "block",
--         right_sep = "block",
--     },
--     gitDiffRemoved = {
--         provider = "git_diff_removed",
--         hl = {
--             bg = "Crust",
--             fg = "#f38ba8",
--         },
--         left_sep = "block",
--         right_sep = "block",
--     },
--     gitDiffChanged = {
--         provider = "git_diff_changed",
--         hl = {
--             bg = "Crust",
--             fg = "#cdd6f4",
--         },
--         left_sep = "block",
--         right_sep = "right_filled",
--     },
--     separator = {
--         provider = "",
--         hl = {
--             bg = "Crust",
--         }
--     },
--     fileinfo = {
--         provider = {
--             name = "file_info",
--             opts = {
--                 type = "relative-short",
--             },
--         },
--         hl = {
--             bg = "Mantle",
--         },
--         left_sep = " ",
--         right_sep = " ",
--     },
--     diagnostic_errors = {
--         provider = "diagnostic_errors",
--         hl = {
--             bg = "Crust",
--         },
--     },
--     diagnostic_warnings = {
--         provider = "diagnostic_warnings",
--         hl = {
--             bg = "Crust",
--         },
--     },
--     diagnostic_hints = {
--         provider = "diagnostic_hints",
--         hl = {
--             bg = "Crust",
--         },
--     },
--     diagnostic_info = {
--         provider = "diagnostic_info",
--         hl = {
--             bg = "Crust",
--         }
--     },
--     transition = {
--         hl = {
--             bg = "Mantle",
--         }
--     },
--     lsp_client_names = {
--         provider = "lsp_client_names",
--         hl = {
--             bg = "Mantle",
--         },
--         left_sep = "block",
--         right_sep = "block",
--     },
--     file_type = {
--         provider = {
--             name = "file_type",
--             opts = {
--                 case = "titlecase",
--             },
--         },
--         hl = {
--             bg = "Mantle",
--         },
--         left_sep = "block",
--         right_sep = "block",
--     },
--     file_encoding = {
--         provider = "file_encoding",
--         hl = {
--             bg = "Mantle",
--         },
--         left_sep = "block",
--         right_sep = "block",
--     },
--     position = {
--         provider = "position",
--         hl = {
--             bg = "Mantle",
--         },
--         left_sep = "block",
--         right_sep = "block",
--     },
--     line_percentage = {
--         provider = "line_percentage",
--         hl = {
--             bg = "Mantle",
--         },
--         left_sep = "block",
--         right_sep = "block",
--     },
-- }

-- local editor = {
--     c.vim_mode,
-- }

-- local project = {
--     c.gitBranch,
--     c.gitDiffAdded,
--     c.gitDiffRemoved,
--     c.gitDiffChanged,
--     -- c.separator,
--     c.diagnostic_errors,
--     c.diagnostic_warnings,
--     c.diagnostic_info,
--     c.diagnostic_hints,
-- }

-- local file = {
--     c.transition,
--     -- c.fileinfo,
--     c.file_type,
--     c.lsp_client_names,
--     c.file_encoding,
--     c.position,
--     c.line_percentage,
-- }

-- local components = {
--     active = {
--         editor,
--         project,
--         file,
--     },
--     inactive = {
--         editor,
--         project,
--         file,
--     },
-- }


-- local ctp_feline = require('catppuccin.groups.integrations.feline')

-- feline.setup({
--     -- components = ctp_feline.get(),
--     components = components,
--     -- components = vim.tbl_deep_extend("keep", components, ctp_feline.get()),
--     theme = catppuccin,
--     -- vi_mode_colors = vi_mode_colors,
-- })

-- feline.winbar.setup({
--     components = winbar_components,
--     force_inactive = force_inactive,
--     theme = catppuccin,
-- })
