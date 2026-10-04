-- Language servers. nvim-lspconfig supplies each server's defaults;
-- after/lsp/<name>.lua adjusts them. A server is enabled only when its
-- program exists; missing ones are listed once at startup.
local tools = require('config.tools')
local M = {}

local npm_extracted = 'npm install -g vscode-langservers-extracted'
M.servers = {
  { name = 'clangd', exe = 'clangd', install = 'scoop install llvm' },
  { name = 'rust_analyzer', exe = 'rust-analyzer', install = 'rustup component add rust-analyzer' },
  { name = 'basedpyright', exe = 'basedpyright-langserver', install = 'uv tool install basedpyright' },
  { name = 'ruff', exe = 'ruff', install = 'scoop install ruff' },
  { name = 'vtsls', exe = 'vtsls', install = 'npm install -g @vtsls/language-server' },
  { name = 'eslint', exe = 'vscode-eslint-language-server', install = npm_extracted },
  { name = 'jsonls', exe = 'vscode-json-language-server', install = npm_extracted },
  { name = 'yamlls', exe = 'yaml-language-server', install = 'npm install -g yaml-language-server' },
  { name = 'taplo', exe = 'taplo', install = 'scoop install taplo' },
  { name = 'lemminx', exe = tools.lemminx, install = 'chezmoi apply (downloads lemminx)' },
  { name = 'powershell_es', exe = tools.pses_start, install = 'chezmoi apply (downloads PowerShell Editor Services)' },
  { name = 'lua_ls', exe = 'lua-language-server', install = 'scoop install lua-language-server' },
}

function M.partition(servers, available)
  local enabled, missing = {}, {}
  for _, server in ipairs(servers) do
    if available(server.exe) then table.insert(enabled, server.name) else table.insert(missing, server) end
  end
  return enabled, missing
end

function M.missing_message(missing)
  if #missing == 0 then return nil end
  local parts = vim.tbl_map(function(s) return ('%s (%s)'):format(s.name, s.install) end, missing)
  return 'Language servers not installed: ' .. table.concat(parts, ', ')
end

-- npm-installed servers: run the .cmd launcher (see tools.command).
for name, exe in pairs({ vtsls = 'vtsls', jsonls = 'vscode-json-language-server', yamlls = 'yaml-language-server', eslint = 'vscode-eslint-language-server' }) do
  vim.lsp.config(name, { cmd = { tools.command(exe), '--stdio' } })
end

local missing
M.enabled, missing = M.partition(M.servers, tools.available)
vim.lsp.enable(M.enabled)

local message = M.missing_message(missing)
if message then vim.schedule(function() vim.notify(message, vim.log.levels.WARN) end) end

-- On Windows a server can outlive Neovim (PowerShell Editor Services ignores
-- the LSP exit request), so on exit: ask every server to stop, give them a
-- moment, then force-stop (kill) whatever is left.
function M.shutdown(grace_ms)
  local clients = vim.lsp.get_clients()
  for _, client in ipairs(clients) do client:stop() end
  vim.wait(grace_ms or 500, function()
    for _, client in ipairs(clients) do
      if not client:is_stopped() then return false end
    end
    return true
  end, 20)
  for _, client in ipairs(clients) do client:stop(true) end
end
Config.autocmd('VimLeavePre', nil, function() M.shutdown() end, 'Stop language servers')

return M
