local status_ok, _ = pcall(require, "neodev")
if not status_ok then
  return
end

require("neodev").setup({

})

local status_ok, _ = pcall(require, "lspconfig")
if not status_ok then
  return
end

require "user.lsp.mason"
require("user.lsp.handlers").setup()
require "user.lsp.null-ls"

require("lspconfig").gopls.setup {
  on_attach = function ()
    print("Hello, NeoVim")
  end
}


