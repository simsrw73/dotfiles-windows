---
name: dotfiles-repo-layout
description: How ~/.config (dotfiles-windows repo) decides what is tracked; secrets purged 2026-09-26; AHK/FlowLauncher junctions
metadata:
  type: project
---
~/.config is the private repo simsrw73/dotfiles-windows. On 2026-09-26 the history was rewritten with git-filter-repo to remove pushed secrets (GPG private keys, claude/.credentials.json, copilot auth.db, docker token seed) and Claude transcripts. It was then force-pushed. The old history is in ~/dotfiles-backup-2026-09-26.git.

**Why:** a blanket "Backup" commit had swept up secrets and runtime junk.
**How to apply:**
- claude/ is whitelisted in .gitignore: only settings.json, hooks/, skills/ (not skills/synced), the plugin manifests and projects/*/memory/. Never `git add -f` anything else there.
- gnupg/, github-copilot/, docker/ and gh/hosts.yml are ignored on purpose.
- FlowLauncher's "Github Quick Launcher" plugin settings hold a GitHub token and are ignored.
- AutoHotKey/ and FlowLauncher/ are the real folders now. %APPDATA%\FlowLauncher and OneDrive\Documents\AutoHotkey are junctions pointing into .config. AutoHotKey/Lib/KeyChord is a submodule.
Related: [[yasb-bar-design]]
