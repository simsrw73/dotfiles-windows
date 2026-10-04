-- Tree-sitter: parsers (built locally by the tree-sitter CLI and a C
-- compiler), highlighting, folds and indent. Missing parsers fall back to
-- regex syntax (gitcommit too: its grammar takes ~3 minutes to compile, past
-- nvim-treesitter's build limit). Text objects (aF/iF, aC/iC) are in mini.lua via mini.ai.
local M = {}

M.languages = {
  'c', 'cpp', 'cmake', 'rust', 'ron', 'python', 'javascript', 'typescript', 'tsx',
  'powershell', 'json', 'yaml', 'toml', 'ini', 'xml', 'lua', 'luadoc', 'vim', 'vimdoc',
  'query', 'markdown', 'markdown_inline', 'bash', 'diff', 'regex',
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
