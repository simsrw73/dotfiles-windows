require("neo-tree").setup({
  default_component_configs = {
    diagnostics = {
      symbols = {
        hint = "",
        info = " ",
        warn = " ",
        error = " ",
      },
      highlights = {
        hint = "DiagnosticSignHint",
        info = "DiagnosticSignInfo",
        warn = "DiagnosticSignWarn",
        error = "DiagnosticSignError",
      },
    },
  }
})
