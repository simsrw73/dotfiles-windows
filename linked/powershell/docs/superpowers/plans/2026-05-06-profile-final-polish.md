# Profile Final Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply a comprehensive polish pass to all 8 profile files: extract reusable helpers, standardize naming, fix real bugs, unify fzf picker appearance, and remove dead code.

**Architecture:** Two commits. Commit 1 touches the 3 infrastructure module files (Env.ps1, Functions.ps1, PSReadline.ps1). Commit 2 rewrites cli_tools_config.ps1 in place — framework fixes first, then fzf consistency, then dead code removal. All files are dot-sourced modules; there are no test files. Verification is done by reloading the profile and asserting that specific commands/variables resolve correctly.

**Tech Stack:** PowerShell 7+, Windows 11. Key tools: fzf (fuzzy finder), eza (ls replacement), bat (cat replacement). Profile is split across `profile.ps1` (entry point) + `ProfileModules/*.ps1` (dot-sourced modules).

---

## File Map

| File | Changes |
|------|---------|
| `ProfileModules/Env.ps1` | Add `Add-ToPath` helper; replace 4 PATH dedup blocks; add XDG state dir creation |
| `ProfileModules/Functions.ps1` | Rename `isAdminUser`→`Test-AdminRole`; `$global:isAdmin`→`$Global:IsAdmin`; fix param blocks on 4 functions; add error handling to `Get-PubIP` |
| `ProfileModules/PSReadline.ps1` | Delete 2 unused theme hashtables; consolidate `Set-PSReadLineOption` calls; remove XDG dir creation (moved to Env.ps1) |
| `ProfileModules/cli_tools_config.ps1` | Remove `$ErrorActionPreference = 'Stop'`; add `Ensure-Dir` helper; fix `#region bat` structure; remove closure-captured path vars; replace TOCTOU dir patterns; add `[CmdletBinding()]` to 5 one-liners; standardize 22 fzf pickers; delete `#region lsd`; convert 13 empty stubs to lean comments |

---

## Task 1: Add `Add-ToPath` helper to Env.ps1

**Files:** Modify `ProfileModules/Env.ps1`

- [ ] **Open** `ProfileModules/Env.ps1`. The current file starts with `#Requires -Version 7.0` followed by the `# Editor` block. Insert the `Add-ToPath` helper between `#Requires` and `# Editor`:

```powershell
#Requires -Version 7.0

# ── PATH helper ────────────────────────────────────────────────────────────────
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
# ─────────────────────────────────────────────────────────────────────────────

# Editor
```

- [ ] **Replace** the `# XDG Base Directory` block. Find these 4 lines:

```powershell
$Env:XDG_CONFIG_HOME = Join-Path -Path $home -ChildPath '.config'
$Env:XDG_DATA_HOME = Join-Path -Path $home -ChildPath '.local' 'share'
$Env:XDG_STATE_HOME = Join-Path -Path $home -ChildPath '.local' 'state'
$Env:XDG_CACHE_HOME = Join-Path -Path $home -ChildPath '.cache'
```

Replace with (adds state dir creation, short `Join-Path` style):

```powershell
$Env:XDG_CONFIG_HOME = Join-Path $home '.config'
$Env:XDG_DATA_HOME   = Join-Path $home '.local' 'share'
$Env:XDG_STATE_HOME  = Join-Path $home '.local' 'state'
$Env:XDG_CACHE_HOME  = Join-Path $home '.cache'
New-Item -ItemType Directory -Force -Path $Env:XDG_STATE_HOME -ErrorAction SilentlyContinue | Out-Null
```

- [ ] **Replace** the `# PATH: personal scripts` block (3 lines with `$_scripts` + `if` + `+=`):

```powershell
# PATH: personal scripts
$_scripts = Join-Path $home 'scripts'
if ($Env:Path -split [IO.Path]::PathSeparator -notcontains $_scripts) {
    $Env:Path += [IO.Path]::PathSeparator + $_scripts
}
```

With:

```powershell
Add-ToPath (Join-Path $home 'scripts')
```

- [ ] **Replace** the cargo/bin PATH block (3 lines with `$_cargoBin` + `if` + `+=`):

```powershell
$_cargoBin = Join-Path $Env:CARGO_HOME 'bin'
if ($Env:Path -split [IO.Path]::PathSeparator -notcontains $_cargoBin) {
    $Env:Path += [IO.Path]::PathSeparator + $_cargoBin
}
```

