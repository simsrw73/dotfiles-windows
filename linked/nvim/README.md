# Neovim config

mini.nvim on Neovim 0.12's built-in plugin manager (`vim.pack`), Catppuccin
Mocha. Set up for C/C++, Rust, Python, JavaScript/TypeScript, PowerShell, Lua,
config formats (JSON/JSONC, YAML, TOML, INI, XML/XAML) and log files.

Design: `docs/superpowers/specs/2026-10-02-neovim-mini-config-design.md` in the
dotfiles repo. The MiniMax starter this replaced is tagged `nvim-minimax`
(`git show nvim-minimax:linked/nvim/init.lua`).

## Layout

```
init.lua              leader key, then lua/config/* in order (each in pcall)
nvim-pack-lock.json   exact plugin revisions (commit after updates)
lua/config/
  options.lua         editor settings
  plugins.lua         every vim.pack.add
  filetypes.lua       detection, indent widths, big files, live log files
  keymaps.lua         leader groups
  mini.lua            Catppuccin and mini.nvim modules
  treesitter.lua      parsers, highlighting, folds, indent
  tools.lua           where language tools live
  lsp.lua             which servers start; stopping them on exit
  format.lua          conform.nvim and the format-on-save rule
  dap.lua             debug adapters and configurations
after/lsp/<server>.lua  per-server settings over nvim-lspconfig's
scripts/check.lua     headless test suite; fixtures in scripts/fixtures/
```

## Check

From this folder, in PowerShell:

```powershell
nvim --headless "+luafile scripts/check.lua"; $LASTEXITCODE
```

It loads the config, checks filetypes, parsers, that every language server
attaches, the formatting rules, and runs a real debug session per language.
Add a test for any change.

## Updating

- Plugins: `:lua vim.pack.update()`, review, `:w`; then commit
  `nvim-pack-lock.json`.
- Language tools come from the dotfiles: `home/.chezmoidata/packages.yaml`
  (scoop, npm, uv, rustup components) and `home/.chezmoiexternal.toml.tmpl`
  (PowerShell Editor Services, lemminx, js-debug). Missing servers are listed
  once at startup with the command that installs them.

## Formatting

On save only when the project has its own formatter config (`.clang-format`,
`ruff.toml` or `[tool.ruff]`, a prettier config or `biome.json`), searched for
upward from the file. Rust always (rustfmt). JSON, YAML, TOML, XML, PowerShell
and Lua never on save. `<Space>lf` formats anything, `<Space>lx` turns
format-on-save off for the session, `<Space>lF` says what would run and why.

## Keys

Press `<Space>` and wait: mini.clue shows the groups.

| Group | | Group | |
|---|---|---|---|
| `b` | buffers | `l` | language (LSP, format) |
| `d` | debug | `m` | mini.map |
| `e` | explore / edit config | `o` | other |
| `f` | find (pickers) | `s` | sessions |
| `g` | git | `t` | terminal |
| | | `v` | visits |

Debugging also has the Visual Studio keys: `F5` continue, `F10` over, `F11`
into, `Shift+F11` out.

## Windows notes

- npm language servers run through their `.cmd` launcher; from Git Bash,
  Neovim would otherwise pick npm's shell script and the server never starts.
- PowerShell Editor Services ignores the LSP exit request, so `lsp.lua` stops
  (and if needed kills) servers when Neovim exits.
- lldb-dap embeds Python 3.14; `dap.lua` points it at the installed Python so
  it doesn't load another program's `python314.dll`.
- `gitcommit` uses regex highlighting: its tree-sitter grammar takes about
  three minutes to compile, past nvim-treesitter's build limit.
