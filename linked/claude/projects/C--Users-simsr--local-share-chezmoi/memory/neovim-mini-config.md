---
name: neovim-mini-config
description: "In-progress rewrite of the Neovim config (mini.nvim + vim.pack + Catppuccin); spec written, plan not yet"
metadata:
  node_type: memory
  type: project
  originSessionId: 0dbf713f-3e0c-44b6-9af0-30e9cd4fbb42
  modified: 2026-10-02T22:37:28.327Z
---

Replacing the MiniMax starter in `linked/nvim` (dotfiles) with a smaller mini.nvim config on Neovim 0.12's `vim.pack`, Catppuccin Mocha. Brainstorming finished 2026-10-02; all four design sections approved by the user.

- Spec: `docs/superpowers/specs/2026-10-02-neovim-mini-config-design.md` in the dotfiles repo. As of 2026-10-02 it was **staged but not committed** (GPG cache expired; user went away from the desktop for a couple of days). Commit it first, after the user unlocks GPG.
- Also uncommitted from the same day, waiting on the GPG unlock: new `CLAUDE.md` files in the dotfiles root and in `~/projects/Legend` (user asked for them; commit and push both).
- Next step: user reviews the spec, then writing-plans → implementation plan → execution method choice.
- Key decisions: rewrite but keep MiniMax's Space-leader groups; tools via `packages.yaml` + `.chezmoiexternal` (no mason); clang/LLVM for C/C++; debugging for all languages (nvim-dap + nvim-dap-view, lldb-dap, debugpy via uv, js-debug, PSES); format on save only with a project formatter config (rustfmt always; config formats, PowerShell, Lua never — last two were filled in by me, flagged to the user for review).
- Tag the current MiniMax commit `nvim-minimax` before replacing it. `chezmoi apply` to install tools needs the user's OK.

**Why:** the user wants an efficient editor for C/C++, Rust, Python, JS/TS, PowerShell, Lua, config formats and logs.
**How to apply:** resume at the spec-review gate; don't start implementation before the plan is approved. Related: [[legend-ahk-library]].
