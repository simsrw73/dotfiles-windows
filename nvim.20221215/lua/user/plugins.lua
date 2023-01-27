local fn = vim.fn

-- Automatically install packer
local install_path = fn.stdpath "data" .. "/site/pack/packer/start/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
  PACKER_BOOTSTRAP = fn.system {
    "git",
    "clone",
    "--depth",
    "1",
    "https://github.com/wbthomason/packer.nvim",
    install_path,
  }
  print "Installing packer close and reopen Neovim..."
  vim.cmd [[packadd packer.nvim]]
end

-- Autocommand that reloads neovim whenever you save the plugins.lua file
vim.cmd [[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerSync
  augroup end
]]

-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
  return
end

-- Have packer use a popup window
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

return packer.startup(function(use)
  print "startup"

  use { "wbthomason/packer.nvim", commit = "6afb67460283f0e990d35d229fd38fdc04063e0a" } -- Have packer manage itself

  use { "nvim-lua/plenary.nvim", commit = "4b7e52044bbb84242158d977a50c4cbcd85070c7" } -- Useful lua functions used by lots of plugins

  use {
    "windwp/nvim-autopairs",
    commit = "4fc96c8f3df89b6d23e5092d31c866c53a346347",
    config = function ()
      require('user.config.autopairs')
    end,
  } -- Autopairs, integrates with both cmp and treesitter

  use {
    "numToStr/Comment.nvim",
    commit = "97a188a98b5a3a6f9b1b850799ac078faa17ab67",
    config = function ()
      require('user.config.comment')
    end,
  }

  use { "JoosepAlviste/nvim-ts-context-commentstring", commit = "32d9627123321db65a4f158b72b757bcaef1a3f4" }
  use { "kyazdani42/nvim-web-devicons", commit = "563f3635c2d8a7be7933b9e547f7c178ba0d4352" }

  use {
    "kyazdani42/nvim-tree.lua",
    commit = "7282f7de8aedf861fe0162a559fc2b214383c51c",
    config = function ()
      require('user.config.nvim-tree')
    end,
  }

  use {
    "akinsho/bufferline.nvim",
    commit = "83bf4dc7bff642e145c8b4547aa596803a8b4dc4",
    config = function ()
      require('user.config.bufferline')
    end,
  }

  use { "moll/vim-bbye", commit = "25ef93ac5a87526111f43e5110675032dbcacf56" }

  use {
    "nvim-lualine/lualine.nvim",
    commit = "a52f078026b27694d2290e34efa61a6e4a690621",
    config = function ()
      require('user.config.lualine')
    end,
  }

  use {
    "akinsho/toggleterm.nvim",
    commit = "2a787c426ef00cb3488c11b14f5dcf892bbd0bda",
    config = function ()
      require('user.config.toggleterm')
    end,
  }

  use {
    "ahmedkhalf/project.nvim",
    commit = "628de7e433dd503e782831fe150bb750e56e55d6",
    config = function ()
      require('user.config.project')
    end,
  }

  use {
    "lewis6991/impatient.nvim",
    commit = "b842e16ecc1a700f62adb9802f8355b99b52a5a6",
    config = function()
      require('user.config.impatient')
    end,
  }

  use {
    "lukas-reineke/indent-blankline.nvim",
    commit = "db7cbcb40cc00fc5d6074d7569fb37197705e7f6",
    after = 'nvim-treesitter',
    config = function ()
      require('user.config.indentline')
    end,
  }

  use {
    "goolord/alpha-nvim",
    commit = "0bb6fc0646bcd1cdb4639737a1cee8d6e08bcc31",
    config = function ()
      require('user.config.alpha')
    end,
  }

  -- Colorschemes
  use {
    "folke/tokyonight.nvim",
    commit = "66bfc2e8f754869c7b651f3f47a2ee56ae557764",
    config = function ()
      require('user.config.colorscheme')
    end,
  }
  -- use { "lunarvim/darkplus.nvim", commit = "13ef9daad28d3cf6c5e793acfc16ddbf456e1c83" }


  -- Completions
  use {
    'hrsh7th/nvim-cmp',
    commit = "b0dff0ec4f2748626aae13f011d1a47071fe9abc",
    requires = {
      { 'hrsh7th/cmp-buffer', commit = "3022dbc9166796b644a841a02de8dd1cc1d311fa", after = 'nvim-cmp' },
      { 'hrsh7th/cmp-nvim-lsp', commit = "affe808a5c56b71630f17aa7c38e15c59fd648a8" },
      { 'onsails/lspkind.nvim' },
      { 'hrsh7th/cmp-nvim-lsp-signature-help', after = 'nvim-cmp' },
      { 'hrsh7th/cmp-path', commit = "447c87cdd6e6d6a1d2488b1d43108bfa217f56e1", after = 'nvim-cmp' },
      { 'hrsh7th/cmp-nvim-lua', commit = "d276254e7198ab7d00f117e88e223b4bd8c02d21", after = 'nvim-cmp' },
      { 'saadparwaiz1/cmp_luasnip', commit = "a9de941bcbda508d0a45d28ae366bb3f08db2e36", after = 'nvim-cmp' },
      { 'lukas-reineke/cmp-under-comparator' },
      { 'hrsh7th/cmp-cmdline', after = 'nvim-cmp' },
      { 'hrsh7th/cmp-nvim-lsp-document-symbol', after = 'nvim-cmp' },
    },
    config = [[require('user.config.cmp')]],
    -- event = 'InsertEnter',
    -- wants = 'LuaSnip',
  }

  -- snippets
  use { "L3MON4D3/LuaSnip", commit = "8f8d493e7836f2697df878ef9c128337cbf2bb84" } --snippet engine
  use { "rafamadriz/friendly-snippets", commit = "2be79d8a9b03d4175ba6b3d14b082680de1b31b1" } -- a bunch of snippets to use

  -- LSP
  -- use { "williamboman/nvim-lsp-installer", commit = "e9f13d7acaa60aff91c58b923002228668c8c9e6" } -- simple to use language server installer
  use { "neovim/nvim-lspconfig", commit = "f11fdff7e8b5b415e5ef1837bdcdd37ea6764dda" } -- enable LSP
  use { "williamboman/mason.nvim", commit = "bfc5997e52fe9e20642704da050c415ea1d4775f"}
  use { "williamboman/mason-lspconfig.nvim", commit = "0eb7cfefbd3a87308c1875c05c3f3abac22d367c" }
  use { "jose-elias-alvarez/null-ls.nvim", commit = "c0c19f32b614b3921e17886c541c13a72748d450" } -- for formatters and linters

  use {
    "RRethy/vim-illuminate",
    commit = "a2e8476af3f3e993bb0d6477438aad3096512e42",
    config = function ()
      require('user.config.illuminate')
    end,
  }

  -- Search
  use {
    {
      'nvim-telescope/telescope.nvim',
      commit = "76ea9a898d3307244dce3573392dcf2cc38f340f",
      requires = {
        'nvim-lua/popup.nvim',
        'nvim-lua/plenary.nvim',
        'telescope-frecency.nvim',
        'telescope-fzf-native.nvim',
        'nvim-telescope/telescope-ui-select.nvim',
      },
      wants = {
        'popup.nvim',
        'plenary.nvim',
        'telescope-frecency.nvim',
        'telescope-fzf-native.nvim',
      },
      -- setup = [[require('user.config.telescope_setup')]],
      config = [[require('user.config.telescope')]],
      cmd = 'Telescope',
      module = 'telescope',
    },
    {
      'nvim-telescope/telescope-frecency.nvim',
      after = 'telescope.nvim',
      requires = 'tami5/sqlite.lua',
    },
    {
      'nvim-telescope/telescope-fzf-native.nvim',
      run = 'make',
    },
    'crispgm/telescope-heading.nvim',
    'nvim-telescope/telescope-file-browser.nvim',
  }

  -- Treesitter
  use {
    "nvim-treesitter/nvim-treesitter",
    commit = "8e763332b7bf7b3a426fd8707b7f5aa85823a5ac",
    config = function ()
      print "treesitter config"
      require('user.config.treesitter')
    end
  }

  -- Git
  use {
    "lewis6991/gitsigns.nvim",
    commit = "f98c85e7c3d65a51f45863a34feb4849c82f240f",
    config = function ()
      require('user.config.gitsigns')
    end,
  }

  -- Debugger
  use {
    {
      'mfussenegger/nvim-dap',
      commit = "6b12294a57001d994022df8acbe2ef7327d30587",
      -- setup = [[require('user.config.dap_setup')]],
      config = [[require('user.config.dap')]],
      requires = 'jbyuki/one-small-step-for-vimkind',
      wants = 'one-small-step-for-vimkind',
      cmd = { 'BreakpointToggle', 'Debug', 'DapREPL' },
    },
    {
      'rcarriga/nvim-dap-ui',
      commit = "1cd4764221c91686dcf4d6b62d7a7b2d112e0b13",
      requires = 'nvim-dap',
      wants = 'nvim-dap',
      after = 'nvim-dap',
      config = function()
        require('dapui').setup()
      end,
    },
  }

  -- TODO ???
  use { "ravenxrz/DAPInstall.nvim", commit = "8798b4c36d33723e7bba6ed6e2c202f84bb300de" }

  -- Tutorial / Training-Wheels
  use { "ThePrimeagen/vim-be-good" }

  use { "tpope/vim-repeat" }
  use { "tpope/vim-unimpaired" }

  use {
    "ggandor/leap.nvim",
    config = function ()
      require('user.config.leap')
    end,
  }

  use {
    'folke/which-key.nvim',
    config = function()
      require('which-key').setup {}
    end,
    event = 'BufReadPost',
  }

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end)
