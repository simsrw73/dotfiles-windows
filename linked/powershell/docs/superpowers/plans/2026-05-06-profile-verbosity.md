# Profile Output Verbosity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `LogLevel` enum + `Write-ProfileMsg` helper to the PowerShell profile, remove noisy load-time output, gate startup status messages at the right levels, and apply consistent colors/glyphs throughout all runtime function output.

**Architecture:** A `LogLevel` enum (Error=0 Warn=1 Info=2 Debug=3) and `$Global:ProfileLogLevel = [LogLevel]::Info` are defined at the top of `profile.ps1` before any dot-sourcing. `Write-ProfileMsg` is the single output helper for all startup messages; runtime functions use `Write-Host` directly with the same color/glyph conventions. `cli_tools_config.ps1` gains two tracking helpers (`_HasCmd`, `_HasMod`) that replace availability guards and feed a Debug-level tool summary emitted at end of file.

**Tech Stack:** PowerShell 7+, `Write-Host`, `Write-Warning`, `Write-Error`. No external dependencies.

**Spec:** `docs/superpowers/specs/2026-05-06-profile-verbosity-design.md`

---

## Color/Glyph Reference (used throughout all tasks)

| Glyph | Meaning | Color |
|---|---|---|
| `⚡` | Admin / elevated | Cyan (Info) |
| `⚙ ` | Setup step / phase header | Cyan (Info or Debug) |
| `✓` | Success / found / done | Green |
| `·` | Not installed / skipped | DarkYellow |
| `→` | Path / detail | DarkGray |

| Level | Default color |
|---|---|
| Info | Cyan |
| Debug | DarkGray |
| (Green/DarkYellow via `-Color`) | as needed |

---

## Task 1: Add LogLevel enum and Write-ProfileMsg to profile.ps1

**Files:**
- Modify: `C:\Users\simsr\OneDrive\Documents\PowerShell\profile.ps1` (insert after line 11)

- [ ] **Step 1: Insert enum, global variable, and Write-ProfileMsg after the `$VerbosePreference` line**

The block goes between line 11 (`$VerbosePreference = ...`) and line 13 (`# ── VS Code`):

```powershell
# ── Output verbosity ─────────────────────────────────────────────────────────
# Set $Global:ProfileLogLevel to control startup output:
#   [LogLevel]::Warn  — warnings/errors only (scripting, CI)
#   [LogLevel]::Info  — key status lines (default)
#   [LogLevel]::Debug — full detail: modules, file loads, tool inventory
enum LogLevel { Error = 0; Warn = 1; Info = 2; Debug = 3 }
$Global:ProfileLogLevel = [LogLevel]::Info

function global:Write-ProfileMsg {
    param(
        [Parameter(Mandatory)][string]$Message,
        [LogLevel]$Level = [LogLevel]::Info,
        [string]$Color = ''
    )
    if ([int]$Level -gt [int]$Global:ProfileLogLevel) { return }
    switch ($Level) {
        ([LogLevel]::Error) { Write-Error   $Message; return }
        ([LogLevel]::Warn)  { Write-Warning $Message; return }
    }
    $c = if ($Color) { $Color } else {
        switch ($Level) {
            ([LogLevel]::Info)  { 'Cyan' }
            ([LogLevel]::Debug) { 'DarkGray' }
        }
    }
    Write-Host $Message -ForegroundColor $c
}
# ─────────────────────────────────────────────────────────────────────────────
```

- [ ] **Step 2: Run PSScriptAnalyzer to confirm no errors**

```powershell
Invoke-ScriptAnalyzer -Path "C:\Users\simsr\OneDrive\Documents\PowerShell\profile.ps1" -Severity Error
```
Expected: 0 errors.

- [ ] **Step 3: Smoke-test Write-ProfileMsg in a fresh terminal**

```powershell
. $PROFILE
Write-ProfileMsg 'test Info'                          # should print cyan
Write-ProfileMsg 'test Debug' -Level Debug            # should be silent (Info level)
$Global:ProfileLogLevel = [LogLevel]::Debug
Write-ProfileMsg 'test Debug' -Level Debug            # should print DarkGray
$Global:ProfileLogLevel = [LogLevel]::Info            # restore
```

- [ ] **Step 4: Commit**

```
git add profile.ps1
git commit -m "feat: add LogLevel enum and Write-ProfileMsg to profile.ps1"
```

---

## Task 2: Remove noisy unconditional load-time output

