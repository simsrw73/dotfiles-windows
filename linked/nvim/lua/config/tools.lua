-- Where language tools live. Most are on PATH; these three come from
-- chezmoi externals (home/.chezmoiexternal.toml.tmpl) under ~/.local/share.
local M = {}

M.share = vim.fs.normalize('~/.local/share')
M.lemminx = M.share .. '/lemminx/lemminx-win32.exe'
M.pses = M.share .. '/powershell-editor-services'
M.pses_start = M.pses .. '/PowerShellEditorServices/Start-EditorServices.ps1'
M.js_debug = M.share .. '/js-debug/src/dapDebugServer.js'

-- A command name on PATH, or an absolute path to a file.
function M.available(exe)
  if exe:find('[/\\]') then return vim.uv.fs_stat(exe) ~= nil end
  return vim.fn.executable(exe) == 1
end

return M
