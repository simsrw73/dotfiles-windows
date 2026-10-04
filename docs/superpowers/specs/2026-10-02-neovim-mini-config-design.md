# Neovim config: mini.nvim, vim.pack, Catppuccin

## Goal

Replace the MiniMax starter in `linked/nvim` with a smaller config written for
the user's languages: C/C++, Rust, Python, JavaScript/TypeScript, PowerShell,
Lua (the config itself), the common config formats (TOML, JSON, JSONC, YAML,
INI, XML, XAML) and log files. It uses mini.nvim for nearly everything,
Neovim 0.12's built-in plugin manager (`vim.pack`), and Catppuccin Mocha.

## Decisions (agreed with the user)

- Rewrite, but keep MiniMax's Space-leader key groups so muscle memory carries.
- Language tools come from the dotfiles package list (`packages.yaml`, plus
  `.chezmoiexternal` for tools with no package); no mason.nvim.
- C/C++ builds with clang (LLVM). clang finds Visual Studio's libraries and
  linker on its own.
- In-editor debugging for all six languages.
- Format on save only when the project has its own formatter config.
- Approach: mini.nvim plus a few single-purpose plugins.

## Layout

```
init.lua              leader keys, then requires lua/config/* in order
nvim-pack-lock.json   exact plugin revisions (committed)
lua/config/
  options.lua         editor settings
  plugins.lua         every vim.pack.add in one place
  mini.lua            mini.nvim modules
  treesitter.lua      parsers, highlighting, folds, text objects
  lsp.lua             server enabling, shared keys, diagnostics
  format.lua          conform.nvim and the project-config rule
  lint.lua            nvim-lint
  dap.lua             adapters, configurations, UI
  filetypes.lua       filetype detection (xaml, jsonc, logs)
  keymaps.lua         leader groups
lsp/<server>.lua      per-server overrides (read by Neovim itself)
after/ftplugin/       per-language settings
scripts/check.lua     headless self-check (nvim --headless -l)
```

## Plugins

- mini.nvim: basics, icons, notify, statusline, tabline, clue, pick, extra,
  files, git, diff, visits, sessions, starter, map, misc, bufremove,
  completion, snippets, ai, surround, pairs, move, splitjoin, bracketed, jump,
  jump2d, hipatterns, indentscope, trailspace, cursorword.
- catppuccin/nvim (mocha, mini integration).
- nvim-treesitter (main branch) and nvim-treesitter-textobjects.
- nvim-lspconfig, for server defaults only; `vim.lsp.enable` starts servers.
- conform.nvim (formatting), nvim-lint (linting).
- nvim-dap, nvim-dap-view, nvim-dap-python.
- log-highlight.nvim.

Updates: `vim.pack.update()` previews changes; the lock file records them.

## Languages

| Language | Server | Formatter | Linter | Debugger |
|---|---|---|---|---|
| C / C++ | clangd | clang-format | clang-tidy (via clangd) | lldb-dap |
| Rust | rust-analyzer (clippy check) | rustfmt | clippy | lldb-dap |
| Python | basedpyright, ruff server | ruff | ruff | debugpy (nvim-dap-python, `uv`) |
| JS / TS | vtsls, eslint | prettier or biome (project's) | eslint | js-debug |
| PowerShell | PowerShell Editor Services | PSES | PSScriptAnalyzer | PSES |
| JSON / JSONC | jsonls | prettier, else jsonls | | |
| YAML | yaml-language-server (SchemaStore on) | prettier, else yamlls | | |
| TOML | taplo | taplo | | |
| XML / XAML | lemminx | lemminx | | |
| INI, logs | highlighting only | | | |
| Lua | lua-language-server | stylua | | |

lua-language-server is configured for Neovim: LuaJIT runtime, `$VIMRUNTIME`
and the config in its library, so `vim` and the Neovim API are known symbols.
Neovim's built-in LuaJIT runs scripts (`nvim -l`); no standalone Lua is
installed.

## Formatting rule

- C/C++, Python, JS/TS: format on save only when the project has a formatter
  config (`.clang-format`; `ruff.toml`, `.ruff.toml` or `[tool.ruff]` in
  `pyproject.toml`; a prettier config or `biome.json`), found by searching up
  from the file.
- Rust: rustfmt always on save.
- JSON, YAML, TOML, XML, PowerShell, Lua: never on save.
- `Space lf` formats any file or selection by hand. `Space lx` toggles
  format-on-save for the session; `Space lF` shows which formatter would run
  and why.

## Logs

- `*.log`, `*.out` and similar get the `log` filetype and log-highlight
  colors (timestamps, levels, IPs, GUIDs).
- Log buffers reload when the file changes (`autoread` plus a `checktime`
  timer), so `G` follows the tail.
- Files over 2 MB skip tree-sitter and language servers.

## Keys

All MiniMax leader groups and keys are kept: `b` buffer, `e` explore/edit,
`f` find, `g` git, `l` language, `m` map, `o` other, `s` session,
`t` terminal, `v` visits; plus `gc` comment, `[`/`]` jumps and `\` toggles.

Changed: `e` group's config-edit keys point at the new files (`ei` init.lua,
`ek` keymaps, `em` mini, `ep` plugins, `el` lsp, `eF` format).

New `d` Debug group: `db`/`dB` breakpoint/conditional, `dc` continue, `di`
`do` `dO` step into/over/out, `dr` run to cursor, `dt` stop, `dv` view,
`de` evaluate. Also `F5` `F10` `F11` `Shift+F11`.

New in `l`: `lx` format-on-save toggle, `lF` formatter info.

## Tools (dotfiles)

- scoop: `llvm` (clang, clangd, clang-format, clang-tidy, lldb-dap),
  `tree-sitter`, `ruff`, `taplo`, `lua-language-server`, `stylua`.
- npm: `@vtsls/language-server`, `vscode-langservers-extracted`,
  `yaml-language-server`, `prettier`.
- uv tool: `basedpyright`.
- `.chezmoiexternal`: PowerShell Editor Services, lemminx and js-debug from
  their GitHub releases, under `~/.local/share/`.
- rust-analyzer, rustfmt and clippy come from rustup (already installed).

## Missing tools

Servers are enabled only when their executable exists; a missing one gives
one startup notice naming the install command. Missing formatters and linters
are skipped. Parsers that cannot build fall back to regex highlighting. The
config is usable before any tool is installed.

## Rollout

1. Add the tools to `packages.yaml` and `.chezmoiexternal`; run
   `chezmoi apply` (asks the user first: it installs software).
2. Tag the current commit `nvim-minimax`, then replace `linked/nvim`.
3. First launch installs plugins and builds parsers; commit the lock file.

## Testing

`scripts/check.lua`, run with `nvim --headless -l scripts/check.lua`:

- the config loads without errors;
- for a sample file per language (C++, Rust, Python, TS, PowerShell, JSON,
  JSONC, YAML, TOML, XML, XAML, INI, log): filetype, parser and attached
  server are as expected;
- the formatter chosen with and without a project config matches the rule,
  and saving in a project without config leaves the file unchanged;
- each debug adapter is registered and its executable exists.

Debugging is finished by hand: set a breakpoint and step through a small
C++, Rust, Python, TypeScript and PowerShell program.
