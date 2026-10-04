-- Debugging: nvim-dap with nvim-dap-view (opens and closes with a session).
--   C, C++, Rust: lldb-dap (from LLVM)      Python: debugpy through uv
--   JS/TS: js-debug (node; TypeScript runs through Node's type stripping)
--   PowerShell: PowerShell Editor Services in debug-only mode
local dap = require('dap')
local tools = require('config.tools')

require('dap-view').setup({ auto_toggle = true })

vim.fn.sign_define('DapBreakpoint', { text = '●', texthl = 'DiagnosticError' })
vim.fn.sign_define('DapBreakpointCondition', { text = '◆', texthl = 'DiagnosticWarn' })
vim.fn.sign_define('DapStopped', { text = '▶', texthl = 'DiagnosticOk', linehl = 'Visual' })

local pick_process = function() return require('dap.utils').pick_process() end
local ask_program = function()
  return vim.fn.input('Executable: ', vim.fn.getcwd() .. '/', 'file')
end

-- C, C++, Rust ---------------------------------------------------------------
dap.adapters.lldb = { type = 'executable', command = 'lldb-dap', name = 'lldb' }
if tools.lldb_python then
  -- Point lldb's embedded Python at a full install (see tools.lldb_python).
  -- nvim-dap passes options.env to uv.spawn, which wants "KEY=value" strings.
  local env = vim.fn.environ()
  local path = env.PATH or env.Path or ''
  env.PATH, env.Path = nil, nil
  env.PYTHONHOME = tools.lldb_python
  env.PATH = tools.lldb_python .. ';' .. path
  local list = {}
  for key, value in pairs(env) do table.insert(list, key .. '=' .. value) end
  dap.adapters.lldb.options = { env = list }
end
local native = {
  { name = 'Launch executable', type = 'lldb', request = 'launch', program = ask_program, cwd = '${workspaceFolder}', args = {} },
  { name = 'Attach to process', type = 'lldb', request = 'attach', pid = pick_process },
}
dap.configurations.c = native
dap.configurations.cpp = native
dap.configurations.rust = {
  {
    name = 'Launch target/debug binary', type = 'lldb', request = 'launch', cwd = '${workspaceFolder}', args = {},
    program = function()
      return vim.fn.input('Executable: ', vim.fn.getcwd() .. '/target/debug/', 'file')
    end,
  },
  native[2],
}

-- Python ---------------------------------------------------------------------
require('dap-python').setup('uv')

-- JavaScript / TypeScript ----------------------------------------------------
dap.adapters['pwa-node'] = {
  type = 'server', host = 'localhost', port = '${port}',
  executable = { command = 'node', args = { tools.js_debug, '${port}' } },
}
for _, ft in ipairs({ 'javascript', 'typescript' }) do
  dap.configurations[ft] = {
    { name = 'Launch file', type = 'pwa-node', request = 'launch', program = '${file}', cwd = '${workspaceFolder}' },
    { name = 'Attach to process', type = 'pwa-node', request = 'attach', processId = pick_process, cwd = '${workspaceFolder}' },
  }
end

-- PowerShell -----------------------------------------------------------------
local log_dir = vim.fn.stdpath('log')
local pses_cmd = table.concat({
  "& '" .. tools.pses_start .. "'",
  "-BundledModulesPath '" .. tools.pses .. "'",
  "-LogPath '" .. log_dir .. "/pses-dap'",   -- a folder (PSES 4 writes one log per run)
  "-SessionDetailsPath '" .. log_dir .. "/pses-dap-session.json'",
  '-FeatureFlags @() -AdditionalModules @()',
  '-HostName nvim -HostProfileId 0 -HostVersion 1.0.0',
  '-Stdio -DebugServiceOnly -LogLevel Warning',
}, ' ')
dap.adapters.powershell = {
  type = 'executable', command = 'pwsh',
  args = { '-NoLogo', '-NoProfile', '-NonInteractive', '-Command', pses_cmd },
  -- nvim-dap starts adapters detached (no console); PowerShell then ends the
  -- debug session right after "initialize". Keep it attached.
  options = { detached = false },
}
dap.configurations.ps1 = {
  { name = 'Run script', type = 'powershell', request = 'launch', script = '${file}', cwd = '${workspaceFolder}' },
}
