-- Bootstrap packer if not installed
local ensure_packer = function()
  local install_path = vim.fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
  if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
    vim.fn.system({ 'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path })
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()


-- Automatically source and re-compile packer whenever you save this init.lua
local packer_group = vim.api.nvim_create_augroup('Packer', { clear = true })
vim.api.nvim_create_autocmd('BufWritePost', {
  command = 'source <afile> | silent! LspStop | silent! LspStart | PackerCompile',
  group = packer_group,
  pattern = vim.fn.expand '$MYVIMRC',
})


-- Safely, require packer
local status_ok, packer = pcall(require, "packer")
if not status_ok then
  return
end

-- Initialize packer
packer.init {
  display = {
    open_fn = function()
      return require("packer.util").float { border = "rounded" }
    end,
  },
  git = {
    clone_timeout = 300, -- Timeout, in seconds, for git clones
  },
}

packer.startup({
  function(use)
    -- Package manager
    use 'wbthomason/packer.nvim'

    use { -- LSP Configuration & Plugins
      'neovim/nvim-lspconfig',
      requires = {
        -- Automatically install LSPs to stdpath for neovim
        'williamboman/mason.nvim',
        'williamboman/mason-lspconfig.nvim',

        -- Useful status updates for LSP
        'j-hui/fidget.nvim',

        -- Additional lua configuration, makes nvim stuff amazing
        'folke/neodev.nvim',
      },
      config = function()
        require("user.configs.lsp")
      end,
    }

    use { -- Autocompletion
      'hrsh7th/nvim-cmp',
      requires = { 'hrsh7th/cmp-nvim-lsp', 'L3MON4D3/LuaSnip', 'saadparwaiz1/cmp_luasnip' },
      config = function()
        require("user.configs.cmp")
      end,
    }

    use { -- Highlight, edit, and navigate code
      'nvim-treesitter/nvim-treesitter',
      run = function()
        pcall(require('nvim-treesitter.install').update { with_sync = true })
      end,
      config = function()
        require("user.configs.treesitter")
      end,
    }

    use { -- Additional text objects via treesitter
      'nvim-treesitter/nvim-treesitter-textobjects',
      after = 'nvim-treesitter',
    }

    -- Git related plugins
    use 'tpope/vim-fugitive'
    use 'tpope/vim-rhubarb'
    use {
      'lewis6991/gitsigns.nvim',
      config = function()
        require("user.configs.gitsigns")
      end,
    }

    use {
      "catppuccin/nvim",
      as = "catppuccin",
      config = function()
        pcall(vim.cmd, 'colorscheme catppuccin')
      end
    }

    use {
      'nanozuki/tabby.nvim',
      config = function()
        require("user.configs.tabby")
      end
    }

    use {
      'nvim-lualine/lualine.nvim', -- Fancier statusline
      config = function()
        require("user.configs.lualine")
      end,
    }

    use {
      'lukas-reineke/indent-blankline.nvim', -- Add indentation guides even on blank lines
      config = function()
        require("user.configs.indent_blankline")
      end,
    }
    use {
      'numToStr/Comment.nvim', -- "gc" to comment visual regions/lines
      config = function()
        require("user.configs.comment")
      end,
    }
    use 'tpope/vim-sleuth' -- Detect tabstop and shiftwidth automatically

    -- Fuzzy Finder (files, lsp, etc)
    use {
      'nvim-telescope/telescope.nvim',
      branch = '0.1.x',
      requires = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope-file-browser.nvim' },
      config = function()
        require("user.configs.telescope")
      end,
    }

    -- Fuzzy Finder Algorithm which requires local dependencies to be built. Only load if `make` is available
    use { 'nvim-telescope/telescope-fzf-native.nvim', run = 'make', cond = vim.fn.executable 'make' == 1 }

    use {
      "nvim-telescope/telescope-file-browser.nvim",
      requires = { 'nvim-tree/nvim-web-devicons' },
    }

    use {
      "nvim-neo-tree/neo-tree.nvim",
      branch = "v2.x",
      requires = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
        "MunifTanjim/nui.nvim",
      },
      config = function()
        require("user.configs.neotree")
      end,
    }


    -- Add custom plugins to packer from ~/.config/nvim/lua/custom/plugins.lua
    local has_plugins, plugins = pcall(require, 'custom.plugins')
    if has_plugins then
      plugins(use)
    end

    if packer_bootstrap then
      require('packer').sync()
    end
  end
})

-- You'll need to restart nvim, and then it will work.
if packer_bootstrap then
  print '=================================='
  print '    Plugins are being installed'
  print '    Wait until Packer completes,'
  print '       then restart nvim'
  print '=================================='
  return
end