**Files:**
- Modify: `ProfileModules/Env.ps1` (lines 7–32 — terminal detection block)
- Modify: `ProfileModules/Show-HelpColor.ps1` (line 4)
- Modify: `profile.ps1` (lines 58–67 — startup diagnostics block)

- [ ] **Step 1: Replace the terminal detection block in Env.ps1**

Replace lines 6–32 (the entire `# Terminal detection` if/elseif chain) with:

```powershell
# Terminal detection — set $isVSCodeTerm; fill TERM_PROGRAM for terminals that don't set it
$isVSCodeTerm = $Env:TERM_PROGRAM -eq 'vscode'
if (-not $Env:TERM_PROGRAM) {
    if      ($Env:ALACRITTY_LOG)        { $Env:TERM_PROGRAM = 'Alacritty' }
    elseif  ($Env:LC_EXTRATERM_COOKIE)  { $Env:TERM_PROGRAM = 'ExtraTerm' }
    elseif  ($env:WT_SESSION)           { $Env:TERM_PROGRAM = 'wt' }
}
```

The WezTerm/Tabby/Hyper/Sublime/vscode branches previously only printed — they had no other side effects. The ALACRITTY_LOG/LC_EXTRATERM_COOKIE/WT_SESSION branches set `$Env:TERM_PROGRAM`; guard them with `if (-not $Env:TERM_PROGRAM)` so they only fire when the terminal didn't set it itself.

- [ ] **Step 2: Remove 'Loading functions...' from Show-HelpColor.ps1**

Delete line 4: `Write-Host 'Loading functions...'`

The file should now read:
```powershell
#Requires -Version 7.0

Set-StrictMode -Version 'Latest'

function global:Show-HelpColor {
```

- [ ] **Step 3: Remove the startup diagnostics block from profile.ps1**

Delete the entire block (lines 58–67):
```powershell
# Startup diagnostics
$PSInfo = Get-Process -Id $pid | Get-Item
Write-Output "Current shell: $PSInfo"

$termInfo = $Host.UI.RawUI
if ($termInfo.WindowSize.Height -le 20) {
    Write-Output 'Terminal size is small.'
} else {
    Write-Output 'Terminal size is normal.'
}
```

- [ ] **Step 4: Run PSScriptAnalyzer on changed files**

```powershell
$root = "C:\Users\simsr\OneDrive\Documents\PowerShell"
foreach ($f in @('ProfileModules\Env.ps1','ProfileModules\Show-HelpColor.ps1','profile.ps1')) {
    $r = Invoke-ScriptAnalyzer -Path "$root\$f" -Severity Error
    if ($r) { $r } else { Write-Host "OK $f" -ForegroundColor Green }
}
```

- [ ] **Step 5: Open a new terminal and confirm the removed messages are gone**

No `'WezTerm detected'`, `'VS Code Terminal'`, `'Loading functions...'`, `'Current shell:'`, or terminal size messages should appear.

- [ ] **Step 6: Commit**

```
git add ProfileModules/Env.ps1 ProfileModules/Show-HelpColor.ps1 profile.ps1
git commit -m "feat: remove noisy unconditional load-time output"
```

---

## Task 3: Gate startup status messages at Info level

**Files:**
- Modify: `ProfileModules/Functions.ps1` (lines 9–12)
- Modify: `profile.ps1` (Dev Shell block ~lines 84–89; Friday update ~lines 70–73; experimental feature ~lines 76–80; transcript path ~line 110)

- [ ] **Step 1: Replace admin Write-Output in Functions.ps1**

Replace:
```powershell
$global:isAdmin = isAdminUser
if ($global:isAdmin) {
    Write-Output 'Running as Administrator'
}
```
With:
```powershell
$global:isAdmin = isAdminUser
if ($global:isAdmin) {
    Write-ProfileMsg '⚡ Administrator' -Color Cyan
}
```

- [ ] **Step 2: Replace the VS Dev Shell block in profile.ps1**

Replace:
```powershell
# VS Dev Shell
Write-Host 'Setting up MS Dev Environment... ' -ForegroundColor Green -NoNewline
$vsWhere = "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsInstallationPath = & $vsWhere -products * -latest -property installationPath
& "${vsInstallationPath}\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64 -SkipAutomaticLocation | Out-Null
Write-Host 'Done.' -ForegroundColor Green
```
With:
```powershell
# VS Dev Shell
$vsWhere = "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vsWhere) {
    $vsInstallationPath = & $vsWhere -products * -latest -property installationPath
    & "${vsInstallationPath}\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64 -SkipAutomaticLocation | Out-Null
    Write-ProfileMsg '⚙  Dev Shell ready'
}
```

