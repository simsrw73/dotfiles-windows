# dotfiles-windows

My Windows config, managed with [chezmoi](https://chezmoi.io). One repo restores
`~/.config`, the PowerShell profile, home dotfiles, SSH/GPG keys and secrets
(from Bitwarden), apps (scoop, winget, cargo, node, python) and the
links/junctions the apps expect.

## Layout

| Path | What |
|---|---|
| `home/` | chezmoi source state (`.chezmoiroot`), maps to `~` |
| `home/dot_config/` | config copied into `~/.config` |
| `linked/` | folders `~/.config/<name>` is a junction to (edited live, so edits show up in `git status` here) |
| `home/.chezmoidata/packages.yaml` | apps to install |
| `home/.chezmoidata/links.yaml` | junctions to create |
| `home/.chezmoiscripts/` | install / setup scripts chezmoi runs |
| `lib/Dotfiles.psm1` | helpers the scripts use (tests in `tests/`, run `Invoke-Pester tests`) |
| `scripts/` | one-off tools: seed Bitwarden, draft package list, cutover, sandbox test |

The source lives at `~/.local/share/chezmoi`. `chezmoi cd` opens a shell there.

## Fresh machine

1. Get `bootstrap.ps1` (GitHub web UI, since the repo is private) and run:
   `powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1`
2. Sign in to GitHub and Bitwarden when asked; enter the Bitwarden master
   password once when chezmoi applies.
3. Sign out and back in. Then re-login to Claude Code, Copilot, Docker and OneDrive.

## Daily use

- Linked folders (`AutoHotKey`, `FlowLauncher`, `yasb`, `komorebi`, `wpm`,
  `claude`, `psmux`, `yazi`, `nvim`, `powershell`): edit in place, then
  `chezmoi cd` and `git add/commit/push`.
- Copied files: `chezmoi edit <file>`, or edit the live file and run
  `chezmoi re-add <file>`. `chezmoi diff` shows what `chezmoi apply` would change.
- Pull changes from another machine: `chezmoi update`.

## Add an app

Add it to `home/.chezmoidata/packages.yaml` (scoop, winget `user` or
`elevated`, `cargo`, `node.npm`, `python`, `pipx`, `uvtools`, `pwsh`), then
`chezmoi apply`. The installer only installs what's missing and never uninstalls.

## Add a secret

Add a field or attachment to an item in the Bitwarden `dotfiles` folder
(`ssh-keys`, `gpg-signing-key`, `env`, `flow-github`), then reference it from a
template (`bitwardenFields`, `bitwardenAttachment`). Never commit secret values;
the pre-commit hook runs gitleaks.

## Add a linked folder

Move the folder into `linked/<name>`, add a `~/.config/<name>` entry to
`home/.chezmoidata/links.yaml`, then `chezmoi apply`.

## Before wiping this machine

- [ ] `chezmoi status` is empty, and `git status` in the source is clean and pushed
- [ ] Bitwarden `dotfiles` folder has `ssh-keys`, `gpg-signing-key`, `env`, `flow-github`
- [ ] New keys or tokens since the last seed are in Bitwarden (`scripts/seed-bitwarden.ps1` updates attachments)
- [ ] `~/dotfiles-backup-*` copied to offline media
- [ ] Anything outside this repo you care about (Documents, Downloads, browser profiles) is backed up
