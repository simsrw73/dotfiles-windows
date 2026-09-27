# chezmoi migration for dotfiles-windows — design

Date: 2026-09-27
Repo: `simsrw73/dotfiles-windows` (private). `simsrw73/w11dwm-config` is out of scope.

## Goal

Rebuild this machine (or set up a new one) from a fresh Windows install with a
bootstrap script plus one `chezmoi apply`, restoring:

- all config `~/.config` tracks today
- the PowerShell profile (currently the separate `powershell-profile` repo)
- home dotfiles and `~/.ssh`
- secrets, from Bitwarden
- apps (scoop, winget, PowerShell modules)
- the links/junctions and one-time system setup the apps need

Success: `chezmoi verify` is clean on this machine, and a Windows Sandbox run
of `bootstrap.ps1` reaches a working config without manual file copying.

## Current state (2026-09-27)

- `~/.config` is itself the git working tree of `dotfiles-windows`; a
  `.gitignore` allowlist decides what's tracked (~40 tool dirs; `claude/` is
  whitelisted file by file). `AutoHotKey/Lib/KeyChord` is a submodule.
- `%APPDATA%\FlowLauncher` and `OneDrive\Documents\AutoHotkey` are manual
  junctions into `~/.config`. Zed junctions are documented in
  `Setup.Config.Junctions.txt` but manual.
- `$PROFILE` resolves to `OneDrive\Documents\PowerShell\…` (OneDrive Known
  Folder Move); that folder is the `powershell-profile` repo and also holds
  installed modules.
- chezmoi v2.72.2 is installed (winget); `~/.config/chezmoi/chezmoi.toml` has
  name/email/signingkey data but no source dir exists.
- Developer Mode is on (symlinks work unelevated).
- Chocolatey has no packages besides itself.
- Secrets: `~/.env`, 5 SSH private keys, GPG signing key `8FDC1EB03BECE139` (the one git uses) in
  `gnupg/`, a GitHub token in FlowLauncher's "Github Quick Launcher"
  settings, `gh/hosts.yml`.

## Decisions

| Topic | Decision |
|---|---|
| Repo | Restructure `dotfiles-windows` in place, keeping history (`git mv`). |
| Source dir | `~/.local/share/chezmoi` (chezmoi default, matches XDG layout). |
| Secrets | Bitwarden for everything that can't be regenerated. |
| Packages | Curated lists + `run_onchange_` install script. |
| PowerShell profile | Code in `~/.config/powershell/`; `$PROFILE` is a stub. |
| Edit flow | Symlinks for app-written / constantly-edited dirs; copies elsewhere. |
| Ignored | `~/.password`, the PowerShell SecretStore vault, `CreateSecrets.ps1`. |
| Chocolatey | Dropped. |

## 1. Repo layout

```
dotfiles-windows/                  cloned to ~/.local/share/chezmoi
├── .chezmoiroot                   contains "home"
├── bootstrap.ps1                  fresh-machine entry point
├── README.md                      workflow + reinstall runbook
├── scripts/seed-bitwarden.ps1     one-time: create vault items from this machine
├── packages/
│   ├── scoop.yaml                 buckets + apps
│   ├── winget.yaml                winget IDs (+ elevated flag)
│   └── pwsh-modules.yaml          PowerShell modules
├── linked/                      dirs that ~/.config symlinks into (outside chezmoi's
│   ├── AutoHotKey/                source state, so chezmoi never manages them as files)
│   │   └── Lib/KeyChord           stays a git submodule
│   └── FlowLauncher/, yasb/, komorebi/, wpm/, claude/, psmux/, yazi/, nvim/
├── docs/
└── home/                          chezmoi source state → ~
    ├── .chezmoi.toml.tmpl
    ├── .chezmoiignore
    ├── .chezmoidata/links.yaml    junction table
    ├── .chezmoiscripts/
    ├── dot_config/…               everything ~/.config tracks today
    │   └── powershell/            profile code from powershell-profile
    ├── dot_gitconfig, dot_bashrc, dot_bash_profile
    ├── dot_env.tmpl
    ├── private_dot_ssh/
    └── OneDrive/Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl   (stub)
```

The stub's target path is computed from the Documents known folder in
`.chezmoi.toml.tmpl` (OneDrive or local), so it lands wherever `$PROFILE`
resolves on that machine. The stub only dot-sources
`~/.config/powershell/profile.ps1`.

`.chezmoi.toml.tmpl` carries forward the existing data (name, email,
signingkey — corrected to `8FDC1EB03BECE139`; the current `41736183F04CA31D`
is stale), `[cd] command = "pwsh"`, `[git] autoAdd = true`, and adds
`[bitwarden] unlock = "auto"` plus any per-machine prompts
(`promptStringOnce`) for values that differ between machines.

`packages/*.yaml` are loaded into template data by the install script's
template (`include` + `fromYaml`), so they live outside `home/` and stay
readable.

## 2. Secrets

Bitwarden folder `dotfiles`:

| Item | Content | Consumer |
|---|---|---|
| `ssh-keys` | attachments: `id_ed25519`, `id_a24`, `private_key`, `routeros_rsa` | `private_dot_ssh/private_<name>.tmpl` → `bitwardenAttachment` |
| `gpg-signing-key` | attachments: armored secret key `8FDC1EB03BECE139` + ownertrust export | `run_onchange_after_30-gpg-import.ps1.tmpl` → `gpg --import`, `gpg --import-ownertrust` |
| `env` | one custom field per `~/.env` variable | `dot_env.tmpl` → `bitwardenFields` |
| `flow-github` | GitHub Quick Launcher token | `run_onchange_after_15-flow-github-token.ps1.tmpl` (see §3) |