- [ ] **Step 3: Replace the Friday update Write-Host in profile.ps1**

Replace:
```powershell
if ((Get-Date).DayOfWeek -eq 'Friday') {
    Write-Host 'Running weekly module update...' -ForegroundColor Cyan
    Update-AllModules
}
```
With:
```powershell
if ((Get-Date).DayOfWeek -eq 'Friday') {
    Write-ProfileMsg '⚙  Running weekly module update…'
    Update-AllModules
}
```

- [ ] **Step 4: Gate the experimental feature message at Debug**

Replace:
```powershell
if ($experimentalFeatures.Name -contains 'PSFeedbackProvider') {
    Write-Host 'Enabling experimental feature: PSFeedbackProvider'
    Enable-ExperimentalFeature PSFeedbackProvider
}
```
With:
```powershell
if ($experimentalFeatures.Name -contains 'PSFeedbackProvider') {
    Enable-ExperimentalFeature PSFeedbackProvider
    Write-ProfileMsg '  ⚙  PSFeedbackProvider enabled' -Level Debug
}
```

- [ ] **Step 5: Add Debug transcript path message in profile.ps1**

After the `Start-Transcript` try block succeeds (after the `| Out-Null` line inside the try), add:
```powershell
        Write-ProfileMsg "  → Transcript: $tsPath" -Level Debug
```

The try block should look like:
```powershell
    try {
        Start-Transcript -LiteralPath $tsPath -Append -IncludeInvocationHeader -ErrorAction Stop | Out-Null
        Write-ProfileMsg "  → Transcript: $tsPath" -Level Debug
    } catch {
        Write-Warning "Failed to start transcript: $($_.Exception.Message)"
    }
```

- [ ] **Step 6: Verify at Info level (default)**

Open a new standard terminal. Expected output:
```
⚡ Administrator        ← if running elevated
⚙  Dev Shell ready
```
Nothing else.

- [ ] **Step 7: Verify at Debug level**

Set `$Global:ProfileLogLevel = [LogLevel]::Debug` at the top of `profile.ps1` temporarily, open a new terminal. The `⚙  PSFeedbackProvider enabled` and `→ Transcript: …` lines should appear. Restore to `[LogLevel]::Info` after verifying.

- [ ] **Step 8: Run PSScriptAnalyzer**

```powershell
Invoke-ScriptAnalyzer -Path "C:\Users\simsr\OneDrive\Documents\PowerShell\profile.ps1" -Severity Error
Invoke-ScriptAnalyzer -Path "C:\Users\simsr\OneDrive\Documents\PowerShell\ProfileModules\Functions.ps1" -Severity Error
```

- [ ] **Step 9: Commit**

```
git add profile.ps1 ProfileModules/Functions.ps1
git commit -m "feat: gate startup status messages with Write-ProfileMsg"
```

---

## Task 4: Add Debug-level module import reporting to profile.ps1

**Files:**
- Modify: `profile.ps1` — both the VS Code fast-path import loop (lines 17–23) and the full-path import loop (lines 37–48)

- [ ] **Step 1: Replace the VS Code fast-path import loop**

Replace:
```powershell
    foreach ($mod in @('PSReadLine', 'PSFzf')) {
        try {
            Import-Module -Name $mod -ErrorAction Stop
        } catch {
            Write-Warning "Module '$mod' failed to load: $($_.Exception.Message)"
        }
    }
```
With:
```powershell
    $_modsOk = [System.Collections.Generic.List[string]]::new()
    foreach ($mod in @('PSReadLine', 'PSFzf')) {
        try {
            Import-Module -Name $mod -ErrorAction Stop
            $null = $_modsOk.Add($mod)
        } catch {
            Write-Warning "Module '$mod' failed to load: $($_.Exception.Message)"
        }
    }
    if ($_modsOk.Count -gt 0) {
        Write-ProfileMsg ("  Modules: " + (($_modsOk | ForEach-Object { "✓ $_" }) -join '  ')) -Level Debug -Color Green
    }
```

- [ ] **Step 2: Replace the full-path import loop**

