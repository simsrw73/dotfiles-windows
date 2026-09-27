# Profile Final Polish — Design Spec

**Date:** 2026-05-06  
**Scope:** All 8 profile files including all 50+ tool sections in cli_tools_config.ps1  
**Approach:** Two commits — infrastructure/helpers first, then cli_tools_config.ps1  

---

## Goals

- Follow strict PowerShell best practices (approved verbs, param blocks, [CmdletBinding()])
- Extract common patterns into reusable helpers (Add-ToPath, Ensure-Dir)
- Consistent naming: local vars `$camelCase`, params `$PascalCase`, globals `$Global:PascalCase`
- Consistent fzf picker appearance: 60% right preview, uniform headers, ANSI where needed
- Fix real bugs: EAP leak from dot-sourced file, closure-captured paths
- Remove dead code; convert empty stubs to lean placeholders

---

## Commit 1: Infrastructure & Helpers

### Env.ps1

**Add `Add-ToPath` helper** (script-private, top of file, before first use):
```powershell
function script:Add-ToPath {
    param([string]$Dir, [switch]$Prepend)
    if (-not $Dir) { return }
    $normalized = [IO.Path]::GetFullPath($Dir)
    $existing = ($Env:Path -split [IO.Path]::PathSeparator) |
        Where-Object { $_ } |
        ForEach-Object { [IO.Path]::GetFullPath($_) }
    if ($normalized -notin $existing) {
        if ($Prepend) { $Env:Path = $normalized + [IO.Path]::PathSeparator + $Env:Path }
        else          { $Env:Path += [IO.Path]::PathSeparator + $normalized }
    }
}
```

- Uses `[IO.Path]::GetFullPath()` (pure string, no FS hit) to normalize `..` segments
- PowerShell's `-notin` is case-insensitive on Windows — handles case variants in PATH
- `-Prepend` switch for Python's user scripts (must shadow system Python)

**Replace 4 dedup-then-append blocks** with `Add-ToPath` calls:
```powershell
Add-ToPath (Join-Path $home 'scripts')
Add-ToPath (Join-Path $Env:CARGO_HOME 'bin')
Add-ToPath (Join-Path $env:LOCALAPPDATA 'Programs' 'Pulsar')
# Python — prepend so user scripts shadow system Python
if (Get-Command python -ErrorAction Ignore) {
    $pythonScripts = python -c "import sysconfig; print(sysconfig.get_path('scripts'))" 2>$null
    if ($pythonScripts) { Add-ToPath $pythonScripts -Prepend }
}
```

**Add XDG state dir creation** (PSReadline.ps1 currently creates this — belongs here):
```powershell
# Ensure XDG state dir exists — PSReadLine writes history here
New-Item -ItemType Directory -Force -Path $Env:XDG_STATE_HOME -ErrorAction SilentlyContinue | Out-Null
```

### Functions.ps1

**Rename `isAdminUser` → `Test-AdminRole`** (approved verb `Test-`, PascalCase):
```powershell
function global:Test-AdminRole {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
$Global:IsAdmin = Test-AdminRole
```

- `[WindowsPrincipal]::new()` instead of `New-Object` (PS 5+ style)
- `$Global:IsAdmin` (was `$global:isAdmin`) — correct casing for globals
- Update all references: `$global:isAdmin` → `$Global:IsAdmin` in Update-AllModules

