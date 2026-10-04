-- Filetype detection, per-language indent, big files, and live log files.
local M = {}

M.bigfile_bytes = 2 * 1024 * 1024
M.log_interval_ms = 1000

vim.filetype.add({
  extension = { xaml = 'xml', axaml = 'xml', csproj = 'xml', vcxproj = 'xml', props = 'xml', targets = 'xml', jsonc = 'jsonc' },
  filename = {
    ['tsconfig.json'] = 'jsonc', ['jsconfig.json'] = 'jsonc',
    ['.clang-format'] = 'yaml', ['.clang-tidy'] = 'yaml', ['.clangd'] = 'yaml',
  },
  pattern = {
    ['.*/%.vscode/.*%.json'] = 'jsonc',
    ['tsconfig%..*%.json'] = 'jsonc',
  },
})

-- Indent width per filetype (the default in options.lua is 4).
local indent = {
  lua = 2, javascript = 2, javascriptreact = 2, typescript = 2, typescriptreact = 2,
  json = 2, jsonc = 2, yaml = 2, toml = 2, xml = 2, html = 2, css = 2, markdown = 2,
}
Config.autocmd('FileType', nil, function(ev)
  local width = indent[ev.match]
  if width then vim.bo[ev.buf].shiftwidth, vim.bo[ev.buf].tabstop = width, width end
end, 'Indent width')

-- Big files: flag before reading; tree-sitter and LSP check the flag.
Config.autocmd('BufReadPre', nil, function(ev)
  if vim.fn.getfsize(ev.match) > M.bigfile_bytes then vim.b[ev.buf].bigfile = true end
end, 'Flag big files')
Config.autocmd('LspAttach', nil, function(ev)
  if vim.b[ev.buf].bigfile then
    vim.schedule(function() vim.lsp.buf_detach_client(ev.buf, ev.data.client_id) end)
  end
end, 'No LSP on big files')

-- Logs: colors from log-highlight; reload while open; G follows the tail.
require('log-highlight').setup({ extension = { 'log', 'out' }, pattern = { '.*%.log%.%d+' } })

local timers = {}
local function stop(buf)
  if timers[buf] then timers[buf]:stop(); timers[buf]:close(); timers[buf] = nil end
end
Config.autocmd('FileType', 'log', function(ev)
  local buf = ev.buf
  if timers[buf] then return end
  vim.bo[buf].autoread = true
  local timer = assert(vim.uv.new_timer())
  timers[buf] = timer
  timer:start(M.log_interval_ms, M.log_interval_ms, vim.schedule_wrap(function()
    if not vim.api.nvim_buf_is_valid(buf) then return stop(buf) end
    if vim.bo[buf].modified then return end   -- reloading would prompt every tick
    vim.cmd('silent! checktime ' .. buf)
  end))
  vim.api.nvim_create_autocmd('BufWipeout', { buffer = buf, once = true, callback = function() stop(buf) end })
end, 'Reload log files')

Config.autocmd({ 'CursorMoved', 'BufEnter' }, nil, function(ev)
  if vim.bo[ev.buf].filetype == 'log' then
    vim.w.log_follow = vim.fn.line('.') == vim.fn.line('$')
  end
end, 'Track log tail')
Config.autocmd('FileChangedShellPost', nil, function(ev)
  if vim.bo[ev.buf].filetype ~= 'log' then return end
  local last = vim.api.nvim_buf_line_count(ev.buf)
  for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
    if vim.w[win].log_follow then vim.api.nvim_win_set_cursor(win, { last, 0 }) end
  end
end, 'Follow log tail')

return M