Replace:
```powershell
foreach ($mod in @(
        'PSReadLine', 'PSFzf', 'powershell-yaml',
        'Microsoft.PowerShell.SecretManagement'
        # DockerCompletion: imported in cli_tools_config.ps1 (#region DockerCompletion)
        # scoop-completion: handled by PSFzf -EnableAliasFuzzyScoop in cli_tools_config.ps1
    )) {
    try {
        Import-Module -Name $mod -ErrorAction Stop
    } catch {
        Write-Warning "Module '$mod' failed to load: $($_.Exception.Message)"
    }
}
```
With:
```powershell
$_modsOk   = [System.Collections.Generic.List[string]]::new()
$_modsFail = [System.Collections.Generic.List[string]]::new()
foreach ($mod in @(
        'PSReadLine', 'PSFzf', 'powershell-yaml',
        'Microsoft.PowerShell.SecretManagement'
        # DockerCompletion: imported in cli_tools_config.ps1 (#region DockerCompletion)
        # scoop-completion: handled by PSFzf -EnableAliasFuzzyScoop in cli_tools_config.ps1
    )) {
    try {
        Import-Module -Name $mod -ErrorAction Stop
        $null = $_modsOk.Add($mod)
    } catch {
        $null = $_modsFail.Add($mod)
        Write-Warning "Module '$mod' failed to load: $($_.Exception.Message)"
    }
}
if ($_modsOk.Count -gt 0) {
    Write-ProfileMsg ("  Modules: " + (($_modsOk | ForEach-Object { "✓ $_" }) -join '  ')) -Level Debug -Color Green
}
if ($_modsFail.Count -gt 0) {
    Write-ProfileMsg ("  Failed:  " + (($_modsFail | ForEach-Object { "· $_" }) -join '  ')) -Level Debug -Color DarkYellow
}
```

- [ ] **Step 3: Run PSScriptAnalyzer**

```powershell
Invoke-ScriptAnalyzer -Path "C:\Users\simsr\OneDrive\Documents\PowerShell\profile.ps1" -Severity Error
```

- [ ] **Step 4: Commit**

```
git add profile.ps1
git commit -m "feat: add Debug-level module import reporting"
```

---

## Task 5: Add Debug-level file load reporting to profile.ps1

**Files:**
- Modify: `profile.ps1` — both dot-source blocks (VS Code fast-path lines 24–30; full-path lines 50–56)

- [ ] **Step 1: Replace the VS Code fast-path dot-source block**

Replace:
```powershell
    . (Join-Path $moduleRoot 'Env.ps1')
    . (Join-Path $moduleRoot 'Aliases.ps1')
    . (Join-Path $moduleRoot 'Functions.ps1')
    . (Join-Path $moduleRoot 'Completers.ps1')
    . (Join-Path $moduleRoot 'PSReadline.ps1')
    . (Join-Path $moduleRoot 'cli_tools_config.ps1')
    . (Join-Path $moduleRoot 'Show-HelpColor.ps1')
```
With:
```powershell
    . (Join-Path $moduleRoot 'Env.ps1')
    Write-ProfileMsg "  Terminal: $($Env:TERM_PROGRAM ?? 'unknown')" -Level Debug
    Write-ProfileMsg '  · Aliases.ps1' -Level Debug
    . (Join-Path $moduleRoot 'Aliases.ps1')
    Write-ProfileMsg '  · Functions.ps1' -Level Debug
    . (Join-Path $moduleRoot 'Functions.ps1')
    Write-ProfileMsg '  · Completers.ps1' -Level Debug
    . (Join-Path $moduleRoot 'Completers.ps1')
    Write-ProfileMsg '  · PSReadline.ps1' -Level Debug
    . (Join-Path $moduleRoot 'PSReadline.ps1')
    Write-ProfileMsg '  · cli_tools_config.ps1' -Level Debug
    . (Join-Path $moduleRoot 'cli_tools_config.ps1')
    Write-ProfileMsg '  · Show-HelpColor.ps1' -Level Debug
    . (Join-Path $moduleRoot 'Show-HelpColor.ps1')
```

Note: Env.ps1 is loaded without a preceding label line — terminal info is emitted after Env.ps1 runs (it sets `$Env:TERM_PROGRAM`).

- [ ] **Step 2: Replace the full-path dot-source block**