Not stored (re-login instead): `gh` auth, Claude/Copilot credentials, Docker.

`.pub` files and `~/.ssh/config` are plain files. `gnupg/` is not managed.

Guards:
- `.chezmoiignore` and `.gitignore` keep today's exclusions (`gnupg`,
  `docker`, `github-copilot`, `gh/hosts.yml`, Claude credentials, runtime
  noise).
- Pre-commit hook in the source repo runs `gitleaks protect --staged`.

`scripts/seed-bitwarden.ps1` creates the items from this machine's files
using `bw`. The user runs it while unlocked; secret values never pass
through the assistant.

## 3. Links and packages

Directory symlinks via chezmoi `symlink_<name>.tmpl` entries in
`home/dot_config/`, each containing
`{{ .chezmoi.workingTree }}/linked/<name>`:

`AutoHotKey`, `FlowLauncher`, `yasb`, `komorebi`, `wpm`, `claude`, `psmux`,
`yazi`, `nvim`.

The linked dirs live in `linked/`, outside `.chezmoiroot`, so chezmoi only
manages the symlink itself; their ignore rules live in the repo `.gitignore`.
KeyChord stays a git submodule at `linked/AutoHotKey/Lib/KeyChord`
(`chezmoi init` clones submodules by default).

A template can't live inside a linked dir, so the FlowLauncher token is
handled by `run_onchange_after_15-flow-github-token.ps1.tmpl`: it writes
`linked/FlowLauncher/Settings/Plugins/Github Quick Launcher/Settings.json`
from Bitwarden. That path stays git-ignored.

Junctions from `run_onchange_after_10-links.ps1.tmpl`, driven by
`.chezmoidata/links.yaml`. The script is idempotent and moves any real
directory in the way to `<path>.pre-chezmoi-<date>`:

| Path | Target |
|---|---|
| `%APPDATA%\FlowLauncher` | `~/.config/FlowLauncher` |
| `<Documents>\AutoHotkey` | `~/.config/AutoHotKey` |
| `%APPDATA%\Zed` | `~/.config/zed` |
| `%LOCALAPPDATA%\Zed` | `~/.local/share/zed` |

All other `~/.config` content is copied (`dot_config/<tool>/…`), with
`.tmpl` only where per-machine values or secrets are needed.

Packages: `run_onchange_before_20-packages.ps1.tmpl` embeds a hash of
`packages/*.yaml` so it reruns only on change. It adds scoop buckets,
installs missing scoop apps, installs missing winget IDs (`--id … -e`,
elevated ones via one `gsudo` block), and installs missing PowerShell
modules (`Install-PSResource`). It never uninstalls. The lists are drafted
from the current `scoop list` / `winget list` and pruned by the user.

One-time setup: `run_once_after_40-wpmd-task.ps1` calls the existing
`wpm/install-wpmd-task.ps1`. Other one-time steps found during migration
follow the same `run_once_after_NN-*.ps1` pattern.

## 4. Bootstrap

`bootstrap.ps1` (runnable via `irm … | iex` or from a clone):

1. Install scoop if missing (to `$env:SCOOP` = `~/.local/share/scoop`).
2. `scoop install git chezmoi bitwarden-cli gsudo`.
3. `bw login` if not logged in.
4. `chezmoi init --apply simsrw73/dotfiles-windows`.

Private repo access: bootstrap uses `gh auth login` (installed via scoop)
before `chezmoi init` so the HTTPS clone works.

## 5. Migration of this machine

Each phase is committed separately on the `chezmoi` branch (worktree
`~/projects/dotfiles-chezmoi`). Nothing is deleted before `chezmoi diff` is
clean.

1. Backup: `git bundle` of `~/.config` and `powershell-profile` repos, plus a
   copy of `~/.ssh`, into `~/dotfiles-backup-2026-09-27/`.
2. Restructure: `git mv` linked dirs into `linked/` (submodule path updated
   in `.gitmodules`) and all other tracked paths into `home/dot_config/`;
   add chezmoi files; import profile code
   (no `Modules/`); add stub, home dotfiles, `.ssh`.
3. Seed Bitwarden (user runs `seed-bitwarden.ps1`); check each secret
   template with `chezmoi execute-template`.
4. Dry run: `chezmoi diff --source ~/projects/dotfiles-chezmoi`. Expected
   differences: link conversions and the stub only. Every other difference
   is reviewed.
5. Cutover: move `~/.config/.git` into the backup; clone to
   `~/.local/share/chezmoi`; `chezmoi apply`; merge `chezmoi` → `main`;
   push. After user confirmation: archive `powershell-profile` on GitHub,
   delete `~/projects/dotfiles-windows` and the worktree.
6. Update README (workflow, add-an-app, add-a-secret, reinstall runbook,
   pre-wipe checklist) and the Claude memory entry for the repo layout.

## 6. Verification

- This machine: `chezmoi verify` exits 0; after a reboot komorebi, yasb, wpm,
  AHK, FlowLauncher and the pwsh profile load; `git commit -S` signs.
- Fresh machine: `bootstrap.ps1` in Windows Sandbox reaches Bitwarden unlock,
  config, links and packages. wpmd task and OneDrive paths are checked
  manually per the runbook.
- Pre-wipe checklist in README: everything pushed, Bitwarden items present,
  offline copy of the backup dir.

## Out of scope

`w11dwm-config` (and its `sync.ps1`, which will need its `-Source` updated
later), registry/Windows settings, browser profiles.
