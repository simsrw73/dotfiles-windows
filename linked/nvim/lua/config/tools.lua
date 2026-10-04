-- Where language tools live. Most are on PATH; these three come from
-- chezmoi externals (home/.chezmoiexternal.toml.tmpl) under ~/.local/share.
local M = {}

M.share = vim.fs.normalize('~/.local/share')
M.lemminx = M.share .. '/lemminx/lemminx-win32.exe'
M.pses = M.share .. '/powershell-editor-services'
M.pses_start = M.pses .. '/PowerShellEditorServices/Start-EditorServices.ps1'
M.js_debug = M.share .. '/js-debug/src/dapDebugServer.js'

-- LLVM's liblldb embeds Python 3.14 (python314.dll). Windows would otherwise
-- load the first python314.dll on PATH (YASB ships one without the standard
-- library) and lldb-dap dies with "No module named 'encodings'". The Python
-- install manager puts 3.14 here; nil if it isn't installed.
M.lldb_python = (function()
  local base = vim.env.LOCALAPPDATA and (vim.fs.normalize(vim.env.LOCALAPPDATA) .. '/Python') or ''
  for _, dir in ipairs(vim.fn.glob(base .. '/pythoncore-3.14-*', false, true)) do
    if vim.uv.fs_stat(dir .. '/python314.dll') then return vim.fs.normalize(dir) end
  end
end)()

-- The program to run for a command on PATH. npm installs three launchers per
-- command (name, name.cmd, name.ps1); started from Git Bash, Neovim resolves
-- the extensionless shell script, which Windows can't run. Prefer .cmd.
function M.command(name)
  if vim.fn.has('win32') == 1 then
    local cmd = vim.fn.exepath(name .. '.cmd')
    if cmd ~= '' then return cmd end
  end
  return name
end

-- A command name on PATH, or an absolute path to a file.
function M.available(exe)
  if exe:find('[/\\]') then return vim.uv.fs_stat(exe) ~= nil end
  return vim.fn.executable(exe) == 1
end

return M
