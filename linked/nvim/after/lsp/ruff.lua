-- ruff lints and formats; basedpyright owns hover.
return {
  on_attach = function(client) client.server_capabilities.hoverProvider = false end,
}
