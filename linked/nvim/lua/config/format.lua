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