With:

```powershell
Add-ToPath (Join-Path $Env:CARGO_HOME 'bin')
```

- [ ] **Replace** the Python PATH block inside the `if (Get-Command python ...)` guard:

```powershell
    if ($pythonScriptsPath -and ($env:Path -split [IO.Path]::PathSeparator -notcontains $pythonScriptsPath)) {
        $env:Path = "$pythonScriptsPath;$env:Path"
    }
```

With:

```powershell
    if ($pythonScripts) { Add-ToPath $pythonScripts -Prepend }
```

Also rename `$pythonScriptsPath` → `$pythonScripts` in the line above:

```powershell
    $pythonScripts = python -c "import sysconfig; print(sysconfig.get_path('scripts'))" 2>$null
```

- [ ] **Replace** the Pulsar PATH block (3 lines with `$_pulsarBin` + `if` + `+=`):

```powershell
$_pulsarBin = Join-Path $env:LOCALAPPDATA 'Programs' 'Pulsar'
if ($Env:Path -split [IO.Path]::PathSeparator -notcontains $_pulsarBin) {
    $Env:Path += [IO.Path]::PathSeparator + $_pulsarBin
}
```

With:

```powershell
Add-ToPath (Join-Path $env:LOCALAPPDATA 'Programs' 'Pulsar')
```

- [ ] **Verify** by dot-sourcing Env.ps1 in a fresh PS7 session and checking:

```powershell
. .\ProfileModules\Env.ps1
# Should print nothing (no errors)
# Check PATH is clean — no duplicates:
($Env:Path -split ';').Count
$Env:Path -split ';' | Group-Object | Where-Object Count -gt 1
# Should return nothing (no dupes)
```

---

## Task 2: Polish Functions.ps1

**Files:** Modify `ProfileModules/Functions.ps1`

- [ ] **Replace** the `isAdminUser` function and `$global:isAdmin` assignment at the top of the file:

```powershell
function global:isAdminUser {
    $wi = [Security.Principal.WindowsIdentity]::GetCurrent()
    $wp = New-Object Security.Principal.WindowsPrincipal($wi)
    $wp.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$global:isAdmin = isAdminUser
if ($global:isAdmin) {
    Write-ProfileMsg '⚡ Administrator' -Color Cyan
}
```

With:

```powershell
function global:Test-AdminRole {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$Global:IsAdmin = Test-AdminRole
if ($Global:IsAdmin) {
    Write-ProfileMsg '⚡ Administrator' -Color Cyan
}
```

- [ ] **Update** the reference in `Update-AllModules`. Find:

```powershell
        if ($scope -eq 'AllUsers' -and -not $global:isAdmin) {
```

Replace with:

```powershell
        if ($scope -eq 'AllUsers' -and -not $Global:IsAdmin) {
```

- [ ] **Replace** `New-File` (currently uses positional `$filename` parameter and `Write-Output`):

```powershell
function global:New-File($filename) {
    Write-Output $null | Out-File $filename -Encoding utf8
}
```

With:

```powershell
function global:New-File {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)
    $null | Out-File -FilePath $Name -Encoding utf8
}
```

- [ ] **Replace** `Remove-All` (currently passes `$args` directly, which is untyped):

```powershell
function global:Remove-All {
    Remove-Item -Force -Recurse $args
}
```

With:

```powershell
function global:Remove-All {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Path)
    Remove-Item -Force -Recurse @Path
}
```

- [ ] **Replace** `Get-PubIP` (currently has no error handling and uses http):

```powershell
function global:Get-PubIP {
    (Invoke-WebRequest http://ifconfig.me/ip).Content
}
```

With:

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

- [ ] **Replace** `Copy-SSHID` (currently uses positional `$dest`, `Write-Host $_` in catch):

```powershell
function global:Copy-SSHID($dest) {
    try {
        Get-Content $Env:USERPROFILE\.ssh\id_rsa.pub | ssh $dest 'mkdir ~/.ssh; cat >> ~/.ssh/authorized_keys'
    } catch {
        Write-Warning "Error copying key to $dest"
        Write-Host $_
    }
}
```

With:

```powershell
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

- [ ] **Verify** by dot-sourcing:

```powershell
. .\ProfileModules\Functions.ps1
Get-Command Test-AdminRole   # must resolve
$Global:IsAdmin              # $true or $false
# Old name must be gone:
Get-Command isAdminUser -ErrorAction Ignore   # must be null
```

---

## Task 3: Clean up PSReadline.ps1

**Files:** Modify `ProfileModules/PSReadline.ps1`

- [ ] **Delete** `$catppuccinSyntaxTheme2` — find and remove the entire hashtable from its opening `$catppuccinSyntaxTheme2 = @{` to its closing `}` (approximately 16 lines including blank line before it).

- [ ] **Delete** `$catppuccinSyntaxTheme3` — same, remove the entire hashtable (approximately 16 lines).

- [ ] **Merge** the two `Set-PSReadLineOption` calls at the top of the file. Find:

```powershell
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
```

Replace with:

```powershell
Set-PSReadLineOption -EditMode Windows -HistorySearchCursorMovesToEnd
```

- [ ] **Remove** the `New-Item` call for the XDG state directory (it was moved to Env.ps1 in Task 1). Find and delete this line:

```powershell
New-Item -ItemType Directory -Force -Path $Env:XDG_STATE_HOME | Out-Null
```

- [ ] **Consolidate** the history `Set-PSReadLineOption` calls at the bottom. Find:

```powershell
$_psHistoryPath = Join-Path $Env:XDG_STATE_HOME 'ps_history.txt'
Set-PSReadLineOption -HistorySavePath   $_psHistoryPath
Set-PSReadLineOption -MaximumHistoryCount 10000
Set-PSReadLineOption -HistoryNoDuplicates $true
```

Replace with (the comment above these lines — `# History — XDG path...` — can stay):

```powershell
Set-PSReadLineOption -HistorySavePath     (Join-Path $Env:XDG_STATE_HOME 'ps_history.txt') `
                     -MaximumHistoryCount 10000 `
                     -HistoryNoDuplicates $true
```

- [ ] **Verify** the file has no reference to `catppuccinSyntaxTheme2` or `catppuccinSyntaxTheme3`:

```powershell
Select-String 'catppuccinSyntaxTheme2|catppuccinSyntaxTheme3' .\ProfileModules\PSReadline.ps1
# Must return nothing
```

---

## Task 4: Commit 1 and verify

- [ ] **Reload** the profile to confirm all 3 files work together:

```powershell
. $PROFILE
```

Expected: no errors, prompt loads normally.

- [ ] **Check** key assertions:

```powershell
# Helpers
Get-Command Test-AdminRole
$Global:IsAdmin                                    # $true or $false
(Get-PSReadLineOption).HistorySavePath             # ends in ps_history.txt
(Get-PSReadLineOption).MaximumHistoryCount         # 10000

# Dead theme vars are gone
Get-Variable catppuccinSyntaxTheme2 -ErrorAction Ignore   # null
Get-Variable catppuccinSyntaxTheme3 -ErrorAction Ignore   # null

# PATH has no duplicates
$Env:Path -split ';' | Group-Object | Where-Object Count -gt 1   # empty

# EAP is still Continue (not touched in commit 1, but confirm baseline)
$ErrorActionPreference   # Continue
```

- [ ] **Commit:**

```powershell
git add ProfileModules/Env.ps1 ProfileModules/Functions.ps1 ProfileModules/PSReadline.ps1
git commit -m "refactor: infrastructure polish — Add-ToPath helper, naming, dead code

- Env.ps1: add Add-ToPath (normalized, dedup, Prepend switch); replace 4 PATH
  blocks; move XDG state dir creation here from PSReadline.ps1
- Functions.ps1: Test-AdminRole (was isAdminUser); \$Global:IsAdmin (was
  \$global:isAdmin); proper param blocks on New-File/Remove-All/Copy-SSHID/
  Get-PubIP; https + error handling on Get-PubIP
- PSReadline.ps1: delete unused catppuccinSyntaxTheme2/3; consolidate
  Set-PSReadLineOption calls

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 5: cli_tools_config.ps1 — Framework fixes

**Files:** Modify `ProfileModules/cli_tools_config.ps1`

- [ ] **Remove** the `$ErrorActionPreference = 'Stop'` line (line 5). This file is dot-sourced, so setting EAP here overwrites the caller's global setting for the entire shell session. Delete only this line:

```powershell
$ErrorActionPreference = 'Stop'
```

- [ ] **Add** `Ensure-Dir` helper after the closing `# ────` separator that follows `_GetCachedCompletion`. Insert immediately before the `# ====` Group 1 separator:

