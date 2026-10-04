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

local severity = vim.diagnostic.severity
vim.diagnostic.config({
  signs = { priority = 9999, severity = { min = severity.WARN, max = severity.ERROR } },
  underline = { severity = { min = severity.HINT, max = severity.ERROR } },
  virtual_lines = false,
  virtual_text = { current_line = true, severity = { min = severity.ERROR, max = severity.ERROR } },
  update_in_insert = false,
  severity_sort = true,
})