**Fix `New-File`, `Remove-All`, `Copy-SSHID`** — add proper param blocks:
```powershell
function global:New-File {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)
    $null | Out-File -FilePath $Name -Encoding utf8
}

function global:Remove-All {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Path)
    Remove-Item -Force -Recurse @Path
}

function global:Copy-SSHID {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Destination)
    try {
        Get-Content "$Env:USERPROFILE\.ssh\id_rsa.pub" |
            ssh $Destination 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'
    } catch {
        Write-Warning "Error copying key to $Destination`: $($_.Exception.Message)"
    }
}
```

**Fix `Get-PubIP`** — add error handling:
```powershell
function global:Get-PubIP {
    [CmdletBinding()]
    param()
    try {
        (Invoke-WebRequest 'https://ifconfig.me/ip' -UseBasicParsing).Content.Trim()
    } catch {
        Write-Warning "Could not reach ifconfig.me: $($_.Exception.Message)"
    }
}
```

**`cd...` / `cd....`** — leave as-is (not approved verbs but acceptable navigation aliases).

### PSReadline.ps1

**Delete dead theme hashtables** — `$catppuccinSyntaxTheme2` and `$catppuccinSyntaxTheme3` are defined but never referenced (~60 lines). Delete both.

**Consolidate `Set-PSReadLineOption` calls** at the top:
```powershell
Set-PSReadLineOption -EditMode Windows -HistorySearchCursorMovesToEnd
```
(Was two separate calls.)

**Remove `New-Item -ItemType Directory -Force -Path $Env:XDG_STATE_HOME`** — moved to Env.ps1.

**Consolidate history settings** into one call:
```powershell
Set-PSReadLineOption -HistorySavePath     (Join-Path $Env:XDG_STATE_HOME 'ps_history.txt') `
                     -MaximumHistoryCount 10000 `
                     -HistoryNoDuplicates $true
```

---

## Commit 2: cli_tools_config.ps1

### Framework changes

**Remove `$ErrorActionPreference = 'Stop'`** (line 5) entirely.

**Why this is a bug:** cli_tools_config.ps1 is dot-sourced, so it runs in the caller's scope (the global scope). Setting `$ErrorActionPreference = 'Stop'` overrides profile.ps1's `'Continue'` setting for the entire shell session — the `'Stop'` leaks out and stays active after profile load. The file should inherit from profile.ps1.

**Add `Ensure-Dir` helper** alongside `_HasCmd`/`_HasMod`:
```powershell
function script:Ensure-Dir {
    param([string]$Path)
    if ($Path) { New-Item -ItemType Directory -Force -Path $Path -ErrorAction SilentlyContinue | Out-Null }
}
```

**Fix `Join-Files` / `cat`** — currently defined outside any guard with an inline `Get-Command bat.exe` check on every invocation. Replace with if/else so `cat` is always available but the bat check runs once at profile load:
```powershell
if (_HasCmd 'bat') {
    $Env:BAT_CONFIG_PATH = Join-Path $Env:XDG_CONFIG_HOME 'bat' 'bat.conf'
    # bat completer registration here (moved from below)
    function global:Join-Files {
        [CmdletBinding()]
        param([Parameter(ValueFromRemainingArguments)][string[]]$Path)
        bat -pp @Path
    }
} else {
    function global:Join-Files {
        [CmdletBinding()]
        param([Parameter(ValueFromRemainingArguments)][string[]]$Path)
        Get-Content @Path
    }
}
Set-Alias -Name cat -Value Join-Files -Scope Global -Force
#endregion bat
```

**Remove path captures** — replace closure-capturing `$eza` and `$wm` variables with direct command calls:
```powershell
# eza: was: $eza = (Get-Command eza.exe).Path.ToString(); & $eza ...
function global:_ls { eza --color=auto --icons --group-directories-first @args }