```powershell
function script:Ensure-Dir {
    param([string]$Path)
    if ($Path) { New-Item -ItemType Directory -Force -Path $Path -ErrorAction SilentlyContinue | Out-Null }
}
```

- [ ] **Fix `#region bat`** — restructure so `Join-Files` is inside the guard and the `Get-Command bat.exe` check only happens once at profile load (not on every `cat` invocation). Replace the entire `#region bat ... #endregion bat` block with:

```powershell
#region bat  -  modern cat replacement
if (_HasCmd 'bat') {
    # --- XDG / Config paths ---
    $Env:BAT_CONFIG_PATH = Join-Path $Env:XDG_CONFIG_HOME 'bat' 'bat.conf'
    # --- Completers ---
    Register-ArgumentCompleter -Native -CommandName bat -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $flags = @(
            '--language', '--theme', '--style', '--paging', '--color',
            '--line-range', '--highlight-line', '--diff', '--show-all',
            '--plain', '--number', '--decorations', '--italic-text',
            '--tabs', '--wrap', '--terminal-width', '--map-syntax',
            '--list-languages', '--list-themes'
        )
        $flags | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
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

- [ ] **Fix `#region eza`** — remove the closure-capturing `$eza` variable. Find:

```powershell
    $eza = (Get-Command eza.exe).Path.ToString()
    function global:_ls { & $eza --color=auto --icons --group-directories-first @args }
    function global:_ll { & $eza --all --long --header @args }
    function global:_la { & $eza --all --group @args }
    function global:_tree { & $eza --tree @args }
```

Replace with:

```powershell
    function global:_ls   { eza --color=auto --icons --group-directories-first @args }
    function global:_ll   { eza --all --long --header @args }
    function global:_la   { eza --all --group @args }
    function global:_tree { eza --tree @args }
```

- [ ] **Fix `#region glazewm`** — remove the closure-capturing `$wm` variable. Find:

```powershell
function global:Start-GlazeWM {
    $wm = (Get-Command glazewm.exe).Path.ToString()
    $glaze_config = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'glazewm' 'config.yaml'
    & $wm --config=$glaze_config $args
}
```

Replace with:

```powershell
function global:Start-GlazeWM {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    glazewm --config (Join-Path $Env:XDG_CONFIG_HOME 'glazewm' 'config.yaml') @Arguments
}
```

- [ ] **Verify** by reloading the profile:

```powershell
. $PROFILE
Get-Alias cat                # → Join-Files
Get-Command Join-Files       # resolves
$ErrorActionPreference       # Continue  ← was Stop before this task
```

---

## Task 6: cli_tools_config.ps1 — Replace TOCTOU patterns and add CmdletBinding to one-liners

**Files:** Modify `ProfileModules/cli_tools_config.ps1`

