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
    local loaded, found = pcall(vim.treesitter.language.add, lang)   -- returns false, not an error, when absent
    if not (loaded and found) then table.insert(missing, lang) end
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

-- Language servers ============================================================

test('partition enables available servers and lists the missing ones', function()
  local lsp = require('config.lsp')
  local servers = { { name = 'a', exe = 'a.exe', install = 'get a' }, { name = 'b', exe = 'b.exe', install = 'get b' } }
  local enabled, missing = lsp.partition(servers, function(exe) return exe == 'a.exe' end)
  eq(enabled, { 'a' }, 'enabled')
  eq(#missing, 1, 'missing count')
  ok(lsp.missing_message(missing):find('b (get b)', 1, true), 'message names the install command')
  eq(lsp.missing_message({}), nil, 'no message when nothing is missing')
end)

test('npm servers run through their .cmd launcher (Git Bash would pick the shell script)', function()
  for _, name in ipairs({ 'vtsls', 'vscode-json-language-server', 'yaml-language-server', 'vscode-eslint-language-server' }) do
    ok(require('config.tools').command(name):lower():match('%.cmd$'), name .. ' resolves to ' .. require('config.tools').command(name))
  end
  ok(vim.lsp.config.vtsls.cmd[1]:lower():match('%.cmd$'), 'vtsls cmd: ' .. vim.inspect(vim.lsp.config.vtsls.cmd))
end)

test('every server in the table is installed', function()
  local _, missing = require('config.lsp').partition(require('config.lsp').servers, require('config.tools').available)
  eq(vim.tbl_map(function(s) return s.name end, missing), {}, 'missing servers')
end)

local function attaches(rel, names)
  local buf = open(fixture(rel))
  for _, name in ipairs(names) do
    local found = vim.wait(30000, function() return #vim.lsp.get_clients({ bufnr = buf, name = name }) > 0 end, 100)
    ok(found, name .. ' did not attach to ' .. rel)
  end
end

test('clangd attaches to C++', function() attaches('files/main.cpp', { 'clangd' }) end)
test('rust-analyzer attaches to Rust', function() attaches('rust/src/main.rs', { 'rust_analyzer' }) end)
test('basedpyright and ruff attach to Python', function() attaches('files/main.py', { 'basedpyright', 'ruff' }) end)
test('vtsls attaches to TypeScript', function() attaches('files/main.ts', { 'vtsls' }) end)
test('PowerShell Editor Services attaches to .ps1', function() attaches('files/script.ps1', { 'powershell_es' }) end)
test('jsonls attaches to JSON and JSONC', function()
  attaches('files/data.json', { 'jsonls' })
  attaches('files/settings.jsonc', { 'jsonls' })
end)
test('yamlls attaches to YAML', function() attaches('files/data.yaml', { 'yamlls' }) end)
test('taplo attaches to TOML', function() attaches('files/data.toml', { 'taplo' }) end)
test('lemminx attaches to XML and XAML', function()
  attaches('files/data.xml', { 'lemminx' })
  attaches('files/View.xaml', { 'lemminx' })
end)
test('lua_ls attaches to this config and knows `vim`', function()
  local buf = open(vim.fn.stdpath('config') .. '/lua/config/options.lua')
  ok(vim.wait(30000, function() return #vim.lsp.get_clients({ bufnr = buf, name = 'lua_ls' }) > 0 end, 100), 'lua_ls did not attach')
  vim.wait(8000, function() return false end)   -- let diagnostics arrive
  for _, d in ipairs(vim.diagnostic.get(buf)) do
    ok(not d.message:find("Undefined global `vim`", 1, true), 'lua_ls does not know vim: ' .. d.message)
  end
end)
test('servers are shut down on exit (PowerShell Editor Services outlived Neovim)', function()
  attaches('files/script.ps1', { 'powershell_es' })
  local children = vim.api.nvim_get_proc_children(vim.fn.getpid())
  ok(#children > 0, 'no server process found')
  vim.api.nvim_exec_autocmds('VimLeavePre', {})
  vim.wait(3000, function() return false end)
  local alive = vim.tbl_filter(function(pid) return vim.api.nvim_get_proc(pid) ~= nil end, children)
  eq(alive, {}, 'server processes still running')
end)

test('a PowerShell server still starting is stopped on exit too', function()
  open(fixture('files/script.ps1'))
  local found = vim.wait(10000, function()
    for _, pid in ipairs(vim.api.nvim_get_proc_children(vim.fn.getpid())) do
      local proc = vim.api.nvim_get_proc(pid)
      if proc and proc.name:lower() == 'pwsh.exe' then return true end
    end
    return false
  end, 20)
  ok(found, 'PowerShell Editor Services did not start')
  local children = vim.api.nvim_get_proc_children(vim.fn.getpid())
  vim.api.nvim_exec_autocmds('VimLeavePre', {})   -- before the client registers
  vim.wait(3000, function() return false end)
  local alive = vim.tbl_filter(function(pid) return vim.api.nvim_get_proc(pid) ~= nil end, children)
  eq(alive, {}, 'server processes still running')
end)

test('no server attaches to a big file', function()
  local root = project({})
  local path = root .. '/big.json'
  local lines = { '[' }
  for i = 1, 120000 do lines[#lines + 1] = '  {"key": "value value value", "n": ' .. i .. '},' end
  lines[#lines + 1] = '  {}]'
  vim.fn.writefile(lines, path)
  local buf = open(path)
  vim.wait(5000, function() return false end)
  eq(#vim.lsp.get_clients({ bufnr = buf }), 0, 'clients on a big file')
end)

-- Formatting ==================================================================

local fmt = function() return require('config.format') end

test('C++ formats on save only with a .clang-format', function()
  local with = project({ ['.clang-format'] = 'BasedOnStyle: LLVM', ['src/deep/a.cpp'] = 'int  main( ){return 0;}' })
  local without = project({ ['a.cpp'] = 'int  main( ){return 0;}' })
  eq(fmt().should_format_on_save(open(with .. '/src/deep/a.cpp')), true, 'with config (nested folder)')
  eq(fmt().should_format_on_save(open(without .. '/a.cpp')), false, 'without config')
end)

test('saving without a project config leaves the file unchanged', function()
  local root = project({ ['a.cpp'] = 'int  main( ){return 0;}' })
  open(root .. '/a.cpp')
  vim.cmd('write')
  eq(read(root .. '/a.cpp'), 'int  main( ){return 0;}', 'file text')
end)

test('saving with a project config formats the file', function()
  local root = project({ ['.clang-format'] = 'BasedOnStyle: LLVM', ['a.cpp'] = 'int  main( ){return 0;}' })
  open(root .. '/a.cpp')
  vim.cmd('write')
  ok(read(root .. '/a.cpp') ~= 'int  main( ){return 0;}', 'file was not formatted')
end)

test('saving TypeScript in a prettier project formats it with prettier', function()
  local root = project({ ['.prettierrc'] = '{ "semi": true }', ['a.ts'] = 'let   a=1' })
  open(root .. '/a.ts')
  vim.cmd('write')
  eq(read(root .. '/a.ts'), 'let a = 1;', 'file text')
end)

test('Python needs ruff.toml or [tool.ruff]', function()
  eq(fmt().should_format_on_save(open(project({ ['pyproject.toml'] = '[tool.ruff]\nline-length = 100', ['a.py'] = 'x=1' }) .. '/a.py')), true, 'tool.ruff')
  eq(fmt().should_format_on_save(open(project({ ['pyproject.toml'] = '[project]\nname = "x"', ['a.py'] = 'x=1' }) .. '/a.py')), false, 'pyproject without ruff')
  eq(fmt().should_format_on_save(open(project({ ['ruff.toml'] = '', ['a.py'] = 'x=1' }) .. '/a.py')), true, 'ruff.toml')
end)

test('JS/TS picks biome or prettier from the project', function()
  eq(fmt().project_formatter(open(project({ ['biome.json'] = '{}', ['a.ts'] = 'let a=1' }) .. '/a.ts')), 'biome', 'biome')
  eq(fmt().project_formatter(open(project({ ['.prettierrc'] = '{}', ['a.ts'] = 'let a=1' }) .. '/a.ts')), 'prettier', 'prettier')
  eq(fmt().project_formatter(open(project({ ['a.ts'] = 'let a=1' }) .. '/a.ts')), nil, 'none')
end)

test('Rust always formats on save; config formats never do', function()
  eq(fmt().should_format_on_save(open(fixture('rust/src/main.rs'))), true, 'rust')
  local root = project({ ['.prettierrc'] = '{}', ['a.json'] = '{"a":1}', ['a.yaml'] = 'a: 1' })
  eq(fmt().should_format_on_save(open(root .. '/a.json')), false, 'json')
  eq(fmt().should_format_on_save(open(root .. '/a.yaml')), false, 'yaml')
  eq(fmt().should_format_on_save(open(fixture('files/script.ps1'))), false, 'ps1')
end)

test('<Leader>lx turns format on save off for the session', function()
  local root = project({ ['.clang-format'] = 'BasedOnStyle: LLVM', ['a.cpp'] = 'int  main( ){}' })
  local buf = open(root .. '/a.cpp')
  fmt().toggle()
  eq(fmt().should_format_on_save(buf), false, 'after toggle')
  fmt().toggle()
  eq(fmt().should_format_on_save(buf), true, 'after second toggle')
  ok(vim.fn.maparg(' lx', 'n') ~= '' and vim.fn.maparg(' lF', 'n') ~= '', 'lx / lF keys')
end)

-- @@ tests end @@

out(('%d passed, %d failed'):format(total - failures, failures))
vim.cmd(failures > 0 and 'cquit 1' or 'qall!')
