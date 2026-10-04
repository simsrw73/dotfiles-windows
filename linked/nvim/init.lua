-- Neovim config: mini.nvim, vim.pack, Catppuccin Mocha.
-- Modules live in lua/config/ and load in the order below. Each loads inside
-- pcall: an error is reported (and recorded in Config.errors for
-- scripts/check.lua) without stopping the rest.

vim.g.mapleader = ' '

_G.Config = { errors = {} }

local group = vim.api.nvim_create_augroup('config', {})
Config.autocmd = function(event, pattern, callback, desc)
  vim.api.nvim_create_autocmd(event, { group = group, pattern = pattern, callback = callback, desc = desc })
end

Config.modules = { 'options', 'plugins', 'filetypes', 'keymaps', 'mini', 'treesitter', 'lsp', 'format', 'dap' }

for _, name in ipairs(Config.modules) do
  local module = 'config.' .. name
  if vim.api.nvim_get_runtime_file('lua/config/' .. name .. '.lua', false)[1] then
    local loaded, err = pcall(require, module)
    if not loaded then
      table.insert(Config.errors, { module = module, err = err })
      vim.notify(module .. ': ' .. tostring(err), vim.log.levels.ERROR)
    end
  end
end
