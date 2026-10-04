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
