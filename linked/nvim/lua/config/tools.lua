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
-- install manager puts 3.14 here (64-bit, like LLVM); nil if it isn't
-- installed. Keep in step with `python:` in packages.yaml.
M.lldb_python = (function()
  local base = vim.env.LOCALAPPDATA and (vim.fs.normalize(vim.env.LOCALAPPDATA) .. '/Python') or ''
  local dir = base .. '/pythoncore-3.14-64'
  if vim.uv.fs_stat(dir .. '/python314.dll') then return dir end
end)()

-- node and npm's global tools live in fnm's per-shell folder, which exists only
-- in shells that ran `fnm env`. Started any other way (Explorer, a shortcut),
-- Neovim would have no node: fall back to fnm's default Node version.
function M.ensure_node()
  if vim.fn.executable('node') == 1 then return end
  local fnm = vim.env.FNM_DIR or vim.fs.normalize('~/.local/share/fnm')
  local default = fnm .. '/aliases/default'
  if vim.uv.fs_stat(default .. '/node.exe') then
    vim.env.PATH = vim.fs.normalize(default) .. ';' .. vim.env.PATH
  end
end
M.ensure_node()

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
