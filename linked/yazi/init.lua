require("folder-rules"):setup()
require("toggle-pane"):entry("min-parent")
require("git"):setup {
	-- Order of status signs showing in the linemode
	order = 1500,
}

-- ~/.config/yazi/init.lua

local catppuccin = require("yatline-catppuccin"):setup("mocha")

require("yatline"):setup({
	theme = catppuccin,

	-- The theme exports these as flat keys (section_separator_open, ...) but
	-- yatline only reads the nested form, so wire them across by hand.
	section_separator = { open = catppuccin.section_separator_open, close = catppuccin.section_separator_close },
	part_separator = { open = catppuccin.part_separator_open, close = catppuccin.part_separator_close },
	inverse_separator = { open = catppuccin.inverse_separator_open, close = catppuccin.inverse_separator_close },

	-- NOTE: do not set style_a/style_b/style_c here. Yatline only falls back to
	-- the theme for keys you have *not* set, and the theme's style_a is what
	-- carries bg_mode (the normal/select/unset mode colours).

	tab_width = 20,

	header_line = {
		left = {
			section_a = {
				{ type = "line", name = "tabs" },
			},
			section_c = {
				{ type = "string", name = "tab_path", params = { true, 45, 18 } },
			},
		},
		right = {
			section_c = {
				{ type = "coloreds", name = "githead" },
			},
		},
	},

	status_line = {
		left = {
			section_a = {
				{ type = "string", name = "tab_mode" },
			},
			section_b = {
				{ type = "string", name = "hovered_size" },
			},
			section_c = {
				-- trimmed, max 48, keep 20 chars each end, resolve symlinks
				{ type = "string", name = "hovered_name", params = { true, 48, 20, true } },
			},
		},
		right = {
			section_a = {
				{ type = "string", name = "cursor_position" },
			},
			section_c = {
				{ type = "coloreds", name = "count" },
				{ type = "coloreds", name = "task_states" },
			},
		},
	},
})

-- Must come after yatline:setup(). Passing the theme is what makes the git
-- colours match Catppuccin; a bare setup() falls back to hardcoded defaults.
require("yatline-githead"):setup({
	theme = catppuccin,
	show_numbers = true,
})

require("zoxide"):setup {
    update_db = true,
}
require("duckdb"):setup({
  mode = "summarized",                       -- "standard" or "summarized"
  cache_size = 500,                          -- rows cached in standard mode
  cache_enabled = true,                      -- false to skip parquet caches (sensitive data)
  auto_install_extensions = false,           -- true to download spatial/avro at preview time
  row_id = false,                            -- true, false, or "dynamic"
  minmax_column_width = 21,
  column_fit_factor = 10,
})

function Linemode:size_and_mtime()
	local time = math.floor(self._file.cha.mtime or 0)
	if time == 0 then
		time = ""
	elseif os.date("%Y", time) == os.date("%Y") then
		time = os.date("%b %d %H:%M", time)
	else
		time = os.date("%b %d  %Y", time)
	end

	local size = self._file:size()
	return string.format("%s %s", size and ya.readable_size(size) or "-", time)
end