- [ ] **Replace all remaining `New-Item -ItemType Directory -Force`** calls with `Ensure-Dir`. Go through the file and apply each substitution below.

  **broot** — find:
  ```powershell
  New-Item -ItemType Directory -Force -Path $brootConfig | Out-Null
  ```
  Replace with: `Ensure-Dir $brootConfig`

  **ripgrep** — find the TOCTOU block:
  ```powershell
  $ripgrepDir = Join-Path $Env:XDG_CONFIG_HOME 'ripgrep'
  if (-not (Test-Path $ripgrepDir)) {
      New-Item -ItemType Directory -Force -Path $ripgrepDir | Out-Null
      Set-Content -Path $Env:RIPGREP_CONFIG_PATH -Value "# ripgrep config`n--smart-case`n--hidden" -Encoding UTF8
  }
  ```
  Replace with (directory always ensured; config file created only if absent):
  ```powershell
  Ensure-Dir (Join-Path $Env:XDG_CONFIG_HOME 'ripgrep')
  if (-not (Test-Path $Env:RIPGREP_CONFIG_PATH)) {
      Set-Content -Path $Env:RIPGREP_CONFIG_PATH -Value "# ripgrep config`n--smart-case`n--hidden" -Encoding UTF8
  }
  ```

  **glow** — find:
  ```powershell
  New-Item -ItemType Directory -Force -Path $Env:GLOW_CONFIG_DIR | Out-Null
  ```
  Replace with: `Ensure-Dir $Env:GLOW_CONFIG_DIR`

  **curl** — find:
  ```powershell
  New-Item -ItemType Directory -Force -Path $Env:CURL_HOME | Out-Null
  ```
  Replace with: `Ensure-Dir $Env:CURL_HOME`

  **wget** — find the TOCTOU block:
  ```powershell
  $wgetDir = Join-Path $Env:XDG_CONFIG_HOME 'wget'
  if (-not (Test-Path $wgetDir)) {
      New-Item -ItemType Directory -Force -Path $wgetDir | Out-Null
      New-Item -ItemType File -Force -Path $Env:WGETRC | Out-Null
  }
  ```
  Replace with:
  ```powershell
  Ensure-Dir (Join-Path $Env:XDG_CONFIG_HOME 'wget')
  $null = New-Item -ItemType File -Force -Path $Env:WGETRC -ErrorAction SilentlyContinue
  ```

  **docker** — find:
  ```powershell
  New-Item -ItemType Directory -Force -Path $Env:DOCKER_CONFIG | Out-Null
  ```
  Replace with: `Ensure-Dir $Env:DOCKER_CONFIG`

  **nano** — find the TOCTOU block:
  ```powershell
  $nanoDir = Join-Path $Env:XDG_CONFIG_HOME 'nano'
  if (-not (Test-Path $nanoDir)) {
      New-Item -ItemType Directory -Force -Path $nanoDir | Out-Null
      New-Item -ItemType File -Force -Path $Env:NANORC | Out-Null
  }
  ```
  Replace with:
  ```powershell
  Ensure-Dir (Join-Path $Env:XDG_CONFIG_HOME 'nano')
  $null = New-Item -ItemType File -Force -Path $Env:NANORC -ErrorAction SilentlyContinue
  ```

  **micro** — find:
  ```powershell
  New-Item -ItemType Directory -Force -Path $Env:MICRO_CONF_DIR | Out-Null
  ```
  Replace with: `Ensure-Dir $Env:MICRO_CONF_DIR`

  **less** — find:
  ```powershell
  New-Item -ItemType Directory -Force -Path $lessStateDir  | Out-Null
  New-Item -ItemType Directory -Force -Path $lessConfigDir | Out-Null
  ```
  Replace with:
  ```powershell
  Ensure-Dir $lessStateDir
  Ensure-Dir $lessConfigDir
  ```

  **winfetch** — find the TOCTOU block:
  ```powershell
  $winfetchDir = Join-Path $Env:XDG_CONFIG_HOME 'winfetch'
  if (-not (Test-Path $winfetchDir)) {
      New-Item -ItemType Directory -Force -Path $winfetchDir | Out-Null
  }
  ```
  Replace with: `Ensure-Dir (Join-Path $Env:XDG_CONFIG_HOME 'winfetch')`

  **npm** — find the TOCTOU block:
  ```powershell
  $npmConfigDir = Join-Path $Env:XDG_CONFIG_HOME 'npm'
  if (-not (Test-Path $npmConfigDir)) {
      New-Item -ItemType Directory -Force -Path $npmConfigDir | Out-Null
  }
  ```
  Replace with: `Ensure-Dir (Join-Path $Env:XDG_CONFIG_HOME 'npm')`

  **lazygit** — find:
  ```powershell
  New-Item -ItemType Directory -Force -Path (Split-Path $Env:LG_CONFIG_FILE) | Out-Null
  ```
  Replace with: `Ensure-Dir (Split-Path $Env:LG_CONFIG_FILE)`

  **chezmoi** — find:
  ```powershell
  New-Item -ItemType Directory -Force -Path $Env:CHEZMOI_CONFIG_DIR | Out-Null
  ```
  Replace with: `Ensure-Dir $Env:CHEZMOI_CONFIG_DIR`

  **uv** — find:
  ```powershell
  New-Item -ItemType Directory -Force -Path $Env:UV_CACHE_DIR | Out-Null
  New-Item -ItemType Directory -Force -Path $Env:UV_DATA_DIR  | Out-Null
  ```
  Replace with:
  ```powershell
  Ensure-Dir $Env:UV_CACHE_DIR
  Ensure-Dir $Env:UV_DATA_DIR
  ```