Replace:
```powershell
. (Join-Path $moduleRoot 'Env.ps1')
. (Join-Path $moduleRoot 'Aliases.ps1')
. (Join-Path $moduleRoot 'Functions.ps1')
. (Join-Path $moduleRoot 'Completers.ps1')
. (Join-Path $moduleRoot 'PSReadline.ps1')
. (Join-Path $moduleRoot 'cli_tools_config.ps1')
. (Join-Path $moduleRoot 'Show-HelpColor.ps1')
```
With:
```powershell
. (Join-Path $moduleRoot 'Env.ps1')
Write-ProfileMsg "  Terminal: $($Env:TERM_PROGRAM ?? 'unknown')" -Level Debug
Write-ProfileMsg '  · Aliases.ps1' -Level Debug
. (Join-Path $moduleRoot 'Aliases.ps1')
Write-ProfileMsg '  · Functions.ps1' -Level Debug
. (Join-Path $moduleRoot 'Functions.ps1')
Write-ProfileMsg '  · Completers.ps1' -Level Debug
. (Join-Path $moduleRoot 'Completers.ps1')
Write-ProfileMsg '  · PSReadline.ps1' -Level Debug
. (Join-Path $moduleRoot 'PSReadline.ps1')
Write-ProfileMsg '  · cli_tools_config.ps1' -Level Debug
. (Join-Path $moduleRoot 'cli_tools_config.ps1')
Write-ProfileMsg '  · Show-HelpColor.ps1' -Level Debug
. (Join-Path $moduleRoot 'Show-HelpColor.ps1')
```

- [ ] **Step 3: Verify Debug output shape**

Temporarily set `$Global:ProfileLogLevel = [LogLevel]::Debug`, open a new terminal. Expected Debug block:

```
  Terminal: wt
  Modules: ✓ PSReadLine  ✓ PSFzf  ✓ powershell-yaml
  · Aliases.ps1
  · Functions.ps1
  · Completers.ps1
  · PSReadline.ps1
  · cli_tools_config.ps1
    ✓ eza  ✓ bat  ✓ fzf  …  · glazewm  · mosquitto
  · Show-HelpColor.ps1
⚡ Administrator
⚙  Dev Shell ready
  → Transcript: PowerShell.Transcripts/…
```

Restore `[LogLevel]::Info` after verifying.

- [ ] **Step 4: Run PSScriptAnalyzer**

```powershell
Invoke-ScriptAnalyzer -Path "C:\Users\simsr\OneDrive\Documents\PowerShell\profile.ps1" -Severity Error
```

- [ ] **Step 5: Commit**

```
git add profile.ps1
git commit -m "feat: add Debug-level terminal info and ProfileModule file load reporting"
```

---

## Task 6: Add tool availability tracking to cli_tools_config.ps1

**Files:**
- Modify: `ProfileModules/cli_tools_config.ps1` — top (add helpers + arrays), all ~50 region guards, bottom (add summary)

This task is mechanical: add two helper functions and two tracking arrays at the top, change each `if (Get-Command ... -ErrorAction Ignore)` guard to `if (_HasCmd 'name')`, change each `if (Get-Module -Name X)` guard to `if (_HasMod 'X')`, then add the summary block at the bottom.

- [ ] **Step 1: Add tracking arrays and helper functions at the top of cli_tools_config.ps1**

After the `$ErrorActionPreference = 'Stop'` line (line 5), insert:

```powershell
# ── Tool availability tracking ────────────────────────────────────────────────
$script:_toolsFound   = [System.Collections.Generic.List[string]]::new()
$script:_toolsMissing = [System.Collections.Generic.List[string]]::new()

function script:_HasCmd {
    param([string]$Label, [string]$Exe = '')
    if (-not $Exe) { $Exe = "$Label.exe" }
    if ($null -ne (Get-Command $Exe -ErrorAction Ignore)) {
        $null = $script:_toolsFound.Add($Label); $true
    } else {
        $null = $script:_toolsMissing.Add($Label); $false
    }
}

function script:_HasMod {
    param([string]$Label, [string]$Module = '')
    if (-not $Module) { $Module = $Label }
    if ($null -ne (Get-Module -Name $Module)) {
        $null = $script:_toolsFound.Add($Label); $true
    } else {
        $null = $script:_toolsMissing.Add($Label); $false
    }
}
# ─────────────────────────────────────────────────────────────────────────────
```

- [ ] **Step 2: Replace all CLI tool guards (exe-based)**

Find every `if (Get-Command <name>.exe -ErrorAction Ignore)` and replace with `if (_HasCmd '<name>')`. For tools where the exe name differs from the label or has no .exe suffix, pass `-Exe` explicitly.

Full substitution table:

