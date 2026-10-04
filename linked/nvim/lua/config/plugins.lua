-- Every plugin, in one place. vim.pack installs missing ones on startup and
-- records exact revisions in nvim-pack-lock.json (commit it).
-- Update: :lua vim.pack.update()   (shows changes, :w to apply)

-- Rebuild tree-sitter parsers after nvim-treesitter updates.
Config.autocmd('PackChanged', nil, function(ev)
  local spec, kind = ev.data.spec, ev.data.kind
  if spec.name ~= 'nvim-treesitter' or kind ~= 'update' then return end
  if not ev.data.active then vim.cmd.packadd('nvim-treesitter') end
  vim.cmd('TSUpdate')
end, 'Update tree-sitter parsers')

local gh = function(repo) return 'https://github.com/' .. repo end

vim.pack.add({
  gh('nvim-mini/mini.nvim'),
  { src = gh('catppuccin/nvim'), name = 'catppuccin' },
  { src = gh('nvim-treesitter/nvim-treesitter'), version = 'main' },
  { src = gh('nvim-treesitter/nvim-treesitter-textobjects'), version = 'main' },
  gh('neovim/nvim-lspconfig'),
  gh('stevearc/conform.nvim'),
  gh('mfussenegger/nvim-dap'),
  { src = gh('igorlfs/nvim-dap-view'), version = vim.version.range('1.*') },
  gh('mfussenegger/nvim-dap-python'),
  gh('fei6409/log-highlight.nvim'),
  gh('rafamadriz/friendly-snippets'),
}, { confirm = false })