- [ ] **Add `[CmdletBinding()]` and `param()` to one-liner functions** in the scoop and winget regions.

  Find `function global:sstat { scoop update; scoop status }` and replace with:
  ```powershell
  function global:sstat {
      [CmdletBinding()]
      param()
      scoop update; scoop status
  }
  ```

  Find `function global:supd { scoop update *; scoop cleanup * }` and replace with:
  ```powershell
  function global:supd {
      [CmdletBinding()]
      param()
      scoop update *; scoop cleanup *
  }
  ```

  Find `function global:wstat { winget upgrade }` and replace with:
  ```powershell
  function global:wstat {
      [CmdletBinding()]
      param()
      winget upgrade
  }
  ```

  Find `function global:wupd { winget upgrade --all }` and replace with:
  ```powershell
  function global:wupd {
      [CmdletBinding()]
      param()
      winget upgrade --all
  }
  ```

  Find `function global:nls { npm list -g --depth=0 }` and replace with:
  ```powershell
  function global:nls {
      [CmdletBinding()]
      param()
      npm list -g --depth=0
  }
  ```

- [ ] **Verify** by reloading and confirming no directory-creation errors:

```powershell
. $PROFILE
# Should print nothing — no errors from Ensure-Dir calls
Get-Command sstat, supd, wstat, wupd, nls   # all resolve
```

---

## Task 7: fzf Tier 1 — Standardize file/code preview pickers to right:60%

**Files:** Modify `ProfileModules/cli_tools_config.ps1`

Each change below is a single `--preview-window` string replacement. Make them one at a time.

- [ ] **`ff` (Select-File):** `--preview-window 'right:55%'` → `--preview-window 'right:60%'`

- [ ] **`ffd` (Select-FdResult):** `--preview-window 'right:50%'` → `--preview-window 'right:60%'`

- [ ] **`frg` (Select-RipgrepResult):** Two changes:
  1. `--preview-window 'right:55%'` → `--preview-window 'right:60%'`
  2. Fix header — find:
     ```powershell
     --header 'Select result (Enter to open in $EDITOR)'
     ```
     Replace with:
     ```powershell
     --header 'Select result  [Enter to open in editor]'
     ```

- [ ] **`fcd` (Select-Directory):** `--preview-window 'right:40%'` → `--preview-window 'right:60%'`

- [ ] **`sins` (Select-ScoopPackage):** `--preview-window 'right:45%'` → `--preview-window 'right:60%'`

- [ ] **`czf` (Edit-DotFile):** `--preview-window 'right:55%'` → `--preview-window 'right:60%'`

- [ ] **`fco` (Select-GitBranch):** `--preview-window 'right:55%'` → `--preview-window 'right:60%'`

- [ ] **`flog` (Select-GitLog):** `--preview-window 'right:55%'` → `--preview-window 'right:60%'`

- [ ] **`fga` (Select-GitFile):** `--preview-window 'right:55%'` → `--preview-window 'right:60%'`

- [ ] **`fstash` (Select-GitStash):** Two changes:
  1. `--preview-window 'right:55%'` → `--preview-window 'right:60%'`
  2. Add `--ansi` flag to the fzf call (git stash show -p outputs ANSI color). The fzf invocation currently starts with `fzf --preview`. Change to `fzf --ansi --preview`.

- [ ] **`fvenv` (Select-UvVenv):** `--preview-window 'right:40%'` → `--preview-window 'right:60%'`

- [ ] **Verify** — `fgl` (Read-MarkdownFile) is already `right:60%`, confirm it's unchanged:

```powershell
Select-String 'right:60' .\ProfileModules\cli_tools_config.ps1 | Measure-Object
# Count should be 12 (fgl was already 60, plus the 11 we just changed)
Select-String 'right:5[05]%|right:4[05]%' .\ProfileModules\cli_tools_config.ps1
# Should return nothing — all old widths replaced
```

---

## Task 8: fzf Tier 2 — Add `--preview-window 'hidden'` to list-only pickers

**Files:** Modify `ProfileModules/cli_tools_config.ps1`

For each picker below, find its `fzf` invocation and add `--preview-window 'hidden'` as the last flag before any `--header`.

- [ ] **`fdc` (Select-DockerContainer):** The fzf call currently is:
  ```powershell
  fzf --header 'Select container (Enter to exec shell)'
  ```
  Change to:
  ```powershell
  fzf --preview-window 'hidden' `
      --header 'Select container (Enter to exec shell)'
  ```

- [ ] **`fdi` (Select-DockerImage):** The fzf call currently is:
  ```powershell
  fzf --header 'Select image'
  ```
  Change to:
  ```powershell
  fzf --preview-window 'hidden' `
      --header 'Select image'
  ```

