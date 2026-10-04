# Dotfiles: notes for Claude

The user's Windows setup, managed with chezmoi (public repo
simsrw73/dotfiles-windows). Layout is in `README.md`: `home/` is chezmoi
source, `linked/` holds folders that `~/.config/<name>` junctions point to
(edited live). Specs and plans live in `docs/superpowers/`.

## Git in this repo

- Never pipe `git diff`/`git status` into `head`: SIGPIPE leaves a stale
  `.git/index.lock`. Write to a file, or use `git --no-optional-locks`.
  Before deleting a lock, check no git process is running here (UniGetUI and
  scoop run their own `git pull`s).
- Commits are GPG-signed and the pre-commit hook runs gitleaks. On
  `gpg: signing failed: Timeout`, ask the user to unlock (see the global
  CLAUDE.md); never bypass signing.
- `linked/claude/plugins/known_marketplaces.json` changes on its own (a
  timestamp); commit it with other work, don't chase it.
- Leave the user's uncommitted changes alone unless asked; commit only the
  files you changed.

## AutoHotkey (`linked/AutoHotKey`)

- Entry point `autohotkey.ahk`; apps in `Apps.ahk`, Win+Space launcher in
  `Chords.ahk`, window keys in `WindowManager.ahk`. Legend is the submodule
  `Lib/Legend` (source repo `~/projects/Legend`, which has its own
  CLAUDE.md).
- Run AutoHotkey from PowerShell only. Check syntax with
  `AutoHotkey64.exe /ErrorStdOut /validate autohotkey.ahk`; reload by
  starting the script again (`#SingleInstance Force`).
- Alt+/ page letters (`PageKeys` in `autohotkey.ahk`) mirror the top level of
  the Win+Space launcher; keep them in step when the launcher changes.
- Don't send keys or open menus on the user's screen without asking.

## Neovim (`linked/nvim`)

mini.nvim on vim.pack (see its README). Test with
`nvim --headless "+luafile scripts/check.lua"` from `linked/nvim`, in
PowerShell; add a test to `scripts/check.lua` for any change. Language tools
come from packages.yaml / .chezmoiexternal, never mason. Commit
`nvim-pack-lock.json` after plugin updates. Fixtures named `*.log` need
`git add -f` (the global git ignore has `*.log`).

## Public mirror

`~/projects/w11dwm.config` (simsrw73/w11dwm-config) publishes the desktop
configs. After changing AutoHotkey, komorebi, yasb, Flow Launcher or wpm
files: run its `sync.ps1` (copies an allowlist, scans for secrets), bump its
`autohotkey/Lib/Legend` submodule to the same commit, commit, push.

## Related repos

- `~/projects/DotForge`: PowerShell module the profile loads (junction
  `Documents/PowerShell/Modules/DotForge`). Has its own CLAUDE.md; tests with
  `Invoke-Pester tests/` from `pwsh -NoProfile`.
- Packages come from `home/.chezmoidata/packages.yaml` (scoop, winget, npm,
  uv tools); tools without a package go in `home/.chezmoiexternal.toml.tmpl`.
  `chezmoi apply` installs software: ask first.
