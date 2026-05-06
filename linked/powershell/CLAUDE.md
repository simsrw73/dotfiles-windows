# PowerShell Profile

Personal PowerShell 7+ profile for Windows 11. The profile is split across a main entry point and dot-sourced module files.

## Structure

```
Documents/PowerShell/
├── profile.ps1              # Main entry point — sourced by $PROFILE
└── ProfileModules/
    ├── Env.ps1              # Profile-wide env vars (XDG dirs, PATH, PAGER, EDITOR)
    ├── Aliases.ps1          # Non-tool aliases (printenv, touch, rmrf, ssh-copy-id)
    ├── Functions.ps1        # Non-tool utilities (isAdmin, Update-AllModules, Show-*, cd...)
    ├── Completers.ps1       # Microsoft.WinGet.CommandNotFound import (guarded)
    ├── PSReadline.ps1       # PSReadLine options and key handlers
    ├── cli_tools_config.ps1 # Per-tool config: XDG paths, aliases, completers, fzf pickers
    └── Show-HelpColor.ps1   # Show-HelpColor function + shc alias
```

`profile.ps1` has two code paths:
- **VS Code fast-path** (top of file): detected via `$Env:TERM_PROGRAM -eq 'vscode'`. Imports
  only PSReadLine+PSFzf, dot-sources all ProfileModules files, returns early — skips VS Dev
  Shell, transcript, diagnostics, and weekly module updates.
- **Full init** (remainder of file): standard terminals get the complete startup sequence.

## cli_tools_config.ps1

The central file for all CLI tool configuration. Organized by tool — each tool has one
`#region`/`#endregion` block containing its XDG paths, functions, aliases, argument completers,
and fzf picker functions. ~1050 lines, 50 tool sections.

**Dot-source order:**
```
Env.ps1 → Aliases.ps1 → Functions.ps1 → Completers.ps1 → PSReadline.ps1 → cli_tools_config.ps1 → Show-HelpColor.ps1
```
PSReadline.ps1 must precede cli_tools_config.ps1 so PSReadLine removes its default Ctrl+T/R
bindings before PSFzf reclaims them.

**Section template:**
```powershell
#region toolname  -  description
if (Get-Command toolname.exe -ErrorAction Ignore) {
    # --- XDG / Config paths ---
    $Env:TOOL_CONFIG = Join-Path $Env:XDG_CONFIG_HOME 'tool'
    # --- Functions / Aliases ---
    function global:Verb-Noun { ... }
    Set-Alias -Name shortcut -Value Verb-Noun -Scope Global
    # --- Completers ---
    toolname completion powershell | Out-String | Invoke-Expression
    # --- Fzf Pickers ---
    function global:Select-Something { ... | fzf ... }
    Set-Alias -Name fxx -Value Select-Something -Scope Global
}
#endregion toolname
```

**Guard rules:**
- CLI tools: `Get-Command toolname -ErrorAction Ignore` — use `Ignore` (not `SilentlyContinue`)
  to prevent entries appearing in `$Error` when optional tools are absent
- PS modules: `if (Get-Module -Name ModName)` — checks if **loaded**, not just installed;
  `Set-PsFzfOption` and similar cmdlets require the module to be imported

## Key Tools & Modules

| Tool           | Purpose                  | Config location                                       |
| -------------- | ------------------------ | ----------------------------------------------------- |
| oh-my-posh     | Prompt theme             | `~/.config/oh-my-posh/catpow.omp.yaml`; skipped in VS Code terminal |
| PSReadLine     | Input experience         | `PSReadline.ps1`                                      |
| PSFzf          | Fuzzy finder integration | `cli_tools_config.ps1` #region PSFzf                  |
| eza            | Modern ls replacement    | `cli_tools_config.ps1` #region eza; ls/ll/la/tree aliases |
| bat            | Modern cat replacement   | `cli_tools_config.ps1` #region bat; cat alias         |
| zoxide         | Smart cd                 | `cli_tools_config.ps1` #region zoxide; cd alias       |
| fzf            | Fuzzy finder             | `cli_tools_config.ps1` #region fzf; Catppuccin Mocha  |
| posh-git       | Git prompt info          | `cli_tools_config.ps1` #region posh-git               |
| Terminal-Icons | File icons in terminal   | `cli_tools_config.ps1` #region Terminal-Icons (⚠ v0.11.0 has a bug — pin to 0.9.0) |
| scoop          | Package manager          | `cli_tools_config.ps1` #region scoop; sstat/supd      |
| winget         | Package manager          | `cli_tools_config.ps1` #region winget; wstat/wupd     |
| gsudo          | Elevation                | `cli_tools_config.ps1` #region gsudo                  |
| chezmoi        | Dotfile manager          | `cli_tools_config.ps1` #region chezmoi; cz alias      |
| moor/bat/less  | Pager                    | `Env.ps1` pager detection; $PAGER set accordingly     |

