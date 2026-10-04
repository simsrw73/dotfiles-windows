-- Headless self-check for this config.
-- Run from the config folder:  nvim --headless "+luafile scripts/check.lua"
-- Prints one line per test; exits 1 if any test fails.

local here = vim.fs.dirname(vim.fs.normalize(debug.getinfo(1, 'S').source:sub(2)))
local failures, total = 0, 0

local function out(line) io.stdout:write(line .. '\n') end

local function test(name, fn)
  total = total + 1
  local passed, err = pcall(fn)
  if passed then
    out('ok   ' .. name)
  else
    failures = failures + 1
    out('FAIL ' .. name .. '\n     ' .. tostring(err))
  end
  pcall(vim.cmd, 'silent! %bwipeout!')
end

local function eq(actual, expected, label)
  if not vim.deep_equal(actual, expected) then
    error(('%s: expected %s, got %s'):format(label or 'value', vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local function ok(value, label)
  if not value then error((label or 'expected a true value'), 2) end
end

local function fixture(rel) return here .. '/fixtures/' .. rel end

local function open(path)
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
  return vim.api.nvim_get_current_buf()
end

-- A fresh temp folder with the given files ({ ['a/b.txt'] = 'text' }).
local function project(files)
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, 'p')
  for rel, text in pairs(files) do
    local path = root .. '/' .. rel
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    vim.fn.writefile(vim.split(text, '\n'), path)
  end
  return root
end

local function read(path) return table.concat(vim.fn.readfile(path), '\n') end

pcall(function() require('config.treesitter').install_missing(10 * 60 * 1000) end)

-- Startup ======================================================================

test('config modules load without errors', function()
  eq(Config.errors, {}, 'Config.errors')
end)

test('colorscheme is catppuccin mocha', function()
  eq(vim.g.colors_name, 'catppuccin-mocha', 'colors_name')
end)

test('plugins are installed and on the runtimepath', function()
  for _, mod in ipairs({ 'mini.pick', 'catppuccin', 'nvim-treesitter', 'conform', 'dap', 'dap-view', 'dap-python', 'log-highlight' }) do
    ok(pcall(require, mod), 'cannot require ' .. mod)
  end
end)

test('MiniMax leader keys still exist', function()
  for _, lhs in ipairs({ ' ff', ' fg', ' fb', ' ed', ' ef', ' en', ' la', ' lf', ' lr', ' gc', ' bd', ' sw', ' tt', ' vv', ' mt', ' oz' }) do
    ok(vim.fn.maparg(lhs, 'n') ~= '', 'missing <Leader>' .. lhs:sub(2))
  end
end)

test('<Leader>ei opens the new init.lua, <Leader>ek the keymaps module', function()
  ok(vim.fn.maparg(' ei', 'n'):find('init.lua', 1, true), 'ei')
  ok(vim.fn.maparg(' ek', 'n'):find('keymaps.lua', 1, true), 'ek')
end)

-- Filetypes, tree-sitter, logs ================================================

test('filetypes are detected', function()
  local expect = {
    ['files/main.cpp'] = 'cpp', ['files/main.py'] = 'python', ['files/main.ts'] = 'typescript',
    ['files/script.ps1'] = 'ps1', ['files/data.json'] = 'json', ['files/settings.jsonc'] = 'jsonc',
    ['files/tsconfig.json'] = 'jsonc', ['files/data.yaml'] = 'yaml', ['files/data.toml'] = 'toml',
    ['files/data.xml'] = 'xml', ['files/View.xaml'] = 'xml', ['files/data.ini'] = 'dosini',
    ['files/app.log'] = 'log', ['files/app.log.1'] = 'log',
  }
  for rel, ft in pairs(expect) do
    local buf = open(fixture(rel))
    eq(vim.bo[buf].filetype, ft, rel)
  end
end)

test('.vscode json files are jsonc', function()
  local root = project({ ['.vscode/settings.json'] = '{\n  // c\n}' })
  eq(vim.bo[open(root .. '/.vscode/settings.json')].filetype, 'jsonc', 'filetype')
end)

test('tree-sitter parsers are installed for every language', function()
  local missing = {}
  for _, lang in ipairs(require('config.treesitter').languages) do
    if not pcall(vim.treesitter.language.add, lang) then table.insert(missing, lang) end
  end
  eq(missing, {}, 'missing parsers')
end)

test('tree-sitter highlights code buffers, including jsonc', function()
  for _, rel in ipairs({ 'files/main.cpp', 'files/main.py', 'files/main.ts', 'files/script.ps1', 'files/settings.jsonc', 'files/data.toml', 'files/View.xaml', 'files/data.ini' }) do
    local buf = open(fixture(rel))
    ok(vim.treesitter.highlighter.active[buf], 'no tree-sitter highlighter for ' .. rel)
  end
end)

test('a big file skips tree-sitter and is marked', function()
  local root = project({})
  local path = root .. '/big.log'
  local line = string.rep('2026-10-04 12:00:00 INFO filler line for size ', 2)
  local lines = {}
  for i = 1, math.ceil(3 * 1024 * 1024 / #line) do lines[i] = line end
  vim.fn.writefile(lines, path)
  local buf = open(path)
  ok(vim.b[buf].bigfile, 'bigfile flag')
  ok(not vim.treesitter.highlighter.active[buf], 'tree-sitter is active on a big file')
end)

test('a log buffer reloads when the file grows and follows the tail', function()
  local root = project({ ['tail.log'] = '2026-10-04 INFO one' })
  local path = root .. '/tail.log'
  local buf = open(path)
  vim.cmd('normal! G')
  vim.fn.writefile({ '2026-10-04 INFO one', '2026-10-04 INFO two', '2026-10-04 INFO three' }, path)
  local interval = require('config.filetypes').log_interval_ms
  ok(vim.wait(interval * 4, function() return vim.api.nvim_buf_line_count(buf) == 3 end, 50), 'buffer did not reload')
  eq(vim.api.nvim_win_get_cursor(0)[1], 3, 'cursor follows the tail')
end)

test('a modified log buffer is left alone (no reload prompt)', function()
  local root = project({ ['edit.log'] = 'one' })
  local path = root .. '/edit.log'
  local buf = open(path)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'edited' })
  vim.fn.writefile({ 'one', 'two' }, path)
  vim.wait(require('config.filetypes').log_interval_ms * 3)
  eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { 'edited' }, 'buffer text')
end)

-- @@ tests end @@

out(('%d passed, %d failed'):format(total - failures, failures))
vim.cmd(failures > 0 and 'cquit 1' or 'qall!')