| Old guard | New guard |
|---|---|
| `Get-Command eza.exe -ErrorAction Ignore` | `_HasCmd 'eza'` |
| `Get-Command bat.exe -ErrorAction Ignore` | `_HasCmd 'bat'` |
| `Get-Command fd.exe -ErrorAction Ignore` | `_HasCmd 'fd'` |
| `Get-Command rg.exe -ErrorAction Ignore` | `_HasCmd 'rg'` |
| `Get-Command broot.exe -ErrorAction Ignore` | `_HasCmd 'broot'` |
| `Get-Command lsd.exe -ErrorAction Ignore` | `_HasCmd 'lsd'` |
| `Get-Command jq.exe -ErrorAction Ignore` | `_HasCmd 'jq'` |
| `Get-Command fx.exe -ErrorAction Ignore` | `_HasCmd 'fx'` |
| `Get-Command jid.exe -ErrorAction Ignore` | `_HasCmd 'jid'` |
| `Get-Command glow.exe -ErrorAction Ignore` | `_HasCmd 'glow'` |
| `Get-Command procs.exe -ErrorAction Ignore` | `_HasCmd 'procs'` |
| `Get-Command duf.exe -ErrorAction Ignore` | `_HasCmd 'duf'` |
| `Get-Command dua.exe -ErrorAction Ignore` | `_HasCmd 'dua'` |
| `Get-Command gdu.exe -ErrorAction Ignore` | `_HasCmd 'gdu'` |
| `Get-Command ntop.exe -ErrorAction Ignore` | `_HasCmd 'ntop'` |
| `Get-Command winfetch -ErrorAction Ignore` | `_HasCmd 'winfetch' -Exe 'winfetch'` |
| `Get-Command curl.exe -ErrorAction Ignore` | `_HasCmd 'curl'` |
| `Get-Command wget.exe -ErrorAction Ignore` | `_HasCmd 'wget'` |
| `Get-Command nano.exe -ErrorAction Ignore` | `_HasCmd 'nano'` |
| `Get-Command micro.exe -ErrorAction Ignore` | `_HasCmd 'micro'` |
| `Get-Command fzf.exe -ErrorAction Ignore` | `_HasCmd 'fzf'` |
| `Get-Command zoxide.exe -ErrorAction Ignore` | `_HasCmd 'zoxide'` |
| `Get-Command moor.exe -ErrorAction Ignore` | `_HasCmd 'moor'` |
| `Get-Command less.exe -ErrorAction Ignore` | `_HasCmd 'less'` |
| `Get-Command scoop -ErrorAction Ignore` | `_HasCmd 'scoop' -Exe 'scoop'` |
| `Get-Command sfsu.exe -ErrorAction Ignore` | `_HasCmd 'sfsu'` |
| `Get-Command winget -ErrorAction Ignore` | `_HasCmd 'winget' -Exe 'winget'` |
| `Get-Command cargo.exe -ErrorAction Ignore` | `_HasCmd 'cargo'` |
| `Get-Command rustup.exe -ErrorAction Ignore` | `_HasCmd 'rustup'` |
| `Get-Command nvm -ErrorAction Ignore` | `_HasCmd 'nvm' -Exe 'nvm'` |
| `Get-Command npm -ErrorAction Ignore` | `_HasCmd 'npm' -Exe 'npm'` |
| `Get-Command uv.exe -ErrorAction Ignore` | `_HasCmd 'uv'` |
| `Get-Command chezmoi.exe -ErrorAction Ignore` | `_HasCmd 'chezmoi'` |
| `Get-Command bw -ErrorAction Ignore` | `_HasCmd 'bw' -Exe 'bw'` |
| `Get-Command gemini -ErrorAction Ignore` | `_HasCmd 'gemini' -Exe 'gemini'` |
| `Get-Command win32yank.exe -ErrorAction Ignore` | `_HasCmd 'win32yank'` |
| `Get-Command gsudo.exe -ErrorAction Ignore` | `_HasCmd 'gsudo'` |
| `Get-Command glazewm.exe -ErrorAction Ignore` | `_HasCmd 'glazewm'` |
| `Get-Command mosquitto.exe -ErrorAction Ignore` | `_HasCmd 'mosquitto'` |

The `#region bat` guard is split — `bat.exe` appears twice (outer guard + inner `Join-Files` guard). Only change the outer `#region bat` guard. The `Join-Files` internal guard stays as `Get-Command bat.exe -ErrorAction Ignore` since it's not a region guard.

The `#region notepadplusplus` section uses `Test-Path` not `Get-Command` — leave it unchanged (no tracking for this section).

- [ ] **Step 3: Replace all PS module guards**

