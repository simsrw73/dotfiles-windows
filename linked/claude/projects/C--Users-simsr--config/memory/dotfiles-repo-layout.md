---
name: dotfiles-repo-layout
description: "Dotfiles are chezmoi (~/.local/share/chezmoi -> simsrw73/dotfiles-windows); linked/ junctions, Bitwarden secrets, OneDrive clobber hazard"
metadata:
  node_type: memory
  type: project
  originSessionId: 3492d0e6-af52-4e25-9fa9-db0334ec0323
  modified: 2026-10-18T23:15:51.114Z
---

Since ~2026-09-27 the dotfiles live in chezmoi source `~/.local/share/chezmoi` (repo simsrw73/dotfiles-windows).
`~/.config` is no longer a git repo. `~/.config/<name>` for AutoHotKey, FlowLauncher, claude, komorebi, nvim,
powershell, psmux, wpm, yasb and yazi are junctions into `linked/<name>`, so edits there show in the source's git status.
Secrets (ssh keys, gpg key 8FDC1EB03BECE139, env, flow-github) come from Bitwarden folder `dotfiles`. `bootstrap.ps1` + README
"Fresh machine" / "Before wiping" sections are the restore runbook. Pre-commit runs gitleaks.

**Why:** the 2026-09-26 history rewrite purged pushed secrets. The pre-purge history is in ~/dotfiles-backup-2026-09-26.git (USB only).
**How to apply:**
- The claude/ whitelist in .gitignore still applies. Skills junctioned from `~/.agents/skills` (an installer store, not in any repo)
  show up as untracked: don't commit them.
- OneDrive hazard: `OneDrive\Documents\AutoHotkey` was a junction into .config. On 2026-10-18 OneDrive put older copies of the AHK
  files and the Legend submodule back in place and left the current ones as `*-cassiel.ahk` conflict copies. Before committing
  "modified" AHK/Flow files, check whether their content is just an older blob from history.
- OneDrive also held a stale June copy at `OneDrive\.config` (with gh/claude tokens) and links out to Zed, .agents skills and H:\Games.
  The user wants OneDrive kept to documents only: no junctions into it, no config or cache trees in it. Large many-file trees
  (DotForge's winget-pkgs snapshot, 600k files) made OneDrive hang. universe.db was moved to G:\cassiel-backup-2026-10-18.
- projects/dotfiles-chezmoi is an orphan worktree of the deleted ~/.config/.git; projects/dotfiles-windows is an old clone.
- `chezmoi status` needs Bitwarden unlocked (the private_dot_env.tmpl template).
Related: [[yasb-bar-design]], [[komorebi-ahk-setup]]
