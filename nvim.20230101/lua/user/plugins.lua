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
  ensure_dependencies = true,
  auto_clean = true,
  display = {
    open_fn = function()
      return require("packer.util").float { border = "rounded" }
    end,
  },
  git = {
    clone_timeout = 300, -- Timeout, in seconds, for git clones
  },
}

-- Install your plugins here
local function spec(use)
  -- My plugins here
  use { -- Have packer manage itself
    "wbthomason/packer.nvim",
    commit = "6afb67460283f0e990d35d229fd38fdc04063e0a"
  }
  use { -- Useful lua functions used by lots of plugins
    "nvim-lua/plenary.nvim",
    commit = "4b7e52044bbb84242158d977a50c4cbcd85070c7",
  }

  use { -- Autopairs, integrates with both cmp and treesitter
    "windwp/nvim-autopairs",
    commit = "4fc96c8f3df89b6d23e5092d31c866c53a346347",
    config = function()
      require "user.config.autopairs"
    end,
  }

  use {
    "numToStr/Comment.nvim",
    commit = "97a188a98b5a3a6f9b1b850799ac078faa17ab67",
    config = function()
      require "user.config.comment"
    end,
  }

  use {
    "JoosepAlviste/nvim-ts-context-commentstring",
    commit = "32d9627123321db65a4f158b72b757bcaef1a3f4"
  }

  use {
    "kyazdani42/nvim-web-devicons",
    commit = "563f3635c2d8a7be7933b9e547f7c178ba0d4352"
  }

  use {
    "kyazdani42/nvim-tree.lua",
    commit = "7282f7de8aedf861fe0162a559fc2b214383c51c",
    config = function()
      require "user.config.nvim-tree"
    end,
  }

  use {
    "nanozuki/tabby.nvim",
    setup = function()
      vim.opt.showtabline = 2
    end,
    config = function()
      require "user.config.tabby"
    end
  }

  use {
    "moll/vim-bbye",
    commit = "25ef93ac5a87526111f43e5110675032dbcacf56"
  }

  -- use {
  --   "nvim-lualine/lualine.nvim",
  --   commit = "a52f078026b27694d2290e34efa61a6e4a690621",
  --   config = function ()
  --     require "user.config.lualine"
  --   end,
  -- }

  use {
    "feline-nvim/feline.nvim",
    config = function()
      require "user.config.feline"
    end,
    requires = {
      "kyazdani42/nvim-web-devicons"
    }
  }

  use {
    "akinsho/toggleterm.nvim",
    commit = "2a787c426ef00cb3488c11b14f5dcf892bbd0bda",
    config = function()
      require "user.config.toggleterm"
    end,
  }

  use {
    "ahmedkhalf/project.nvim",
    commit = "628de7e433dd503e782831fe150bb750e56e55d6",
    config = function()
      require "user.config.project"
    end,
  }

  use {
    "lewis6991/impatient.nvim",
    commit = "b842e16ecc1a700f62adb9802f8355b99b52a5a6",
  }

  use {
    "lukas-reineke/indent-blankline.nvim",
    commit = "db7cbcb40cc00fc5d6074d7569fb37197705e7f6",
    config = function()
      require "user.config.indentline"
    end,
  }

  use {
    "goolord/alpha-nvim",
    commit = "0bb6fc0646bcd1cdb4639737a1cee8d6e08bcc31",
    config = function()
      require "user.config.alpha"
    end,
  }

  -- Colorscheme
  use {
    "catppuccin/nvim",
    as = "catppuccin",
    config = function()
      pcall(vim.cmd, "colorscheme catppuccin")
    end
  }

  -- use {
  --   "folke/tokyonight.nvim",
  --   commit = "66bfc2e8f754869c7b651f3f47a2ee56ae557764",
  --   config = function()
  --     pcall(vim.cmd, "colorscheme tokyonight-night")
  --   end
  -- }

  -- cmp plugins
  use { -- The completion plugin
    "hrsh7th/nvim-cmp",
    commit = "b0dff0ec4f2748626aae13f011d1a47071fe9abc",
    config = function()
      require "user.config.cmp"
    end,
  }

  use { -- buffer completions
    "hrsh7th/cmp-buffer",
    commit = "3022dbc9166796b644a841a02de8dd1cc1d311fa"
  }

  use { -- path completions
    "hrsh7th/cmp-path",
    commit = "447c87cdd6e6d6a1d2488b1d43108bfa217f56e1"
  }

  use { -- snippet completions
    "saadparwaiz1/cmp_luasnip",
    commit = "a9de941bcbda508d0a45d28ae366bb3f08db2e36"
  }

  use {
    "hrsh7th/cmp-nvim-lsp",
    commit = "affe808a5c56b71630f17aa7c38e15c59fd648a8"
  }

  use {
    "hrsh7th/cmp-nvim-lua",
    commit = "d276254e7198ab7d00f117e88e223b4bd8c02d21"
  }

  -- snippets
  use { --snippet engine
    "L3MON4D3/LuaSnip",
    commit = "8f8d493e7836f2697df878ef9c128337cbf2bb84"
  }

  use { -- a bunch of snippets to use
    "rafamadriz/friendly-snippets",
    commit = "2be79d8a9b03d4175ba6b3d14b082680de1b31b1"
  }

  -- LSP
  -- use { "williamboman/nvim-lsp-installer", commit = "e9f13d7acaa60aff91c58b923002228668c8c9e6" } -- simple to use language server installer
  use { -- enable LSP
    "neovim/nvim-lspconfig",
    commit = "f11fdff7e8b5b415e5ef1837bdcdd37ea6764dda",
    config = function()
      require "user.config.lsp.mason"
      require("user.config.lsp.handlers").setup()
      require "user.config.lsp.null-ls"
    end
  }

  use {
    "williamboman/mason.nvim",
    commit = "bfc5997e52fe9e20642704da050c415ea1d4775f"
  }

  use {
    "williamboman/mason-lspconfig.nvim",
    commit = "0eb7cfefbd3a87308c1875c05c3f3abac22d367c"
  }

  use { -- for formatters and linters
    "jose-elias-alvarez/null-ls.nvim",
    commit = "c0c19f32b614b3921e17886c541c13a72748d450"
  }

  use {
    "SmiteshP/nvim-navic",
    requires = "neovim/nvim-lspconfig",
  }

  use {
    "RRethy/vim-illuminate",
    commit = "a2e8476af3f3e993bb0d6477438aad3096512e42",
    config = function()
      require "user.config.illuminate"
    end,
  }

  -- Telescope
  use {
    "nvim-telescope/telescope.nvim",
    commit = "76ea9a898d3307244dce3573392dcf2cc38f340f",
    config = function()
      require "user.config.telescope"
    end,
  }

  -- Treesitter
  use {
    "nvim-treesitter/nvim-treesitter",
    commit = "8e763332b7bf7b3a426fd8707b7f5aa85823a5ac",
    config = function()
      require "user.config.treesitter"
    end,
  }

  -- Git
  use {
    "lewis6991/gitsigns.nvim",
    commit = "f98c85e7c3d65a51f45863a34feb4849c82f240f",
    config = function()
      require "user.config.gitsigns"
    end
  }

  -- DAP
  use {
    "mfussenegger/nvim-dap",
    commit = "6b12294a57001d994022df8acbe2ef7327d30587",
    config = function()
      require "user.config.dap"
    end
  }

  use {
    "rcarriga/nvim-dap-ui",
    commit = "1cd4764221c91686dcf4d6b62d7a7b2d112e0b13"
  }

  use {
    "ravenxrz/DAPInstall.nvim",
    commit = "8798b4c36d33723e7bba6ed6e2c202f84bb300de",
  }

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end

packer.startup {
  spec,
  config = {
    -- config here
  },
}
