# PowerShell Profile

Personal PowerShell 7+ profile for Windows 11. The profile is split across a main entry point and dot-sourced module files.

## Structure

```
Documents/PowerShell/
├── profile.ps1              # Main entry point — sourced by $PROFILE
└── ProfileModules/
    ├── Env.ps1              # $Env:* and $env:* variable assignments
    ├── Aliases.ps1          # Set-Alias calls
    ├── Functions.ps1        # General utility functions
    ├── Completers.ps1       # Argument completers and tab completion config
    ├── PSReadline.ps1       # PSReadLine options and key handlers
    ├── Show-HelpColor.ps1   # Show-HelpColor function + shc alias
    └── Edit-PSProfile.ps1   # Helper to open the profile in $EDITOR (not dot-sourced)
```

`profile.ps1` dot-sources all ProfileModules files at startup. The ProfileModules files are currently mostly stubs — content migration from profile.ps1 is in progress.

## Key Tools & Modules

| Tool           | Purpose                  | Config                                               |
| -------------- | ------------------------ | ---------------------------------------------------- |
| oh-my-posh     | Prompt theme             | `~/.config/oh-my-posh/catpow.omp.yaml`               |
| PSReadLine     | Input experience         | Configured in profile.ps1 + PSReadline.ps1           |
| PSFzf          | Fuzzy finder integration | fzf + fd; Ctrl+T file, Ctrl+R history                |
| eza            | Modern ls replacement    | ls/ll/la/tree aliases                                |
| bat            | Modern cat replacement   | cat alias; config at `~/.config/bat/bat.conf`        |
| zoxide         | Smart cd                 | z alias replaces cd; data at `$XDG_DATA_HOME/zoxide` |
| fzf            | Fuzzy finder             | Catppuccin Mocha theme                               |
| posh-git       | Git prompt info          | Loaded via Import-Module                             |
| Terminal-Icons | File icons in terminal   | Loaded via Import-Module                             |
| scoop          | Package manager          | sstat/supd helpers                                   |
| winget         | Package manager          | wstat/wupd helpers                                   |
| gsudo          | Elevation                | gsudoModule imported                                 |
| chezmoi        | Dotfile manager          | cz alias                                             |
| moor/bat/less  | Pager                    | Auto-detected; $PAGER set accordingly                |

## Theme

Everything uses **Catppuccin Mocha** consistently:

- PSReadLine syntax colors: `$catppuccinSyntaxTheme` hashtable in profile.ps1
- FZF: `$FZF_DEFAULT_OPTS` color string
- oh-my-posh: `catpow.omp.yaml` (custom theme)
- bat: config file

## Environment Layout (XDG)

```
~/.config/    → $Env:XDG_CONFIG_HOME   (gnupg, bat, oh-my-posh, glazewm, komorebi)
~/.local/share → $Env:XDG_DATA_HOME   (rustup, cargo, python, zoxide)
~/.local/state → $Env:XDG_STATE_HOME
~/.cache/     → $Env:XDG_CACHE_HOME   (python pycache)
~/scripts/    → added to $PATH
```

## ProfileModules Migration Conventions

When moving content out of profile.ps1 into ProfileModules:

- **Env.ps1** — All `$Env:*` assignments (XDG vars, tool paths, PAGER, EDITOR, FZF opts, etc.)
- **Aliases.ps1** — All `Set-Alias` calls (ls→eza, cat→bat, cd→z, touch, rmrf, etc.)
- **Functions.ps1** — Utility functions (Show-Environment, Show-Path, New-File, Get-PubIP, etc.)
- **Completers.ps1** — Argument Completers: Completion setup (PSFzf options, scoop-search hook, rustup completions)
- **PSReadline.ps1** — All `Set-PSReadLineOption` and `Set-PSReadLineKeyHandler` calls

Each ProfileModule file must be self-contained: use `$ErrorActionPreference = 'Stop'` and guard tool availability with `Get-Command x.exe -ErrorAction SilentlyContinue`.

## Known TODOs

- Replace direct eza/bat/moor references with a separate tool-config script (see TODO comment in profile.ps1)
- Move history, transcript, and PSReadLine history to `$XDG_STATE_HOME`
- Apply remaining XDG paths (NPM, NVM, GOPATH, etc.)
- Implement the `$isVSCodeTerm` conditional block (currently wired but empty)
- Either set up the profile to install any required modules and tools if it finds them missing, or create an install script that clones the profile, installs powershell modules, and installs desired tools

## Startup Behavior

On every shell start:

1. Detects terminal type and sets `$Env:TERM_PROGRAM`
2. Sets `$isVSCodeTerm` (true when TERM_PROGRAM is vscode)
3. Imports modules (posh-git, Terminal-Icons, PSReadLine, PSFzf, etc.)
4. Configures PSReadLine with Catppuccin colors
5. Configures fzf and zoxide
6. Launches oh-my-posh prompt
7. Starts a transcript (saved to `~/Documents/PowerShell.Transcripts/YYYY-MM-DD/`)
8. On Fridays: runs `Update-AllModules`
9. Initializes VS Dev Shell via vswhere

## Admin / Elevation

`$isAdmin` is set at startup. `gsudo` (via gsudoModule) provides elevation. `ssh-copy-id` alias wraps `Copy-SSHID`.
