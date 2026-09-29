# PowerShell Profile

Personal PowerShell 7+ profile for Windows 11. The profile is split across a main entry point and dot-sourced module files. CLI tool configuration is handled by the **DotForge** module (`~/projects/DotForge`).

## Structure

```
Documents/PowerShell/
├── profile.ps1              # Main entry point — sourced by $PROFILE
└── ProfileModules/
    ├── Env.ps1              # Profile-wide env vars (XDG dirs, PATH, PAGER, EDITOR)
    ├── Aliases.ps1          # Non-tool aliases (printenv, touch, rmrf, ssh-copy-id)
    ├── Functions.ps1        # Non-tool utilities (Test-AdminRole, Update-AllModules, Show-*, cd...)
    ├── Completers.ps1       # Microsoft.WinGet.CommandNotFound import (guarded)
    ├── PSReadline.ps1       # PSReadLine options and key handlers
    └── Show-HelpColor.ps1   # Show-HelpColor function + shc alias
```

`profile.ps1` has two code paths:

- **VS Code fast-path** (top of file): detected via `$Env:TERM_PROGRAM -eq 'vscode'`. Imports
  PSReadLine, dot-sources ProfileModules, runs `Register-DFTool -All`, returns early — skips
  VS Dev Shell, transcript, and weekly module updates.
- **Full init** (remainder of file): standard terminals get the complete startup sequence.

## DotForge

All CLI tool configuration (XDG paths, aliases, completers, fzf pickers) is handled by the
DotForge module at `~/projects/DotForge`. The profile calls:

```powershell
$DFConfig = @{
    PackageManagerOrder = @('scoop', 'winget')
    SkipTools           = @('lsd', 'oh-my-posh')  # oh-my-posh replaced by starship
}
Import-Module DotForge
Register-DFTool -All
```

DotForge reads `~/projects/DotForge/Tools/*.json` records and processes each installed tool.
Per-tool companion scripts at `Tools/<name>.ps1` handle complex initialization:

| Companion       | Purpose                                           |
| --------------- | ------------------------------------------------- |
| `PSFzf.ps1`     | Import-Module PSFzf + Set-PsFzfOption calls       |
| `posh-git.ps1`  | Import-Module posh-git + fzf pickers              |
| `Terminal-Icons.ps1` | Import-Module Terminal-Icons                 |
| `zoxide.ps1`    | zoxide init invocation + cd alias (AllScope)      |
| `starship.ps1`  | starship prompt init (cached init script)         |
| `ripgrep.ps1`   | frg interactive code search                       |
| `procs.ps1`     | fkill fuzzy process kill                          |
| `winget.ps1`    | wins/wrm install/uninstall pickers                |

**Dot-source order in profile.ps1:**

```
Env.ps1 → Aliases.ps1 → Functions.ps1 → Completers.ps1 → PSReadline.ps1
  → Import-Module DotForge → Register-DFTool -All → Show-HelpColor.ps1
```

PSReadline.ps1 must precede `Register-DFTool` so PSReadLine removes its default Ctrl+T/R
bindings before PSFzf's companion reclaims them.

## Key Tools & Modules

| Tool           | Purpose                  | Config location                                                                    |
| -------------- | ------------------------ | ---------------------------------------------------------------------------------- |
| starship       | Prompt                   | `~/.config/starship.toml` (p9cat preset, github.com/simsrw73/starship-p9cat); DotForge `starship.ps1` companion. Transient prompt ("time dir ❯") from `~/.config/starship/p9cat.transient.ps1`, dot-sourced after `Register-DFTool`. oh-my-posh stays installed but is skipped via `SkipTools` |
| PSReadLine     | Input experience         | `PSReadline.ps1`                                                                   |
| PSFzf          | Fuzzy finder integration | DotForge `Tools/PSFzf.ps1` companion                                               |
| eza            | Modern ls replacement    | DotForge `Tools/eza.json`; ls/ll/la/tree aliases                                   |
| bat            | Modern cat replacement   | DotForge `Tools/bat.json`; cat alias                                               |
| zoxide         | Smart cd                 | DotForge `Tools/zoxide.json` + `zoxide.ps1` companion; cd alias                   |
| fzf            | Fuzzy finder             | DotForge `Tools/fzf.json`; Catppuccin Mocha colors                                 |
| posh-git       | Git prompt info          | DotForge `Tools/posh-git.json` + `posh-git.ps1` companion                         |
| Terminal-Icons | File icons in terminal   | DotForge `Tools/Terminal-Icons.json` + companion (⚠ pin to v0.9.0 — v0.11.0 bug) |
| scoop          | Package manager          | DotForge `Tools/scoop.json`; sstat/supd                                            |
| winget         | Package manager          | DotForge `Tools/winget.json` + `winget.ps1` companion; wstat/wupd                  |
| gsudo          | Elevation                | DotForge `Tools/gsudo.json`                                                        |
| chezmoi        | Dotfile manager          | DotForge `Tools/chezmoi.json`; cz alias                                            |
| moor/bat/less  | Pager                    | `Env.ps1` pager detection; $PAGER set accordingly                                  |
| DockerCompletion | Docker tab completions | Inline in profile.ps1 (not in DotForge registry)                                  |
| PowerType      | AI tab completions       | Inline in profile.ps1 (not in DotForge registry)                                  |

## Fzf Picker Functions

