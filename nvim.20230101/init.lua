-- TODO: Check if installed && can require
local status_ok, imp = pcall(require, "impatient")
if not status_ok then
    print "Failed to load impatient!"
else
    imp.enable_profile()
end

require "user.options"
require "user.keymaps"
require "user.plugins"
require "user.autocommands"


-- TODO: Ordering problem causing bufferline not to be colored unless we call again here.
local status_ok, colorscheme = pcall(vim.cmd, "colorscheme catppuccin")
