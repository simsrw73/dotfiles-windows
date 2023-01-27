local status_ok, catppuccin = pcall(require, "catppuccin")
if not status_ok then
  return
end

catppuccin.setup({
  flavour = "mocha",
  integrations = {
--    bufferline = true,
    dashboard = true,
    gitsigns = true,
--    lualine = true,
    markdown = true,
    mason = true,
    cmp = true,
    dap = true,
--    native_lsp = true,
    nvimtree = true,
    treesitter = true,
    telescope = true,
    illuminate = true,
  },
})

vim.cmd.colorscheme "catppuccin"