## Fzf Picker Functions (22 total)

All defined in `cli_tools_config.ps1` alongside their tool's section. Pattern: `Select-Verb-Noun`
PowerShell name + short alias.

| Alias | Function | Tool | Purpose |
|---|---|---|---|
| `ff` | `Select-File` | eza+bat | Browse files with bat preview |
| `fcd` | `Select-Directory` | zoxide | Fuzzy cd from zoxide history |
| `fco` | `Select-GitBranch` | posh-git | Fuzzy branch checkout |
| `flog` | `Select-GitLog` | posh-git | Browse commit log with diff |
| `fga` | `Select-GitFile` | git | Stage files interactively |
| `fstash` | `Select-GitStash` | git | Fuzzy stash apply/drop |
| `fkill` | `Select-Process` | procs | Fuzzy kill process |
| `sins` | `Select-ScoopPackage` | sfsu/scoop | Search + install package |
| `srm` | `Remove-ScoopPackage` | scoop | Pick installed → uninstall |
| `wins` | `Select-WingetPackage` | winget | Search + install package |
| `wrm` | `Remove-WingetPackage` | winget | Pick installed → uninstall |
| `frg` | `Select-RipgrepResult` | rg+fzf | Interactive code search |
| `ffd` | `Select-FdResult` | fd+fzf | Interactive file find |
| `fjq` | `Select-JsonPath` | jq+fzf | Interactive JSON filter |
| `fkill` | `Select-Process` | procs | Fuzzy process kill |
| `fgl` | `Read-MarkdownFile` | glow | Pick + render markdown |
| `fbw` | `Select-BwItem` | bitwarden | Fuzzy vault lookup |
| `czf` | `Edit-DotFile` | chezmoi | Pick managed file to edit |
| `fpot` | `Select-PoshTheme` | oh-my-posh | Preview + apply theme |
| `fnv` | `Select-NodeVersion` | nvm | Fuzzy switch Node version |
| `fns` | `Select-NpmScript` | npm | Run npm script from picker |
| `frtc` | `Select-RustupToolchain` | rustup | Fuzzy toolchain switch |
| `fvenv` | `Select-UvVenv` | uv | Pick + activate Python venv |

## Theme

Everything uses **Catppuccin Mocha** consistently:

- PSReadLine syntax colors: set in `PSReadline.ps1`
- FZF: `$FZF_DEFAULT_OPTS` color string in `cli_tools_config.ps1` #region fzf
- oh-my-posh: `catpow.omp.yaml` (custom theme)
- bat: `~/.config/bat/bat.conf`

## Environment Layout (XDG)

```
~/.config/     → $Env:XDG_CONFIG_HOME   (bat, ripgrep, glow, wget, curl, nano, chezmoi, gnupg, oh-my-posh, glazewm, komorebi)
~/.local/share → $Env:XDG_DATA_HOME    (rustup, cargo, python, zoxide, nvm, node, uv)
~/.local/state → $Env:XDG_STATE_HOME   (less history)
~/.cache/      → $Env:XDG_CACHE_HOME   (python pycache, uv cache)
~/scripts/     → added to $PATH
```

XDG env vars for each tool are set inside that tool's `#region` in `cli_tools_config.ps1`,
not in `Env.ps1` (Env.ps1 only sets the four base XDG dirs and PATH additions that must
be available before cli_tools_config.ps1 loads).

## Startup Behavior

**VS Code terminal (fast-path):**
1. Detects `$Env:TERM_PROGRAM -eq 'vscode'`
2. Imports PSReadLine + PSFzf
3. Dot-sources all ProfileModules (including cli_tools_config.ps1)
4. Returns — skips everything below

**Standard terminal (full init):**
1. Detects terminal type, sets `$Env:TERM_PROGRAM` and `$isVSCodeTerm`
2. Imports modules: PSReadLine, PSFzf, powershell-yaml, Microsoft.PowerShell.SecretManagement
3. Dot-sources all ProfileModules
4. Runs startup diagnostics (shell info, terminal size)
5. On Fridays: runs `Update-AllModules`
6. Enables PSFeedbackProvider experimental feature if available
7. Initializes VS Dev Shell via vswhere
8. Starts transcript (saved to `~/Documents/PowerShell.Transcripts/YYYY-MM-DD/`)

## Admin / Elevation

`$isAdmin` is set at startup via `isAdminUser` in `Functions.ps1`. `gsudo` (via gsudoModule)
provides elevation. `ssh-copy-id` alias wraps `Copy-SSHID`.

## Known TODOs

- Move PSReadLine history and transcript files to `$XDG_STATE_HOME`
- Create an install script that bootstraps the profile on a new machine (clone repo, install PS modules, install scoop tools)
- Terminal-Icons 0.11.0 generates corrupt CliXml theme files — pin to 0.9.0 as a workaround