| Old guard | New guard |
|---|---|
| `Get-Module -Name posh-git -ListAvailable` | `_HasMod 'posh-git'` |
| `Get-Module -Name Terminal-Icons -ListAvailable` | `_HasMod 'Terminal-Icons'` |
| `Get-Module -Name PSFzf` | `_HasMod 'PSFzf'` |
| `Get-Module -Name scoop-completion -ListAvailable` | `_HasMod 'scoop-completion'` |
| `Get-Module -Name DockerCompletion -ListAvailable` | `_HasMod 'DockerCompletion'` |
| `Get-Module -Name PowerType -ListAvailable` | `_HasMod 'PowerType'` |
| `Get-Module -Name PSAISuite -ListAvailable` | `_HasMod 'PSAISuite'` |
| `Get-Module -Name PSWindowsUpdate -ListAvailable` | `_HasMod 'PSWindowsUpdate'` |
| `Get-Module -Name Admin -ListAvailable` | `_HasMod 'Admin'` |
| `Get-Module -Name gsudoModule -ListAvailable` | `_HasMod 'gsudo'` |

Note: The PSFzf guard was already changed to `Get-Module -Name PSFzf` (no `-ListAvailable`) in a prior bug fix. `_HasMod` uses the same check — no `-ListAvailable`.

- [ ] **Step 4: Add summary block at the bottom of cli_tools_config.ps1**

Append after all `#endregion` blocks:

```powershell
# ── Tool availability summary (Debug level) ───────────────────────────────────
if ($script:_toolsFound.Count -gt 0 -or $script:_toolsMissing.Count -gt 0) {
    $found   = ($script:_toolsFound   | ForEach-Object { "✓ $_" }) -join '  '
    $missing = ($script:_toolsMissing | ForEach-Object { "· $_" }) -join '  '
    if ($found)   { Write-ProfileMsg "  $found"   -Level Debug -Color Green }
    if ($missing) { Write-ProfileMsg "  $missing" -Level Debug -Color DarkYellow }
}
```

- [ ] **Step 5: Run PSScriptAnalyzer**

```powershell
Invoke-ScriptAnalyzer -Path "C:\Users\simsr\OneDrive\Documents\PowerShell\ProfileModules\cli_tools_config.ps1" -Severity Error
```
Expected: 0 errors.

- [ ] **Step 6: Open a new terminal at Debug level and verify tool summary appears**

Temporarily set `[LogLevel]::Debug`, open terminal. The last lines before the runtime prompt should include two lines like:
```
  ✓ eza  ✓ bat  ✓ fzf  ✓ zoxide  ✓ rg  ✓ broot  ✓ cargo  …
  · glazewm  · mosquitto  · lsd  · ntop  …
```
Restore `[LogLevel]::Info`.

- [ ] **Step 7: Commit**

```
git add ProfileModules/cli_tools_config.ps1
git commit -m "feat: add tool availability tracking and Debug summary to cli_tools_config.ps1"
```

---

## Task 7: Restyle Update-AllModules output

**Files:**
- Modify: `ProfileModules/Functions.ps1` — the `Update-AllModules` function body only

All changes are `Write-Host` replacements. Logic and structure are unchanged.

- [ ] **Step 1: Replace all Write-Host calls inside Update-AllModules**

Apply these substitutions in order within the function body:

```powershell
# BEFORE → AFTER

Write-Host "`n=== Phase 1: Pruning stale module entries ===" -ForegroundColor Yellow
→ Write-Host "`n⚙  Phase 1 — Pruning stale entries" -ForegroundColor Cyan

Write-Host 'No stale entries found.' -ForegroundColor Green
→ Write-Host '  ✓ No stale entries' -ForegroundColor Green

Write-Host "  Stale: $($module.Name) v$($module.Version) -> $($module.InstalledLocation)" -ForegroundColor Red
→ Write-Warning "Stale entry: $($module.Name) v$($module.Version) — $($module.InstalledLocation)"

Write-Host "`n=== Phase 2: Updating installed modules ===" -ForegroundColor Yellow
→ Write-Host "`n⚙  Phase 2 — Updating modules" -ForegroundColor Cyan

Write-Host "  [$i/$total] SKIP (needs admin): $($module.Name) [$scope]" -ForegroundColor DarkYellow
→ Write-Host "  · [$i/$total] $($module.Name) — needs admin" -ForegroundColor DarkYellow

Write-Host "  [$i/$total] $($module.Name) [$scope]..." -NoNewline
→ Write-Host "  [$i/$total] $($module.Name)…" -ForegroundColor DarkGray -NoNewline

Write-Host ' Done.' -ForegroundColor Green
→ Write-Host ' ✓' -ForegroundColor Green

Write-Host "`n=== Phase 3: Updating help files ===" -ForegroundColor Yellow
→ Write-Host "`n⚙  Phase 3 — Updating help files" -ForegroundColor Cyan