Pickers are defined in DotForge companion scripts or declaratively in JSON records.
Pattern: `Select-Verb-Noun` PowerShell name + short alias.

| Alias    | Function                 | Source                      | Purpose                       |
| -------- | ------------------------ | --------------------------- | ----------------------------- |
| `ff`     | `Select-File`            | `eza.json` declarative      | Browse files with bat preview |
| `fcd`    | `Select-Directory`       | `zoxide.json` declarative   | Fuzzy cd from zoxide history  |
| `fco`    | `Select-GitBranch`       | `posh-git.ps1`              | Fuzzy branch checkout         |
| `flog`   | `Select-GitLog`          | `posh-git.ps1`              | Browse commit log with diff   |
| `fga`    | `Select-GitFile`         | `posh-git.ps1`              | Stage files interactively     |
| `fstash` | `Select-GitStash`        | `posh-git.ps1`              | Fuzzy stash apply/drop        |
| `fkill`  | `Select-Process`         | `procs.ps1`                 | Fuzzy kill process            |
| `sins`   | `Select-ScoopPackage`    | `scoop.json` declarative    | Search + install package      |
| `srm`    | `Remove-ScoopPackage`    | `scoop.json` declarative    | Pick installed → uninstall    |
| `wins`   | `Select-WingetPackage`   | `winget.ps1`                | Search + install package      |
| `wrm`    | `Remove-WingetPackage`   | `winget.ps1`                | Pick installed → uninstall    |
| `frg`    | `Select-RipgrepResult`   | `ripgrep.ps1`               | Interactive code search       |
| `ffd`    | `Select-FdResult`        | `fd.json` declarative       | Interactive file find         |
| `fjq`    | `Select-JsonPath`        | `jq.json` declarative       | Interactive JSON filter       |
| `fgl`    | `Read-MarkdownFile`      | `glow.json` declarative     | Pick + render markdown        |
| `fbw`    | `Select-BwItem`          | `bitwarden.json` declarative| Fuzzy vault lookup            |
| `czf`    | `Edit-DotFile`           | `chezmoi.json` declarative  | Pick managed file to edit     |
| `fnv`    | `Select-NodeVersion`     | `nvm.json` declarative      | Fuzzy switch Node version     |
| `fns`    | `Select-NpmScript`       | `npm.json` declarative      | Run npm script from picker    |
| `frtc`   | `Select-RustupToolchain` | `rustup.json` declarative   | Fuzzy toolchain switch        |
| `fvenv`  | `Select-UvVenv`          | `uv.json` declarative       | Pick + activate Python venv   |

## Theme

Everything uses **Catppuccin Mocha** consistently:

- PSReadLine syntax colors: set in `PSReadline.ps1`
- FZF: `$FZF_DEFAULT_OPTS` color string in DotForge `Tools/fzf.json`
- starship: `~/.config/starship.toml` (p9cat preset, a port of the old oh-my-posh `catpow.omp.yaml`)
- bat: `~/.config/bat/bat.conf`

## Environment Layout (XDG)

```
~/.config/     → $Env:XDG_CONFIG_HOME   (bat, ripgrep, glow, wget, curl, nano, chezmoi, gnupg, starship, oh-my-posh, glazewm, komorebi)
~/.local/share → $Env:XDG_DATA_HOME    (rustup, cargo, python, zoxide, nvm, node, uv)
~/.local/state → $Env:XDG_STATE_HOME   (ps_history, less history)
~/.cache/      → $Env:XDG_CACHE_HOME   (python pycache, uv cache, ps-completions)
~/scripts/     → added to $PATH
```

XDG env vars for each tool are set by DotForge's `Register-DFTool` processing the `xdg.vars`
field in each tool's JSON record. `Env.ps1` only sets the four base XDG dirs and PATH additions
that must be available before DotForge loads.

## Startup Behavior

**VS Code terminal (fast-path):**

1. Detects `$Env:TERM_PROGRAM -eq 'vscode'`
2. Imports PSReadLine
3. Dot-sources Env, Aliases, Functions, Completers, PSReadline modules
4. `Import-Module DotForge; Register-DFTool -All`
5. Imports DockerCompletion, PowerType (if installed)
6. Dot-sources Show-HelpColor
7. Returns — skips everything below

**Standard terminal (full init):**

1. Imports PSReadLine, powershell-yaml, Microsoft.PowerShell.SecretManagement
2. SSH agent status check (Debug level)
3. Dot-sources Env, Aliases, Functions, Completers, PSReadline modules
4. `Import-Module DotForge; Register-DFTool -All`
5. Imports DockerCompletion, PowerType (if installed)
6. Dot-sources Show-HelpColor
7. Prompt: starship, initialized during step 4 by DotForge's `starship.ps1` companion
8. On Fridays: runs `Update-AllModules`
9. Enables PSFeedbackProvider experimental feature if available
10. Initializes VS Dev Shell via vswhere
11. Starts transcript (saved to `~/Documents/PowerShell.Transcripts/YYYY-MM-DD/`)

## Admin / Elevation

`$Global:IsAdmin` is set at startup via `Test-AdminRole` in `Functions.ps1`. `gsudo` (via
gsudoModule) provides elevation. `ssh-copy-id` alias wraps `Copy-SSHID`.

## Tools

- Always use Context7 MCP for library docs without me asking
- git add/git commit at logical milestones

## Known TODOs

- Terminal-Icons 0.11.0 generates corrupt CliXml theme files — pin to 0.9.0 as a workaround
