# Neovim mini.nvim Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the MiniMax starter in `linked/nvim` with a mini.nvim config on `vim.pack`, Catppuccin Mocha, full tooling for C/C++, Rust, Python, JS/TS, PowerShell, Lua, config formats and logs.

**Architecture:** `init.lua` loads `lua/config/*` modules in a fixed order, each wrapped in `pcall` so one failure doesn't take down the rest. Language tools come from PATH (installed by the dotfiles); the config only enables what exists. A headless check script (`scripts/check.lua`) is the test suite.

**Tech Stack:** Neovim 0.12.5 (`vim.pack`, `vim.lsp.enable`), mini.nvim, catppuccin/nvim, nvim-treesitter (main), nvim-lspconfig, conform.nvim, nvim-dap, nvim-dap-view, nvim-dap-python, log-highlight.nvim, friendly-snippets. Tools via scoop, npm, uv and chezmoi externals.

**Spec:** `docs/superpowers/specs/2026-10-02-neovim-mini-config-design.md`

## Global Constraints

- All paths below are relative to the dotfiles repo `C:\Users\simsr\.local\share\chezmoi` unless they start with `~`. The live config `~/.config/nvim` is a junction to `linked/nvim`, so edits are live.
- Neovim data dir is `~/.local/share/nvim-data` (`stdpath('data')`); `vim.pack` installs to `<data>/site/pack/core/opt`.
- Keep every MiniMax leader group and key (`b e f g l m o s t v`), `gc`, `[`/`]` jumps, `\` toggles.
- Format on save only with a project formatter config; rustfmt always; JSON/YAML/TOML/XML/PowerShell/Lua never on save.
- Servers are enabled only when their executable exists; one startup notice lists the missing ones with install commands.
- Files over 2 MB skip tree-sitter and language servers.
- Commits are GPG-signed; never bypass. On `gpg: signing failed: Timeout`, ask the user to run `! 'unlock' | gpg --clearsign | Out-Null`.
- Run the check with `nvim --headless "+luafile scripts/check.lua"` from `linked/nvim` (not `nvim -l`: the check needs the user config loaded). Run it from PowerShell.
- `chezmoi apply` installs software: ask the user before running it.

## Rulings against the spec

- **No nvim-lint.** Every linter in the spec's table runs inside a language server (clang-tidy in clangd, clippy in rust-analyzer, ruff, eslint, PSScriptAnalyzer in PSES). `lint.lua` and nvim-lint would do nothing. Cost if wrong: add one plugin later.
- **friendly-snippets added.** mini.snippets ships no snippets; MiniMax used friendly-snippets. Cost if wrong: remove one line.
- **Server overrides in `after/lsp/`, not `lsp/`.** Files in `after/` load after nvim-lspconfig's, so they win. Cost if wrong: none.
- **Per-language indent in `filetypes.lua`** (one table) instead of many `after/ftplugin` files. Cost if wrong: none.
- **JSONC uses the `json` parser** (nvim-treesitter has no jsonc parser).

## Review Focus

1. lldb-dap on Windows may need a matching `python3xx.dll` and fail silently: the adapter check only proves the exe exists; the manual debug checklist must catch it, and the fallback is CodeLLDB.
2. A modified log buffer must not trigger a reload prompt every second (`checktime` on a modified buffer warns): pinned by a test in Task 3.
3. Formatter configs found in a parent folder (file deep in a repo): pinned by a nested-folder test in Task 5.
4. `tsconfig.json` and `.vscode/*.json` contain comments: they must be `jsonc`, not `json`, or jsonls flags every comment. Pinned in Task 3.
5. Big files: a 3 MB log must open with no tree-sitter and no language server. Pinned in Task 3.

---

### Task 1: Install the language tools

**Files:**
- Modify: `home/.chezmoidata/packages.yaml` (scoop `apps`, `node.npm`, `uvtools`)
- Modify: `home/.chezmoiexternal.toml.tmpl` (append three entries)

**Interfaces:**
- Produces: on PATH `clangd clang clang-format clang-tidy lldb-dap tree-sitter ruff taplo lua-language-server stylua vtsls vscode-json-language-server vscode-eslint-language-server yaml-language-server prettier basedpyright-langserver`; files `~/.local/share/lemminx/lemminx-win32.exe`, `~/.local/share/powershell-editor-services/PowerShellEditorServices/Start-EditorServices.ps1`, `~/.local/share/js-debug/src/dapDebugServer.js`.

- [ ] **Step 1: Write the check that fails now**

Run (PowerShell):
```powershell
$exes = 'clangd','clang','clang-format','clang-tidy','lldb-dap','tree-sitter','ruff','taplo','lua-language-server','stylua','vtsls','vscode-json-language-server','vscode-eslint-language-server','yaml-language-server','prettier','basedpyright-langserver','rust-analyzer','node','uv','pwsh'
$files = "$HOME\.local\share\lemminx\lemminx-win32.exe", "$HOME\.local\share\powershell-editor-services\PowerShellEditorServices\Start-EditorServices.ps1", "$HOME\.local\share\js-debug\src\dapDebugServer.js"
$missing = @($exes | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) }) + @($files | Where-Object { -not (Test-Path $_) })
"missing: $($missing.Count)"; $missing
```
Expected now: missing includes clangd, tree-sitter, ruff, vtsls, the three files, etc.

- [ ] **Step 2: Add scoop apps**

In `home/.chezmoidata/packages.yaml` under `packages.scoop.apps`, insert in alphabetical position: `llvm`, `lua-language-server`, `ruff`, `stylua`, `taplo`, `tree-sitter`.

- [ ] **Step 3: Add npm and uv tools**

Under `packages.node.npm` add (keep alphabetical, quote names with `@`):
```yaml
      - "@vtsls/language-server"
      - prettier
      - vscode-langservers-extracted
      - yaml-language-server
```
Under `packages.uvtools` add `basedpyright`.

- [ ] **Step 4: Add chezmoi externals**

Append to `home/.chezmoiexternal.toml.tmpl`:
```toml
# Language tools for Neovim with no scoop/npm package (see linked/nvim).
[".local/share/powershell-editor-services"]
    type = "archive"
    url = "https://github.com/PowerShell/PowerShellEditorServices/releases/latest/download/PowerShellEditorServices.zip"
    exact = true
    refreshPeriod = "168h"

[".local/share/lemminx"]
    type = "archive"
    url = "https://github.com/redhat-developer/vscode-xml/releases/latest/download/lemminx-win32.zip"
    exact = true
    refreshPeriod = "168h"

[".local/share/js-debug"]
    type = "archive"
    url = {{ gitHubLatestReleaseAssetURL "microsoft/vscode-js-debug" "js-debug-dap-v*.tar.gz" | quote }}
    stripComponents = 1
    exact = true
    refreshPeriod = "168h"
```

- [ ] **Step 5: Preview, ask, apply**

Run `chezmoi diff` and `chezmoi execute-template < home/.chezmoiexternal.toml.tmpl` (check the js-debug URL resolved). Show the user what will install; on their OK run `chezmoi apply`. Then open a new PowerShell so PATH updates.

- [ ] **Step 6: Re-run the Step 1 check**

Expected: `missing: 0`. If `lldb-dap` is missing, check `scoop prefix llvm`\bin; if present there but not on PATH, open a new shell. Then run `lldb-dap --help` and confirm it prints usage (a missing Python DLL shows here as an error dialog or exit code; note it for Task 6).

- [ ] **Step 7: Commit**

```bash
git add home/.chezmoidata/packages.yaml home/.chezmoiexternal.toml.tmpl
git commit -m "packages: language tools for the new Neovim config"
```

---

### Task 2: Skeleton: plugins, theme, mini, keys, check harness

**Files:**
- Tag: current HEAD as `nvim-minimax`
- Delete: everything in `linked/nvim` (MiniMax: `.github/`, `configs/`, `plugin/`, `after/`, `snippets/`, `init.lua`, `nvim-pack-lock.json`, `CHANGELOG.md`, `.stylua.toml`, any other file)
- Create: `linked/nvim/init.lua`, `lua/config/options.lua`, `lua/config/plugins.lua`, `lua/config/mini.lua`, `lua/config/keymaps.lua`, `scripts/check.lua`, `.stylua.toml`, `snippets/global.json`

**Interfaces:**
- Produces: global `Config` with `Config.autocmd(event, pattern, callback, desc)`, `Config.errors` (list of `{module, err}`), `Config.leader_group_clues` (mini.clue list), `Config.modules` (load order list). Module load order: `options plugins filetypes keymaps mini treesitter lsp format dap`. Missing modules (later tasks) are skipped silently; real errors land in `Config.errors`.
- Produces: `scripts/check.lua` helpers `test(name, fn)`, `eq(actual, expected, label)`, `ok(value, label)`, `open(path) -> buf`, `fixture(rel) -> abs path`, and the run footer. Later tasks add tests above the footer marker `-- @@ tests end @@`.

- [ ] **Step 1: Tag the old config**

```bash
git tag -s nvim-minimax -m "MiniMax Neovim config before the rewrite"
```

- [ ] **Step 2: Write the check harness with the first tests**

Create `linked/nvim/scripts/check.lua`:
```lua
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
  for rel, text in pairs(files) do
    local path = root .. '/' .. rel
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    vim.fn.writefile(vim.split(text, '\n'), path)
  end
  return root
end

local function read(path) return table.concat(vim.fn.readfile(path), '\n') end

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

-- @@ tests end @@

out(('%d passed, %d failed'):format(total - failures, failures))
vim.cmd(failures > 0 and 'cquit 1' or 'qall!')
```

- [ ] **Step 3: Run it against the old config to see it fail**

Run (PowerShell, in `linked/nvim`): `nvim --headless "+luafile scripts/check.lua"; "exit $LASTEXITCODE"`
Expected: FAIL lines (no `Config.errors`, colorscheme `miniwinter`), exit 1.

- [ ] **Step 4: Remove MiniMax**

Remove every tracked MiniMax file (the untracked `scripts/check.lua` stays):
```bash
git ls-files -z linked/nvim | xargs -0 git rm -q
git ls-files linked/nvim        # expect no output
```
Untracked leftovers (if any) other than `linked/nvim/scripts/`: list with `git status --short --ignored linked/nvim` and delete them.

- [ ] **Step 5: Create `init.lua`**

```lua
-- Neovim config: mini.nvim, vim.pack, Catppuccin Mocha.
-- Modules live in lua/config/ and load in the order below. Each loads inside
-- pcall: an error is reported (and recorded in Config.errors for
-- scripts/check.lua) without stopping the rest.

vim.g.mapleader = ' '

_G.Config = { errors = {} }

local group = vim.api.nvim_create_augroup('config', {})
Config.autocmd = function(event, pattern, callback, desc)
  vim.api.nvim_create_autocmd(event, { group = group, pattern = pattern, callback = callback, desc = desc })
end

Config.modules = { 'options', 'plugins', 'filetypes', 'keymaps', 'mini', 'treesitter', 'lsp', 'format', 'dap' }

for _, name in ipairs(Config.modules) do
  local module = 'config.' .. name
  if vim.api.nvim_get_runtime_file('lua/config/' .. name .. '.lua', false)[1] then
    local loaded, err = pcall(require, module)
    if not loaded then
      table.insert(Config.errors, { module = module, err = err })
      vim.notify(module .. ': ' .. tostring(err), vim.log.levels.ERROR)
    end
  end
end
```

- [ ] **Step 6: Create `lua/config/options.lua`**

```lua
-- Editor settings. See :h option-list.

local o = vim.o
o.mouse = 'a'
o.mousescroll = 'ver:25,hor:6'
o.switchbuf = 'usetab'
o.undofile = true
o.autoread = true
o.shada = "'100,<50,s10,:1000,/100,@100,h"

-- UI
o.breakindent = true
o.breakindentopt = 'list:-1'
o.colorcolumn = '+1'
o.cursorline = true
o.cursorlineopt = 'screenline,number'
o.linebreak = true
o.list = true
o.listchars = 'extends:…,nbsp:␣,precedes:…,tab:> '
o.fillchars = 'eob: ,fold:╌'
o.number = true
o.relativenumber = false
o.pumborder = 'single'
o.pumheight = 10
o.pummaxwidth = 100
o.ruler = false
o.shortmess = 'CFOSWaco'
o.showmode = false
o.signcolumn = 'yes'
o.splitbelow = true
o.splitright = true
o.splitkeep = 'screen'
o.winborder = 'single'
o.wrap = false
o.termguicolors = true

-- Folds (tree-sitter sets foldexpr per buffer; this is the fallback)
o.foldlevel = 99
o.foldmethod = 'indent'
o.foldnestmax = 10
o.foldtext = ''

-- Editing
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.autoindent = true
o.smartindent = true
o.formatoptions = 'rqnl1j'
o.ignorecase = true
o.smartcase = true
o.infercase = true
o.incsearch = true
o.spelloptions = 'camel'
o.virtualedit = 'block'
o.iskeyword = '@,48-57,_,192-255,-'
o.formatlistpat = [[^\s*[0-9\-\+\*]\+[\.\)]*\s\+]]

-- Completion (mini.completion drives the popup)
o.complete = '.,w,b,kspell'
o.completeopt = 'menuone,noselect,fuzzy,nosort'
o.completetimeout = 100

-- Don't continue comments with o/O
Config.autocmd('FileType', nil, function() vim.cmd('setlocal formatoptions-=c formatoptions-=o') end, 'formatoptions')

vim.diagnostic.config({
  signs = { priority = 9999, severity = { min = 'WARN', max = 'ERROR' } },
  underline = { severity = { min = 'HINT', max = 'ERROR' } },
  virtual_lines = false,
  virtual_text = { current_line = true, severity = { min = 'ERROR', max = 'ERROR' } },
  update_in_insert = false,
  severity_sort = true,
})
```

- [ ] **Step 7: Create `lua/config/plugins.lua`**

```lua
-- Every plugin, in one place. vim.pack installs missing ones on startup and
-- records exact revisions in nvim-pack-lock.json (commit it).
-- Update: :lua vim.pack.update()   (shows changes, :w to apply)

-- Rebuild tree-sitter parsers after nvim-treesitter updates.
Config.autocmd('PackChanged', nil, function(ev)
  local spec, kind = ev.data.spec, ev.data.kind
  if spec.name ~= 'nvim-treesitter' or kind ~= 'update' then return end
  if not ev.data.active then vim.cmd.packadd('nvim-treesitter') end
  vim.cmd('TSUpdate')
end, 'Update tree-sitter parsers')

local gh = function(repo) return 'https://github.com/' .. repo end

vim.pack.add({
  gh('nvim-mini/mini.nvim'),
  { src = gh('catppuccin/nvim'), name = 'catppuccin' },
  { src = gh('nvim-treesitter/nvim-treesitter'), version = 'main' },
  { src = gh('nvim-treesitter/nvim-treesitter-textobjects'), version = 'main' },
  gh('neovim/nvim-lspconfig'),
  gh('stevearc/conform.nvim'),
  gh('mfussenegger/nvim-dap'),
  { src = gh('igorlfs/nvim-dap-view'), version = vim.version.range('1.*') },
  gh('mfussenegger/nvim-dap-python'),
  gh('fei6409/log-highlight.nvim'),
  gh('rafamadriz/friendly-snippets'),
}, { confirm = false })
```

- [ ] **Step 8: Create `lua/config/keymaps.lua`**

```lua
-- Keys. Leader groups match MiniMax: b buffer, d debug, e explore/edit,
-- f find, g git, l language, m map, o other, s session, t terminal, v visits.
-- Press <Space> and wait: mini.clue lists what comes next.

local nmap = function(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { desc = desc }) end
local nmap_leader = function(suffix, rhs, desc) vim.keymap.set('n', '<Leader>' .. suffix, rhs, { desc = desc }) end
local xmap_leader = function(suffix, rhs, desc) vim.keymap.set('x', '<Leader>' .. suffix, rhs, { desc = desc }) end

nmap('[p', '<Cmd>exe "iput! " . v:register<CR>', 'Paste Above')
nmap(']p', '<Cmd>exe "iput "  . v:register<CR>', 'Paste Below')

Config.leader_group_clues = {
  { mode = 'n', keys = '<Leader>b', desc = '+Buffer' },
  { mode = 'n', keys = '<Leader>d', desc = '+Debug' },
  { mode = 'n', keys = '<Leader>e', desc = '+Explore/Edit' },
  { mode = 'n', keys = '<Leader>f', desc = '+Find' },
  { mode = 'n', keys = '<Leader>g', desc = '+Git' },
  { mode = 'n', keys = '<Leader>l', desc = '+Language' },
  { mode = 'n', keys = '<Leader>m', desc = '+Map' },
  { mode = 'n', keys = '<Leader>o', desc = '+Other' },
  { mode = 'n', keys = '<Leader>s', desc = '+Session' },
  { mode = 'n', keys = '<Leader>t', desc = '+Terminal' },
  { mode = 'n', keys = '<Leader>v', desc = '+Visits' },
  { mode = 'x', keys = '<Leader>g', desc = '+Git' },
  { mode = 'x', keys = '<Leader>l', desc = '+Language' },
}

-- b: buffers
local new_scratch_buffer = function() vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true)) end
nmap_leader('ba', '<Cmd>b#<CR>', 'Alternate')
nmap_leader('bd', '<Cmd>lua MiniBufremove.delete()<CR>', 'Delete')
nmap_leader('bD', '<Cmd>lua MiniBufremove.delete(0, true)<CR>', 'Delete!')
nmap_leader('bs', new_scratch_buffer, 'Scratch')
nmap_leader('bw', '<Cmd>lua MiniBufremove.wipeout()<CR>', 'Wipeout')
nmap_leader('bW', '<Cmd>lua MiniBufremove.wipeout(0, true)<CR>', 'Wipeout!')

-- e: explore / edit config
local edit_config = function(file)
  return ('<Cmd>edit %s/lua/config/%s<CR>'):format(vim.fn.stdpath('config'), file)
end
local explore_at_file = '<Cmd>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<CR>'
local explore_quickfix = function() vim.cmd(vim.fn.getqflist({ winid = true }).winid ~= 0 and 'cclose' or 'copen') end
local explore_locations = function() vim.cmd(vim.fn.getloclist(0, { winid = true }).winid ~= 0 and 'lclose' or 'lopen') end
nmap_leader('ed', '<Cmd>lua MiniFiles.open()<CR>', 'Directory')
nmap_leader('ef', explore_at_file, 'File directory')
nmap_leader('ei', ('<Cmd>edit %s/init.lua<CR>'):format(vim.fn.stdpath('config')), 'init.lua')
nmap_leader('ek', edit_config('keymaps.lua'), 'Keymaps config')
nmap_leader('em', edit_config('mini.lua'), 'MINI config')
nmap_leader('ep', edit_config('plugins.lua'), 'Plugins config')
nmap_leader('eo', edit_config('options.lua'), 'Options config')
nmap_leader('el', edit_config('lsp.lua'), 'LSP config')
nmap_leader('eF', edit_config('format.lua'), 'Format config')
nmap_leader('en', '<Cmd>lua MiniNotify.show_history()<CR>', 'Notifications')
nmap_leader('eq', explore_quickfix, 'Quickfix list')
nmap_leader('eQ', explore_locations, 'Location list')

-- f: find
local pick_added_hunks_buf = '<Cmd>Pick git_hunks path="%" scope="staged"<CR>'
local pick_workspace_symbols_live = '<Cmd>Pick lsp scope="workspace_symbol_live"<CR>'
nmap_leader('f/', '<Cmd>Pick history scope="/"<CR>', '"/" history')
nmap_leader('f:', '<Cmd>Pick history scope=":"<CR>', '":" history')
nmap_leader('fa', '<Cmd>Pick git_hunks scope="staged"<CR>', 'Added hunks (all)')
nmap_leader('fA', pick_added_hunks_buf, 'Added hunks (buf)')
nmap_leader('fb', '<Cmd>Pick buffers<CR>', 'Buffers')
nmap_leader('fc', '<Cmd>Pick git_commits<CR>', 'Commits (all)')
nmap_leader('fC', '<Cmd>Pick git_commits path="%"<CR>', 'Commits (buf)')
nmap_leader('fd', '<Cmd>Pick diagnostic scope="all"<CR>', 'Diagnostic workspace')
nmap_leader('fD', '<Cmd>Pick diagnostic scope="current"<CR>', 'Diagnostic buffer')
nmap_leader('ff', '<Cmd>Pick files<CR>', 'Files')
nmap_leader('fg', '<Cmd>Pick grep_live<CR>', 'Grep live')
nmap_leader('fG', '<Cmd>Pick grep pattern="<cword>"<CR>', 'Grep current word')
nmap_leader('fh', '<Cmd>Pick help<CR>', 'Help tags')
nmap_leader('fH', '<Cmd>Pick hl_groups<CR>', 'Highlight groups')
nmap_leader('fl', '<Cmd>Pick buf_lines scope="all"<CR>', 'Lines (all)')
nmap_leader('fL', '<Cmd>Pick buf_lines scope="current"<CR>', 'Lines (buf)')
nmap_leader('fm', '<Cmd>Pick git_hunks<CR>', 'Modified hunks (all)')
nmap_leader('fM', '<Cmd>Pick git_hunks path="%"<CR>', 'Modified hunks (buf)')
nmap_leader('fr', '<Cmd>Pick resume<CR>', 'Resume')
nmap_leader('fR', '<Cmd>Pick lsp scope="references"<CR>', 'References (LSP)')
nmap_leader('fs', pick_workspace_symbols_live, 'Symbols workspace (live)')
nmap_leader('fS', '<Cmd>Pick lsp scope="document_symbol"<CR>', 'Symbols document')
nmap_leader('fv', '<Cmd>Pick visit_paths cwd=""<CR>', 'Visit paths (all)')
nmap_leader('fV', '<Cmd>Pick visit_paths<CR>', 'Visit paths (cwd)')

-- g: git
local git_log_cmd = [[Git log --pretty=format:\%h\ \%as\ │\ \%s --topo-order]]
local git_log_buf_cmd = git_log_cmd .. ' --follow -- %'
nmap_leader('ga', '<Cmd>Git diff --cached<CR>', 'Added diff')
nmap_leader('gA', '<Cmd>Git diff --cached -- %<CR>', 'Added diff buffer')
nmap_leader('gc', '<Cmd>Git commit<CR>', 'Commit')
nmap_leader('gC', '<Cmd>Git commit --amend<CR>', 'Commit amend')
nmap_leader('gd', '<Cmd>Git diff<CR>', 'Diff')
nmap_leader('gD', '<Cmd>Git diff -- %<CR>', 'Diff buffer')
nmap_leader('gl', '<Cmd>' .. git_log_cmd .. '<CR>', 'Log')
nmap_leader('gL', '<Cmd>' .. git_log_buf_cmd .. '<CR>', 'Log buffer')
nmap_leader('go', '<Cmd>lua MiniDiff.toggle_overlay()<CR>', 'Toggle overlay')
nmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>', 'Show at cursor')
xmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>', 'Show at selection')

-- l: language
nmap_leader('la', '<Cmd>lua vim.lsp.buf.code_action()<CR>', 'Actions')
nmap_leader('ld', '<Cmd>lua vim.diagnostic.open_float()<CR>', 'Diagnostic popup')
nmap_leader('lf', '<Cmd>lua require("conform").format()<CR>', 'Format')
nmap_leader('li', '<Cmd>lua vim.lsp.buf.implementation()<CR>', 'Implementation')
nmap_leader('lh', '<Cmd>lua vim.lsp.buf.hover()<CR>', 'Hover')
nmap_leader('ll', '<Cmd>lua vim.lsp.codelens.run()<CR>', 'Lens')
nmap_leader('lr', '<Cmd>lua vim.lsp.buf.rename()<CR>', 'Rename')
nmap_leader('lR', '<Cmd>lua vim.lsp.buf.references()<CR>', 'References')
nmap_leader('ls', '<Cmd>lua vim.lsp.buf.definition()<CR>', 'Source definition')
nmap_leader('lt', '<Cmd>lua vim.lsp.buf.type_definition()<CR>', 'Type definition')
xmap_leader('lf', '<Cmd>lua require("conform").format()<CR>', 'Format selection')

-- m: map
nmap_leader('mf', '<Cmd>lua MiniMap.toggle_focus()<CR>', 'Focus (toggle)')
nmap_leader('mr', '<Cmd>lua MiniMap.refresh()<CR>', 'Refresh')
nmap_leader('ms', '<Cmd>lua MiniMap.toggle_side()<CR>', 'Side (toggle)')
nmap_leader('mt', '<Cmd>lua MiniMap.toggle()<CR>', 'Toggle')

-- o: other
nmap_leader('or', '<Cmd>lua MiniMisc.resize_window()<CR>', 'Resize to default width')
nmap_leader('ot', '<Cmd>lua MiniTrailspace.trim()<CR>', 'Trim trailspace')
nmap_leader('oz', '<Cmd>lua MiniMisc.zoom()<CR>', 'Zoom toggle')

-- s: sessions
local session_new = 'vim.ui.input({ prompt = "Session name: " }, MiniSessions.write)'
nmap_leader('sd', '<Cmd>lua MiniSessions.select("delete")<CR>', 'Delete')
nmap_leader('sn', '<Cmd>lua ' .. session_new .. '<CR>', 'New')
nmap_leader('sr', '<Cmd>lua MiniSessions.select("read")<CR>', 'Read')
nmap_leader('sR', '<Cmd>lua MiniSessions.restart()<CR>', 'Restart')
nmap_leader('sw', '<Cmd>lua MiniSessions.write()<CR>', 'Write current')

-- t: terminal
nmap_leader('tT', '<Cmd>horizontal term<CR>', 'Terminal (horizontal)')
nmap_leader('tt', '<Cmd>vertical term<CR>', 'Terminal (vertical)')

-- v: visits
local make_pick_core = function(cwd, desc)
  return function()
    local sort_latest = MiniVisits.gen_sort.default({ recency_weight = 1 })
    local local_opts = { cwd = cwd, filter = 'core', sort = sort_latest }
    MiniExtra.pickers.visit_paths(local_opts, { source = { name = desc } })
  end
end
nmap_leader('vc', make_pick_core('', 'Core visits (all)'), 'Core visits (all)')
nmap_leader('vC', make_pick_core(nil, 'Core visits (cwd)'), 'Core visits (cwd)')
nmap_leader('vv', '<Cmd>lua MiniVisits.add_label("core")<CR>', 'Add "core" label')
nmap_leader('vV', '<Cmd>lua MiniVisits.remove_label("core")<CR>', 'Remove "core" label')
nmap_leader('vl', '<Cmd>lua MiniVisits.add_label()<CR>', 'Add label')
nmap_leader('vL', '<Cmd>lua MiniVisits.remove_label()<CR>', 'Remove label')
```

- [ ] **Step 9: Create `lua/config/mini.lua`**

```lua
-- Theme and mini.nvim modules. See :h mini.nvim and each :h mini.<module>.

require('catppuccin').setup({
  flavour = 'mocha',
  integrations = { mini = { enabled = true }, native_lsp = { enabled = true }, dap = true },
})
vim.cmd.colorscheme('catppuccin-mocha')

require('mini.basics').setup({ options = { basic = false }, mappings = { windows = true, move_with_alt = true } })

local ext3_blocklist = { scm = true, txt = true, yml = true }
local ext4_blocklist = { json = true, yaml = true }
require('mini.icons').setup({
  use_file_extension = function(ext) return not (ext3_blocklist[ext:sub(-3)] or ext4_blocklist[ext:sub(-4)]) end,
})
MiniIcons.mock_nvim_web_devicons()
MiniIcons.tweak_lsp_kind()

require('mini.notify').setup()
require('mini.sessions').setup()
require('mini.starter').setup()
require('mini.statusline').setup()
require('mini.tabline').setup()
require('mini.input').setup()
require('mini.extra').setup()

-- Completion: LSP through omnifunc, set on attach.
require('mini.completion').setup({
  lsp_completion = {
    source_func = 'omnifunc',
    auto_setup = false,
    process_items = function(items, base)
      return MiniCompletion.default_process_items(items, base, { kind_priority = { Text = -1, Snippet = 99 } })
    end,
  },
})
Config.autocmd('LspAttach', nil, function(ev)
  vim.bo[ev.buf].omnifunc = 'v:lua.MiniCompletion.completefunc_lsp'
end, "Set 'omnifunc'")
vim.lsp.config('*', { capabilities = MiniCompletion.get_lsp_capabilities() })

require('mini.files').setup({ windows = { preview = true } })
Config.autocmd('User', 'MiniFilesExplorerOpen', function()
  MiniFiles.set_bookmark('c', vim.fn.stdpath('config'), { desc = 'Config' })
  MiniFiles.set_bookmark('p', vim.fn.stdpath('data') .. '/site/pack/core/opt', { desc = 'Plugins' })
  MiniFiles.set_bookmark('w', vim.fn.getcwd, { desc = 'Working directory' })
end, 'Add bookmarks')

require('mini.misc').setup()
MiniMisc.setup_auto_root()
MiniMisc.setup_restore_cursor()
MiniMisc.setup_termbg_sync()

local ai = require('mini.ai')
ai.setup({
  custom_textobjects = {
    B = MiniExtra.gen_ai_spec.buffer(),
    F = ai.gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' }),
    C = ai.gen_spec.treesitter({ a = '@class.outer', i = '@class.inner' }),
  },
  search_method = 'cover',
})

require('mini.bracketed').setup()
require('mini.bufremove').setup()
require('mini.diff').setup()
require('mini.git').setup()
require('mini.indentscope').setup()
require('mini.jump').setup()
require('mini.jump2d').setup()
require('mini.move').setup()
require('mini.pairs').setup({ modes = { command = true } })
require('mini.pick').setup()
require('mini.splitjoin').setup()
require('mini.surround').setup()
require('mini.trailspace').setup()
require('mini.visits').setup()
require('mini.cursorword').setup()

local hipatterns = require('mini.hipatterns')
local hi_words = MiniExtra.gen_highlighter.words
hipatterns.setup({
  highlighters = {
    fixme = hi_words({ 'FIXME', 'Fixme', 'fixme' }, 'MiniHipatternsFixme'),
    hack = hi_words({ 'HACK', 'Hack', 'hack' }, 'MiniHipatternsHack'),
    todo = hi_words({ 'TODO', 'Todo', 'todo' }, 'MiniHipatternsTodo'),
    note = hi_words({ 'NOTE', 'Note', 'note' }, 'MiniHipatternsNote'),
    hex_color = hipatterns.gen_highlighter.hex_color(),
  },
})

require('mini.keymap').setup()
MiniKeymap.map_multistep('i', '<Tab>', { 'pmenu_next' })
MiniKeymap.map_multistep('i', '<S-Tab>', { 'pmenu_prev' })
MiniKeymap.map_multistep('i', '<CR>', { 'pmenu_accept', 'minipairs_cr' })
MiniKeymap.map_multistep('i', '<BS>', { 'minipairs_bs' })

local map = require('mini.map')
map.setup({
  symbols = { encode = map.gen_encode_symbols.dot('4x2') },
  integrations = { map.gen_integration.builtin_search(), map.gen_integration.diff(), map.gen_integration.diagnostic() },
})

local snippets = require('mini.snippets')
snippets.setup({
  snippets = {
    snippets.gen_loader.from_file(vim.fn.stdpath('config') .. '/snippets/global.json'),
    snippets.gen_loader.from_lang(),
  },
})

local miniclue = require('mini.clue')
miniclue.setup({
  clues = {
    Config.leader_group_clues,
    miniclue.gen_clues.builtin_completion(),
    miniclue.gen_clues.g(),
    miniclue.gen_clues.marks(),
    miniclue.gen_clues.registers(),
    miniclue.gen_clues.square_brackets(),
    miniclue.gen_clues.windows({ submode_resize = true }),
    miniclue.gen_clues.z(),
  },
  triggers = {
    { mode = { 'n', 'x' }, keys = '<Leader>' },
    { mode = 'n', keys = '\\' },
    { mode = { 'n', 'x' }, keys = '[' },
    { mode = { 'n', 'x' }, keys = ']' },
    { mode = 'i', keys = '<C-x>' },
    { mode = { 'n', 'x' }, keys = 'g' },
    { mode = { 'n', 'x' }, keys = "'" },
    { mode = { 'n', 'x' }, keys = '`' },
    { mode = { 'n', 'x' }, keys = '"' },
    { mode = { 'i', 'c' }, keys = '<C-r>' },
    { mode = 'n', keys = '<C-w>' },
    { mode = { 'n', 'x' }, keys = 's' },
    { mode = { 'n', 'x' }, keys = 'z' },
  },
})
```

- [ ] **Step 10: Create `snippets/global.json` and `.stylua.toml`**

`snippets/global.json`:
```json
{
  "Date": { "prefix": "date", "body": "${CURRENT_YEAR}-${CURRENT_MONTH}-${CURRENT_DATE}", "description": "Today's date" }
}
```
`.stylua.toml`:
```toml
column_width = 120
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferSingle"
```

- [ ] **Step 11: Run the check**

Run (PowerShell, in `linked/nvim`): `nvim --headless "+luafile scripts/check.lua"; "exit $LASTEXITCODE"`
The first run installs plugins (network); if it times out on first install, run it again.
Expected: `5 passed, 0 failed`, exit 0.

- [ ] **Step 12: Commit**

```bash
git add -A linked/nvim
git commit -m "nvim: rewrite on mini.nvim + vim.pack with Catppuccin (skeleton, keys, check script)"
```
Include `linked/nvim/nvim-pack-lock.json` (written by vim.pack on first run).

---

### Task 3: Filetypes, tree-sitter and logs

**Files:**
- Create: `linked/nvim/lua/config/filetypes.lua`, `lua/config/treesitter.lua`
- Create fixtures: `scripts/fixtures/files/{main.cpp,main.py,main.ts,script.ps1,data.json,settings.jsonc,tsconfig.json,data.yaml,data.toml,data.xml,View.xaml,data.ini,app.log,app.log.1}`
- Test: `scripts/check.lua`

**Interfaces:**
- Produces: `require('config.filetypes').bigfile_bytes` (number, 2 MB); `vim.b[buf].bigfile` (true for big files); `require('config.filetypes').log_interval_ms` (1000); `require('config.treesitter').languages` (list), `require('config.treesitter').install_missing(timeout_ms)`.

- [ ] **Step 1: Create the fixtures**

Each fixture a few lines of valid content, e.g. `main.cpp`: `#include <cstdio>\nint main() { std::puts("hi"); return 0; }`; `main.py`: `def main():\n    print("hi")\n`; `main.ts`: `const greet = (name: string): string => \`hi ${name}\`;\nconsole.log(greet("x"));`; `script.ps1`: `param([string]$Name = 'x')\nWrite-Output "hi $Name"`; `data.json`: `{"a": 1}`; `settings.jsonc` and `tsconfig.json`: `{\n  // comment\n  "a": 1\n}`; `data.yaml`: `a: 1`; `data.toml`: `a = 1`; `data.xml`: `<root><a>1</a></root>`; `View.xaml`: `<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"><Grid/></Window>`; `data.ini`: `[s]\na=1`; `app.log` and `app.log.1`: `2026-10-04 12:00:00 INFO started\n2026-10-04 12:00:01 ERROR failed`.

- [ ] **Step 2: Add failing tests to `check.lua`** (above `-- @@ tests end @@`)

```lua
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
```

- [ ] **Step 3: Run the check, watch these fail**

Run: `nvim --headless "+luafile scripts/check.lua"`
Expected: the new tests FAIL (tsconfig is `json`, `config.treesitter` missing, no reload).

- [ ] **Step 4: Create `lua/config/filetypes.lua`**

```lua
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
```

- [ ] **Step 5: Create `lua/config/treesitter.lua`**

```lua
-- Tree-sitter: parsers (built locally by the tree-sitter CLI and a C
-- compiler), highlighting, folds and indent. Missing parsers fall back to
-- regex syntax. Text objects (af/if, aC/iC) are in mini.lua via mini.ai.
local M = {}

M.languages = {
  'c', 'cpp', 'cmake', 'rust', 'ron', 'python', 'javascript', 'typescript', 'tsx',
  'powershell', 'json', 'yaml', 'toml', 'ini', 'xml', 'lua', 'luadoc', 'vim', 'vimdoc',
  'query', 'markdown', 'markdown_inline', 'bash', 'diff', 'gitcommit', 'regex',
}

vim.treesitter.language.register('json', 'jsonc')

local function installed(lang)
  return #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) > 0
end

-- Installs missing parsers; waits up to timeout_ms when given (the check script).
function M.install_missing(timeout_ms)
  local missing = vim.tbl_filter(function(lang) return not installed(lang) end, M.languages)
  if #missing == 0 or vim.fn.executable('tree-sitter') == 0 then return end
  local task = require('nvim-treesitter').install(missing)
  if timeout_ms then task:wait(timeout_ms) end
end

M.install_missing()

Config.autocmd('FileType', nil, function(ev)
  if vim.b[ev.buf].bigfile then return end
  local lang = vim.treesitter.language.get_lang(ev.match)
  if not lang or not pcall(vim.treesitter.start, ev.buf, lang) then return end
  for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
    vim.wo[win][0].foldmethod = 'expr'
    vim.wo[win][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
  end
  vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
end, 'Start tree-sitter')

return M
```

- [ ] **Step 6: Make the check wait for parser builds**

In `check.lua`, directly after the helpers block (before `-- Startup`), add:
```lua
pcall(function() require('config.treesitter').install_missing(10 * 60 * 1000) end)
```

- [ ] **Step 7: Run the check**

Run: `nvim --headless "+luafile scripts/check.lua"`
Expected: all pass. The first run builds ~26 parsers (several minutes). If parser builds fail, run `:checkhealth nvim-treesitter` in Neovim and check `tree-sitter --version` (≥ 0.26.1) and that a C compiler is found (clang from LLVM, or MSVC via Visual Studio).

- [ ] **Step 8: Commit**

```bash
git add linked/nvim
git commit -m "nvim: filetypes, tree-sitter, big files, live log files"
```

---

### Task 4: Language servers

**Files:**
- Create: `linked/nvim/lua/config/tools.lua`, `lua/config/lsp.lua`
- Create: `linked/nvim/after/lsp/{clangd,rust_analyzer,basedpyright,ruff,yamlls,lemminx,powershell_es,lua_ls}.lua`
- Create fixtures: `scripts/fixtures/rust/Cargo.toml`, `scripts/fixtures/rust/src/main.rs`, `scripts/fixtures/files/package.json`
- Test: `scripts/check.lua`

**Interfaces:**
- Produces: `require('config.tools')` with fields `share`, `lemminx`, `pses` (bundle dir), `pses_start` (Start-EditorServices.ps1), `js_debug` (dapDebugServer.js), and `available(exe_or_path) -> boolean`.
- Produces: `require('config.lsp').servers` (list of `{ name, exe, install }`), `.partition(servers, available) -> enabled_names, missing_entries`, `.enabled` (names enabled this session), `.missing_message(missing) -> string|nil`.

- [ ] **Step 1: Create the fixtures**

`scripts/fixtures/rust/Cargo.toml`:
```toml
[package]
name = "fixture"
version = "0.1.0"
edition = "2021"
```
`scripts/fixtures/rust/src/main.rs`: `fn main() {\n    println!("hi");\n}`
`scripts/fixtures/files/package.json`: `{ "name": "fixture", "private": true }`

- [ ] **Step 2: Add failing tests to `check.lua`**

```lua
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
```

- [ ] **Step 3: Run the check, watch these fail**

Expected: FAIL (`config.lsp` missing, no clients attach).

- [ ] **Step 4: Create `lua/config/tools.lua`**

```lua
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
```

- [ ] **Step 5: Create `lua/config/lsp.lua`**

```lua
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

local missing
M.enabled, missing = M.partition(M.servers, tools.available)
vim.lsp.enable(M.enabled)

local message = M.missing_message(missing)
if message then vim.schedule(function() vim.notify(message, vim.log.levels.WARN) end) end

return M
```

- [ ] **Step 6: Create the `after/lsp/` overrides**

`after/lsp/clangd.lua`:
```lua
return {
  cmd = { 'clangd', '--clang-tidy', '--background-index', '--header-insertion=never', '--completion-style=detailed' },
}
```
`after/lsp/rust_analyzer.lua`:
```lua
return { settings = { ['rust-analyzer'] = { check = { command = 'clippy' } } } }
```
`after/lsp/basedpyright.lua`:
```lua
return {
  settings = {
    basedpyright = { disableOrganizeImports = true, analysis = { typeCheckingMode = 'standard' } },
  },
}
```
`after/lsp/ruff.lua`:
```lua
-- ruff lints and formats; basedpyright owns hover.
return {
  on_attach = function(client) client.server_capabilities.hoverProvider = false end,
}
```
`after/lsp/yamlls.lua`:
```lua
return {
  settings = {
    yaml = { schemaStore = { enable = true, url = 'https://www.schemastore.org/api/json/catalog.json' }, format = { enable = true } },
  },
}
```
`after/lsp/lemminx.lua`:
```lua
return { cmd = { require('config.tools').lemminx }, filetypes = { 'xml', 'xsd', 'xsl', 'xslt', 'svg' } }
```
`after/lsp/powershell_es.lua`:
```lua
return {
  bundle_path = require('config.tools').pses,
  settings = { powershell = { codeFormatting = { Preset = 'OTBS' } } },
}
```
`after/lsp/lua_ls.lua`:
```lua
-- Neovim Lua: LuaJIT, Neovim's runtime and the plugins as libraries, so `vim`
-- and plugin modules are known.
local library = { vim.env.VIMRUNTIME, '${3rd}/luv/library' }
for _, dir in ipairs(vim.fn.globpath(vim.fn.stdpath('data') .. '/site/pack/core/opt', '*', false, true)) do
  table.insert(library, dir)
end
return {
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT', path = { 'lua/?.lua', 'lua/?/init.lua' } },
      workspace = { checkThirdParty = false, library = library },
      telemetry = { enable = false },
    },
  },
}
```

- [ ] **Step 7: Run the check**

Expected: all pass. If one server fails to attach: run `nvim files/<fixture>` interactively and `:checkhealth vim.lsp`; for `powershell_es` check `~/.local/share/nvim-data/... ` log via `:lua =vim.lsp.log.get_filename()`.

- [ ] **Step 8: Commit**

```bash
git add linked/nvim
git commit -m "nvim: language servers for C/C++, Rust, Python, JS/TS, PowerShell, config formats, Lua"
```

---

### Task 5: Formatting

**Files:**
- Create: `linked/nvim/lua/config/format.lua`
- Modify: `linked/nvim/lua/config/keymaps.lua` (add `lx`, `lF` under `-- l: language`)
- Test: `scripts/check.lua`

**Interfaces:**
- Produces: `require('config.format')` with `.project_formatter(buf) -> name|nil, reason` (`'clang_format' | 'ruff' | 'biome' | 'prettier'`), `.should_format_on_save(buf) -> boolean, reason`, `.toggle()`, `.info()`; `vim.g.format_on_save_disabled`.

- [ ] **Step 1: Add failing tests to `check.lua`**

```lua
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
```

- [ ] **Step 2: Run the check, watch these fail**

Expected: FAIL (`config.format` missing).

- [ ] **Step 3: Create `lua/config/format.lua`**

```lua
-- Formatting with conform.nvim. On save only when the project has its own
-- formatter config (found by searching up from the file); rustfmt always;
-- config formats, PowerShell and Lua never. <Space>lf formats anything.
local conform = require('conform')
local M = {}

local configs = {
  clang_format = { '.clang-format', '_clang-format' },
  ruff = { 'ruff.toml', '.ruff.toml' },
  biome = { 'biome.json', 'biome.jsonc' },
  prettier = {
    '.prettierrc', '.prettierrc.json', '.prettierrc.yaml', '.prettierrc.yml', '.prettierrc.json5',
    '.prettierrc.js', '.prettierrc.cjs', '.prettierrc.mjs', '.prettierrc.toml',
    'prettier.config.js', 'prettier.config.cjs', 'prettier.config.mjs',
  },
}

local function find_up(buf, names)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == '' then return nil end
  return vim.fs.find(names, { upward = true, path = vim.fs.dirname(name), limit = 1 })[1]
end

local function has_tool_ruff(pyproject)
  for _, line in ipairs(vim.fn.readfile(pyproject)) do
    if line:match('^%s*%[tool%.ruff') then return true end
  end
  return false
end

local by_ft = {
  c = 'clang_format', cpp = 'clang_format', python = 'python',
  javascript = 'js', typescript = 'js', javascriptreact = 'js', typescriptreact = 'js',
}

-- The project's formatter for this buffer, or nil; second value says why.
function M.project_formatter(buf)
  local kind = by_ft[vim.bo[buf].filetype]
  if kind == 'clang_format' then
    local found = find_up(buf, configs.clang_format)
    return found and 'clang_format' or nil, found or 'no .clang-format'
  elseif kind == 'python' then
    local found = find_up(buf, configs.ruff)
    if found then return 'ruff', found end
    local pyproject = find_up(buf, { 'pyproject.toml' })
    if pyproject and has_tool_ruff(pyproject) then return 'ruff', pyproject end
    return nil, 'no ruff.toml or [tool.ruff]'
  elseif kind == 'js' then
    local biome = find_up(buf, configs.biome)
    if biome then return 'biome', biome end
    local prettier = find_up(buf, configs.prettier)
    if prettier then return 'prettier', prettier end
    return nil, 'no biome or prettier config'
  end
  return nil, 'no project formatter for ' .. vim.bo[buf].filetype
end

function M.should_format_on_save(buf)
  if vim.g.format_on_save_disabled then return false, 'turned off (<Space>lx)' end
  if vim.bo[buf].filetype == 'rust' then return true, 'rustfmt always' end
  local name, why = M.project_formatter(buf)
  return name ~= nil, why
end

local function js(buf)
  local name = M.project_formatter(buf)
  return name and { name } or {}
end
local function prettier_if_configured(buf)
  return find_up(buf, configs.prettier) and { 'prettier' } or {}
end

conform.setup({
  formatters_by_ft = {
    c = { 'clang_format' }, cpp = { 'clang_format' },
    rust = { 'rustfmt' },
    python = { 'ruff_organize_imports', 'ruff_format' },
    javascript = js, typescript = js, javascriptreact = js, typescriptreact = js,
    json = prettier_if_configured, jsonc = prettier_if_configured, yaml = prettier_if_configured,
    toml = { 'taplo' },
    lua = { 'stylua' },
  },
  -- No dedicated formatter (or none configured): use the language server's.
  default_format_opts = { lsp_format = 'fallback' },
  format_on_save = function(buf)
    if M.should_format_on_save(buf) then return { timeout_ms = 3000, lsp_format = 'never' } end
  end,
})

function M.toggle()
  vim.g.format_on_save_disabled = not vim.g.format_on_save_disabled
  vim.notify('Format on save ' .. (vim.g.format_on_save_disabled and 'off' or 'on') .. ' for this session')
end

function M.info()
  local buf = vim.api.nvim_get_current_buf()
  local formatters, lsp = conform.list_formatters_to_run(buf)
  local names = vim.tbl_map(function(f) return f.name end, formatters)
  if #names == 0 and lsp then names = { 'language server' } end
  local on_save, why = M.should_format_on_save(buf)
  vim.notify(('Formatter: %s\nOn save: %s (%s)'):format(
    #names > 0 and table.concat(names, ', ') or 'none', on_save and 'yes' or 'no', why))
end

return M
```

- [ ] **Step 4: Add the keys**

In `lua/config/keymaps.lua`, after `xmap_leader('lf', …)`, add:
```lua
nmap_leader('lx', function() require('config.format').toggle() end, 'Format on save (toggle)')
nmap_leader('lF', function() require('config.format').info() end, 'Formatter info')
```

- [ ] **Step 5: Run the check**

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add linked/nvim
git commit -m "nvim: formatting with conform; on save only with a project config"
```

---

### Task 6: Debugging

**Files:**
- Create: `linked/nvim/lua/config/dap.lua`
- Modify: `linked/nvim/lua/config/keymaps.lua` (add the `d` group and F-keys)
- Test: `scripts/check.lua`

**Interfaces:**
- Consumes: `require('config.tools').js_debug`, `.pses`, `.pses_start`, `.available`.
- Produces: `dap.adapters.lldb`, `dap.adapters['pwa-node']`, `dap.adapters.powershell`, `dap.adapters.python` (from nvim-dap-python); configurations for `c cpp rust python javascript typescript ps1`.

- [ ] **Step 1: Add failing tests to `check.lua`**

```lua
-- Debugging ===================================================================

test('debug adapters are registered and their programs exist', function()
  local dap = require('dap')
  local tools = require('config.tools')
  ok(dap.adapters.lldb and tools.available(dap.adapters.lldb.command), 'lldb-dap')
  local node = dap.adapters['pwa-node']
  ok(node and tools.available(node.executable.command) and tools.available(node.executable.args[1]), 'js-debug')
  ok(dap.adapters.powershell and tools.available(tools.pses_start), 'PowerShell Editor Services')
  ok(dap.adapters.python and tools.available('uv'), 'debugpy via uv')
end)

test('every language has a debug configuration', function()
  for _, ft in ipairs({ 'c', 'cpp', 'rust', 'python', 'javascript', 'typescript', 'ps1' }) do
    ok(#(require('dap').configurations[ft] or {}) > 0, 'no configuration for ' .. ft)
  end
end)

test('debug keys exist', function()
  for _, lhs in ipairs({ ' db', ' dB', ' dc', ' di', ' do', ' dO', ' dr', ' dt', ' dv', ' de', '<F5>', '<F10>', '<F11>', '<S-F11>' }) do
    ok(vim.fn.maparg(lhs, 'n') ~= '', 'missing ' .. lhs)
  end
end)
```

- [ ] **Step 2: Run the check, watch these fail**

Expected: FAIL (no adapters).

- [ ] **Step 3: Create `lua/config/dap.lua`**

```lua
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
  "-LogPath '" .. log_dir .. "/pses-dap.log'",
  "-SessionDetailsPath '" .. log_dir .. "/pses-dap-session.json'",
  '-FeatureFlags @() -AdditionalModules @()',
  '-HostName nvim -HostProfileId 0 -HostVersion 1.0.0',
  '-Stdio -DebugServiceOnly -LogLevel Normal',
}, ' ')
dap.adapters.powershell = {
  type = 'executable', command = 'pwsh',
  args = { '-NoLogo', '-NoProfile', '-NonInteractive', '-Command', pses_cmd },
}
dap.configurations.ps1 = {
  { name = 'Run script', type = 'powershell', request = 'launch', script = '${file}', cwd = '${workspaceFolder}' },
}
```

- [ ] **Step 4: Add the keys**

In `lua/config/keymaps.lua`, after the `-- b: buffers` block, add:
```lua
-- d: debug (plus the Visual Studio F-keys)
local dap = function(fn) return function(...) return require('dap')[fn](...) end end
nmap_leader('db', dap('toggle_breakpoint'), 'Breakpoint')
nmap_leader('dB', function() require('dap').set_breakpoint(vim.fn.input('Condition: ')) end, 'Conditional breakpoint')
nmap_leader('dc', dap('continue'), 'Start / continue')
nmap_leader('di', dap('step_into'), 'Step into')
nmap_leader('do', dap('step_over'), 'Step over')
nmap_leader('dO', dap('step_out'), 'Step out')
nmap_leader('dr', dap('run_to_cursor'), 'Run to cursor')
nmap_leader('dt', dap('terminate'), 'Stop')
nmap_leader('dv', '<Cmd>DapViewToggle<CR>', 'Debugger view')
nmap_leader('de', function() require('dap.ui.widgets').hover() end, 'Evaluate under cursor')
nmap('<F5>', dap('continue'), 'Debug: continue')
nmap('<F10>', dap('step_over'), 'Debug: step over')
nmap('<F11>', dap('step_into'), 'Debug: step into')
nmap('<S-F11>', dap('step_out'), 'Debug: step out')
```

- [ ] **Step 5: Run the check**

Expected: all pass.

- [ ] **Step 6: Hands-on debug check (with the user)**

In each case: open the file, `<Space>db` on a line inside, `F5`, confirm it stops there, `F10` steps, `<Space>de` shows a value, `<Space>dt` stops.
1. C++: in a temp folder, `clang++ -g -O0 main.cpp -o main.exe` (fixture `files/main.cpp`), launch `main.exe`.
2. Rust: `cargo build` in `scripts/fixtures/rust`, launch `target/debug/fixture.exe`.
3. Python: `files/main.py` (add `main()` call), configuration "Launch file".
4. TypeScript: `files/main.ts`, "Launch file".
5. PowerShell: `files/script.ps1`, "Run script".
If lldb-dap fails to start (Review Focus 1), note the error and ask the user whether to switch C/C++/Rust to CodeLLDB.

- [ ] **Step 7: Commit**

```bash
git add linked/nvim
git commit -m "nvim: debugging for C/C++, Rust, Python, JS/TS and PowerShell"
```

---

### Task 7: Finish

**Files:**
- Create: `linked/nvim/README.md`
- Modify: `CLAUDE.md` (dotfiles), the Neovim memory note

- [ ] **Step 1: Write `linked/nvim/README.md`**

A short guide: what the config is; file layout (copy the spec's Layout block); how to run the check (`nvim --headless "+luafile scripts/check.lua"` from this folder, in PowerShell); how to update plugins (`:lua vim.pack.update()`, then commit `nvim-pack-lock.json`); the formatting rule; where tools come from (`packages.yaml`, `.chezmoiexternal.toml.tmpl`); key groups table; the `nvim-minimax` tag to get the old config back (`git show nvim-minimax:linked/nvim/init.lua`).

- [ ] **Step 2: Add a Neovim section to the dotfiles `CLAUDE.md`**

```markdown
## Neovim (`linked/nvim`)

mini.nvim on vim.pack. Test with `nvim --headless "+luafile scripts/check.lua"`
from `linked/nvim` (PowerShell). Add a test to `scripts/check.lua` for any
change. Language tools come from packages.yaml / .chezmoiexternal, never mason.
Commit `nvim-pack-lock.json` after plugin updates.
```

- [ ] **Step 3: Run the full check one last time**

Expected: all tests pass, exit 0. Also start Neovim normally once: no error messages, Catppuccin colors, `<Space>` shows the groups.

- [ ] **Step 4: Commit and push**

```bash
git add linked/nvim/README.md CLAUDE.md linked/nvim/nvim-pack-lock.json
git commit -m "nvim: README; CLAUDE.md notes"
git push origin main
git push origin nvim-minimax
```

- [ ] **Step 5: Update memory**

Mark the Neovim note complete (or delete it and record only lasting facts, e.g. lldb-dap's status on Windows).