- [ ] **`fns` (Select-NpmScript):** The fzf call currently is:
  ```powershell
  $script = $scripts | fzf --header 'Select npm script (Enter to npm run)'
  ```
  Change to:
  ```powershell
  $script = $scripts | fzf --preview-window 'hidden' `
      --header 'Select npm script (Enter to npm run)'
  ```

- [ ] **`frtc` (Select-RustupToolchain):** The fzf call currently is:
  ```powershell
  fzf --header 'Select Rust toolchain (Enter to rustup default)'
  ```
  Change to:
  ```powershell
  fzf --preview-window 'hidden' `
      --header 'Select Rust toolchain (Enter to rustup default)'
  ```

- [ ] **`fnv` (Select-NodeVersion):** The fzf call currently is:
  ```powershell
  fzf --header 'Select Node.js version (Enter to nvm use)'
  ```
  Change to:
  ```powershell
  fzf --preview-window 'hidden' `
      --header 'Select Node.js version (Enter to nvm use)'
  ```

- [ ] **`fpr` (Select-GHPr):** The fzf call currently is:
  ```powershell
  fzf --header 'Select PR to checkout' --delimiter "`t" --with-nth '1,2'
  ```
  Change to:
  ```powershell
  fzf --preview-window 'hidden' `
      --header 'Select PR to checkout' --delimiter "`t" --with-nth '1,2'
  ```

- [ ] **`fgi` (Select-GHIssue):** The fzf call currently is:
  ```powershell
  fzf --header 'Select issue to view' --delimiter "`t" --with-nth '1,2'
  ```
  Change to:
  ```powershell
  fzf --preview-window 'hidden' `
      --header 'Select issue to view' --delimiter "`t" --with-nth '1,2'
  ```

- [ ] **`fbw` (Select-BwItem):** The fzf call currently is:
  ```powershell
  fzf --delimiter "`t" --with-nth 1 `
      --header 'Select vault item (Enter to copy password)'
  ```
  Change to:
  ```powershell
  fzf --delimiter "`t" --with-nth 1 `
      --preview-window 'hidden' `
      --header 'Select vault item (Enter to copy password)'
  ```

- [ ] **Verify** hidden count:

```powershell
Select-String "'hidden'" .\ProfileModules\cli_tools_config.ps1 | Measure-Object
# Count should be 9 (fkill was already hidden; 8 new ones added here)
```

---

## Task 9: fzf specific fixes — GHIssue redundancy

**Files:** Modify `ProfileModules/cli_tools_config.ps1`

- [ ] **Fix `Select-GHIssue`** — the function adds a `#` prefix to the issue number then strips it when parsing. Remove both. Find:

```powershell
        $issue = gh issue list --json number,title,assignees,state 2>$null |
            ConvertFrom-Json |
            ForEach-Object { "#$($_.number)`t$($_.title)" } |
```

Replace with:

```powershell
        $issue = gh issue list --json number,title,assignees,state 2>$null |
            ConvertFrom-Json |
            ForEach-Object { "$($_.number)`t$($_.title)" } |
```

- [ ] Find and update the parsing line immediately after the fzf result:

```powershell
            $num = ($issue -split "`t")[0].TrimStart('#').Trim()
```

Replace with:

```powershell
            $num = ($issue -split "`t")[0].Trim()
```

- [ ] **Verify** by checking the function body has no `#` in the format string and no `TrimStart`:

```powershell
Select-String 'TrimStart' .\ProfileModules\cli_tools_config.ps1
# Should return nothing
```

---

## Task 10: Dead code and empty stubs

**Files:** Modify `ProfileModules/cli_tools_config.ps1`

- [ ] **Delete `#region lsd`** entirely. The comment inside already says "NOTE: lsd conflicts with eza; enable only if eza is removed." Find and remove:

```powershell
#region lsd  -  another ls alternative
# NOTE: lsd conflicts with eza; enable only if eza is removed
if (_HasCmd 'lsd') {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion lsd
```