# glazewm: was: $wm = (Get-Command glazewm.exe).Path.ToString(); & $wm ...
function global:Start-GlazeWM {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    glazewm --config (Join-Path $Env:XDG_CONFIG_HOME 'glazewm' 'config.yaml') @Arguments
}
```

**Replace TOCTOU patterns** with `Ensure-Dir`:
- wget: `if (-not (Test-Path $wgetDir)) { New-Item ... }` → `Ensure-Dir $wgetDir`
- nano: same pattern → `Ensure-Dir $nanoDir`
- npm: same pattern → `Ensure-Dir $npmConfigDir`
- winfetch: same pattern → `Ensure-Dir $winfetchDir`
- ripgrep: same pattern → `Ensure-Dir $ripgrepDir`
- All other `New-Item -ItemType Directory -Force -Path $x | Out-Null` → `Ensure-Dir $x`

**Add `[CmdletBinding()]` and `param()` to one-liner functions**: `sstat`, `supd`, `wstat`, `wupd`, `nls`

### fzf Picker Consistency

**Standard tiers:**

| Tier | When | Preview window |
|------|------|---------------|
| 1 — File/code | Content visible in preview | `right:60%` |
| 2 — List only | No meaningful preview | `hidden` |
| 3 — Short output | Prompt-sized preview (oh-my-posh themes) | `bottom:3` |

**Preview window changes:**

| Picker | From | To |
|--------|------|-----|
| `ff` (Select-File) | `right:55%` | `right:60%` |
| `ffd` (Select-FdResult) | `right:50%` | `right:60%` |
| `frg` (Select-RipgrepResult) | `right:55%` | `right:60%` |
| `fcd` (Select-Directory) | `right:40%` | `right:60%` |
| `sins` (Select-ScoopPackage) | `right:45%` | `right:60%` |
| `czf` (Edit-DotFile) | `right:55%` | `right:60%` |
| `fco` (Select-GitBranch) | `right:55%` | `right:60%` |
| `flog` (Select-GitLog) | `right:55%` | `right:60%` |
| `fga` (Select-GitFile) | `right:55%` | `right:60%` |
| `fstash` (Select-GitStash) | `right:55%`, no `--ansi` | `right:60%`, add `--ansi` |
| `fvenv` (Select-UvVenv) | `right:40%` | `right:60%` |
| `fgl` (Read-MarkdownFile) | `right:60%` | already correct |
| `fdc` (Select-DockerContainer) | none | `hidden` |
| `fdi` (Select-DockerImage) | none | `hidden` |
| `fkill` (Select-Process) | `hidden` | already correct |
| `fns` (Select-NpmScript) | none | `hidden` |
| `frtc` (Select-RustupToolchain) | none | `hidden` |
| `fnv` (Select-NodeVersion) | none | `hidden` |
| `fpot` (Select-PoshTheme) | `bottom:3` | already correct |
| `fpr` (Select-GHPr) | none | `hidden` |
| `fgi` (Select-GHIssue) | none | `hidden` |
| `fbw` (Select-BwItem) | none | `hidden` |

**`Select-RipgrepResult` header fix:** Remove literal `$EDITOR` from header string (headers are static strings, env var interpolation doesn't work there).

**`Select-GHIssue` redundancy:** Remove `#` prefix in `ForEach-Object` and `TrimStart('#')` in parsing — pass `$_.number` directly.

### Dead Code & Empty Stubs

**Delete:**
- `PSReadline.ps1`: `$catppuccinSyntaxTheme2`, `$catppuccinSyntaxTheme3` (~60 lines)
- `cli_tools_config.ps1` `#region lsd`: conflicts with eza (noted), serves no purpose

**Convert empty stubs** to lean placeholder comments (remove the `if (_HasCmd) {}` wrapper,
keep the `#region`/`#endregion` markers):
- `duf`, `dua`, `gdu`, `ntop`, `moor`, `win32yank`, `gemini`
- `scoop-completion`, `PSAISuite`, `PSWindowsUpdate`, `Admin`
- `fx`, `jid` (no content, no near-term plan)

Format:
```powershell
#region duf  -  modern df replacement
# not yet configured
#endregion duf
```

---

## What Is Not Changed

- `Completers.ps1` — already clean, single purpose
- `Aliases.ps1` — minimal, correct
- The 6 manual `Register-ArgumentCompleter` blocks — functional, not worth abstracting
- `_HasCmd`/`_HasMod`/`_GetCachedCompletion` helpers — already good
- `#region notepadplusplus` — uses `Test-Path` for a fixed install path (not on PATH), intentional
- `_HasCmd 'scoop' -Exe 'scoop'` override pattern — needed for `.cmd` commands, intentional

---

## Verification

After each commit:
```powershell
# Profile loads without errors
. $PROFILE

# Helpers resolve
Get-Command Test-AdminRole
$Global:IsAdmin                          # $true or $false
Get-Command Join-Files                   # resolves
Get-Alias cat                            # → Join-Files

# PATH is clean
$Env:Path -split ';' | Group-Object | Where Count -gt 1  # should be empty

# fzf pickers resolve
Get-Command ff, fcd, fco, flog, fga, fstash, sins, srm, wins, wrm,
            frg, ffd, fjq, fkill, czf, fbw, fnv, fns, frtc, fvenv,
            fgl, fpot, fpr, fgi, fdc, fdi, lg

# Dead code gone
Get-Variable catppuccinSyntaxTheme2 -ErrorAction Ignore  # should be null

# EAP is correct after profile load
$ErrorActionPreference                   # 'Continue'
```
