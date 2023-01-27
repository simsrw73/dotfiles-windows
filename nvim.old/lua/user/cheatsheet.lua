local status_ok, cheatsheet = pcall(require, "cheatsheet.lua")
if not status_ok then
  return
end

cheatsheet.setup({
  bundled_plugin_cheatsheets = {
    enabled = {
      "gitsigns",
      "telescopt",
    },
    disabled = {},
  }
})