Write-Host 'Help update complete.' -ForegroundColor Green
→ Write-Host '  ✓ Help updated' -ForegroundColor Green

Write-Host "Help update encountered errors: $($_.Exception.Message)" -ForegroundColor DarkYellow
→ Write-Warning "Help update failed: $($_.Exception.Message)"

Write-Host "`nAll done." -ForegroundColor Cyan
→ Write-Host "`n✓ Done" -ForegroundColor Green
```

- [ ] **Step 2: Run PSScriptAnalyzer**

```powershell
Invoke-ScriptAnalyzer -Path "C:\Users\simsr\OneDrive\Documents\PowerShell\ProfileModules\Functions.ps1" -Severity Error
```

- [ ] **Step 3: Verify by running Update-AllModules (use -WhatIf to avoid actual updates)**

```powershell
Update-AllModules -WhatIf
```
Confirm phase headers show `⚙` in Cyan, skip lines show `·` in DarkYellow.

- [ ] **Step 4: Commit**

```
git add ProfileModules/Functions.ps1
git commit -m "feat: restyle Update-AllModules output with consistent colors and glyphs"
```

---

## Task 8: Restyle fzf picker output in cli_tools_config.ps1

**Files:**
- Modify: `ProfileModules/cli_tools_config.ps1` — Write-Host calls inside picker functions only

- [ ] **Step 1: Apply restyling substitutions to picker function Write-Host calls**

```powershell
# Select-ScoopPackage
Write-Host "Installing $name..." -ForegroundColor Cyan
→ Write-Host "⚙  Installing $name…" -ForegroundColor Cyan

# Remove-ScoopPackage
Write-Host "Uninstalling $name..." -ForegroundColor Yellow
→ Write-Host "⚙  Uninstalling $name…" -ForegroundColor DarkYellow

# Select-WingetPackage
Write-Host "Installing $id..." -ForegroundColor Cyan
→ Write-Host "⚙  Installing $id…" -ForegroundColor Cyan

# Remove-WingetPackage
Write-Host "Uninstalling $id..." -ForegroundColor Yellow
→ Write-Host "⚙  Uninstalling $id…" -ForegroundColor DarkYellow

# Select-BwItem
Write-Host 'Password copied to clipboard.' -ForegroundColor Green
→ Write-Host '✓ Password copied to clipboard' -ForegroundColor Green

# Select-PoshTheme
Write-Host "Applied theme: $theme (add to cli_tools_config.ps1 to persist)" -ForegroundColor Cyan
→ Write-Host "✓ Theme applied: $theme" -ForegroundColor Green
→ Write-Host "  → To persist: update #region oh-my-posh in cli_tools_config.ps1" -ForegroundColor DarkGray
```

The `Write-Warning` calls in `Select-NpmScript`, `Select-UvVenv`, and `Select-BwItem` are already correct — leave them unchanged.

- [ ] **Step 2: Run PSScriptAnalyzer**

```powershell
Invoke-ScriptAnalyzer -Path "C:\Users\simsr\OneDrive\Documents\PowerShell\ProfileModules\cli_tools_config.ps1" -Severity Error
```

- [ ] **Step 3: Spot-check one picker function**

In a terminal with scoop available:
```powershell
sins   # Select-ScoopPackage — pick any package
```
Confirm the install line reads `⚙  Installing <name>…` in Cyan.

- [ ] **Step 4: Commit**

```
git add ProfileModules/cli_tools_config.ps1
git commit -m "feat: restyle fzf picker output with consistent colors and glyphs"
```

---

## Verification

After all tasks, open fresh standard and VS Code terminals with `[LogLevel]::Info` (default):

**Standard terminal — expected:**
```
⚡ Administrator        ← only if elevated
⚙  Dev Shell ready
```

**VS Code terminal — expected:**
```
(nothing — Info level with no admin, fast-path skips Dev Shell)
```

**Standard terminal with `[LogLevel]::Debug`:**
```
  Terminal: wt
  Modules: ✓ PSReadLine  ✓ PSFzf  ✓ powershell-yaml
  · Aliases.ps1
  · Functions.ps1
⚡ Administrator
  · Completers.ps1
  · PSReadline.ps1
  · cli_tools_config.ps1
    ✓ eza  ✓ bat  ✓ fzf  ✓ zoxide  ✓ rg  …
    · glazewm  · mosquitto  …
  · Show-HelpColor.ps1
⚙  Dev Shell ready
  → Transcript: PowerShell.Transcripts/2026-05-06/Transcript_….txt
```

PSScriptAnalyzer must report 0 errors on all modified files.
