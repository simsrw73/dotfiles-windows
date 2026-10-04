---
name: neovim-mini-config
description: "The user's Neovim config (mini.nvim + vim.pack + Catppuccin, linked/nvim) and the Windows traps found building it"
metadata:
  node_type: memory
  type: project
  originSessionId: 0dbf713f-3e0c-44b6-9af0-30e9cd4fbb42
  modified: 2026-10-04T20:39:10.642Z
---

Built 2026-10-04 on dotfiles branch `nvim-mini` (spec `docs/superpowers/specs/2026-10-02-neovim-mini-config-design.md`, plan `docs/superpowers/plans/2026-10-04-neovim-mini-config.md`). Old MiniMax config tagged `nvim-minimax`. Test suite: `nvim --headless "+luafile scripts/check.lua"` from `linked/nvim` (48 tests incl. a real debug session per language); `linked/nvim/README.md` documents it.

Windows traps found (each has a test):
- npm tools live only in fnm's per-shell folder; `tools.ensure_node()` falls back to `~/.local/share/fnm/aliases/default`. From Git Bash, Neovim resolves npm's extensionless shell script → use `<name>.cmd`.
- PowerShell Editor Services ignores LSP exit and outlives Neovim; `lsp.lua` stops/kills servers (and pwsh children) on VimLeavePre. As a DAP adapter it must start with `detached = false`.
- lldb-dap embeds Python 3.14 and loaded YASB's python314.dll (no stdlib); prepend the installed Python 3.14 to its PATH (no PYTHONHOME — it leaks into the debuggee). nvim-dap `options.env` must be a list of "KEY=value".
- rust-analyzer on PATH was only rustup's stub; now a rustup component in packages.yaml.
- `gitcommit` tree-sitter grammar takes ~158 s to compile, past nvim-treesitter's limit; interrupted builds leave a stale lock in `%LOCALAPPDATA%\tree-sitter\lock`.
- Global git ignore has `*.log`: `git add -f` log fixtures.

**Why:** these cost hours to find; any future nvim change on Windows can hit them again.
**How to apply:** read this before changing LSP/DAP/tool resolution in linked/nvim; run the check script after every change.
