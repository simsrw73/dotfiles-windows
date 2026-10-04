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