- [ ] **Convert 13 empty stub sections** to lean placeholder comments. For each of the following regions, replace the entire `if (_HasCmd/HasMod ...) { # TODO ... }` body with `# not yet configured`. The `#region` and `#endregion` lines stay.

  Regions to convert: `fx`, `jid`, `duf`, `dua`, `gdu`, `ntop`, `moor`, `win32yank`, `gemini`, `scoop-completion`, `PSAISuite`, `PSWindowsUpdate`, `Admin`

  **Template** — before:
  ```powershell
  #region duf  -  modern df replacement
  if (_HasCmd 'duf') {
      # TODO: XDG / Config paths
      # TODO: Functions / Aliases
      # TODO: Completers
      # TODO: Fzf Pickers
  }
  #endregion duf
  ```

  After:
  ```powershell
  #region duf  -  modern df replacement
  # not yet configured
  #endregion duf
  ```

  Apply the same pattern to all 13 stubs. Exact content varies slightly (some have `_HasMod`), but the result is the same: remove the if-block, leave just the placeholder comment.

- [ ] **Verify** no empty if-blocks remain for these tools:

```powershell
Select-String '#region (fx|jid|duf|dua|gdu|ntop|moor|win32yank|gemini|scoop-completion|PSAISuite|PSWindowsUpdate|Admin)' `
    .\ProfileModules\cli_tools_config.ps1 -AllMatches |
    ForEach-Object { $_.Line }
# Each should be followed only by '# not yet configured' and '#endregion'
```

---

## Task 11: Commit 2 and full verification

- [ ] **Reload** the profile:

```powershell
. $PROFILE
```

Expected: no errors.

- [ ] **Run full verification suite:**

```powershell
# EAP is Continue (not Stop — the dot-source bug is fixed)
$ErrorActionPreference   # Continue

# All fzf pickers resolve
Get-Command ff, fcd, fco, flog, fga, fstash, sins, srm, wins, wrm,
            frg, ffd, fjq, fkill, czf, fbw, fnv, fns, frtc, fvenv,
            fgl, fpot, fpr, fgi, fdc, fdi, lg

# cat/Join-Files
Get-Alias cat              # → Join-Files
Get-Command Join-Files     # resolves

# Naming
Get-Command Test-AdminRole
$Global:IsAdmin            # $true or $false

# Dead code is gone
Get-Variable catppuccinSyntaxTheme2 -ErrorAction Ignore   # null
Get-Variable catppuccinSyntaxTheme3 -ErrorAction Ignore   # null

# fzf preview consistency — all Tier 1 pickers at 60%
Select-String "right:5[05]%|right:4[05]%" .\ProfileModules\cli_tools_config.ps1
# Must return nothing

# Hidden preview count (9 total: fkill original + 8 new)
(Select-String "'hidden'" .\ProfileModules\cli_tools_config.ps1).Count   # 9

# No TrimStart in GH issue picker
Select-String 'TrimStart' .\ProfileModules\cli_tools_config.ps1   # nothing
```

- [ ] **Commit:**

```powershell
git add ProfileModules/cli_tools_config.ps1
git commit -m "refactor: cli_tools_config polish — helpers, fzf consistency, dead code

- Remove \$ErrorActionPreference = 'Stop' (dot-sourced file, leaked to global scope)
- Add Ensure-Dir helper; replace 14 New-Item dir calls and 5 TOCTOU patterns
- Fix #region bat: Join-Files defined in if/else, Get-Command runs once at load
- Remove closure-captured \$eza and \$wm path vars (call binaries directly)
- Add [CmdletBinding()]/param() to sstat, supd, wstat, wupd, nls
- fzf: standardize 11 Tier-1 pickers to right:60% preview window
- fzf: add --preview-window 'hidden' to 8 list-only pickers
- fzf: fix fstash --ansi; fix frg header; fix fgi # redundancy
- Delete #region lsd (conflicts with eza); convert 13 empty stubs to comments

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

- [ ] **Push** to GitHub:

```powershell
git push
```

---

## Self-Review Notes

- **Spec coverage:** All sections covered. Add-ToPath ✓, Ensure-Dir ✓, Test-AdminRole ✓, EAP bug fix ✓, Join-Files restructure ✓, path captures ✓, TOCTOU ✓, CmdletBinding one-liners ✓, all 22 fzf pickers ✓, dead code ✓
- **No placeholders:** All steps contain exact code, no "implement later" language
- **Type consistency:** `$Global:IsAdmin` used consistently in Tasks 2 and 4; `Ensure-Dir` defined in Task 5 before first use in Task 6; `Add-ToPath` defined in Task 1 before use in same task
- **Verification after every task:** Each task has a verification step before the next task begins
