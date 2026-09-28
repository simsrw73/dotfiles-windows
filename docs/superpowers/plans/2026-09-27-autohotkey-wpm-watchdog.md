# AutoHotkey wpm Watchdog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Start the primary AutoHotkey v2 script at interactive logon, restart it after exit, and preserve supervision across PID-changing reloads.

**Architecture:** wpm starts and restarts a persistent PowerShell watchdog; the watchdog owns the script by canonical command-line argument rather than PID. A matching AutoHotkey process is healthy even when it has a replacement PID.

**Tech Stack:** wpm TOML, PowerShell 7, Pester 6, Win32_Process CIM, AutoHotkey v2.

## Global Constraints

- Manage `C:\Users\simsr\.config\autohotkey\autohotkey.ahk` through `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`.
- Never identify the script by PID; do not add hung-process detection.
- Do not remove the Startup shortcut until the running unit is verified.
- Use the existing interactive-logon `wpmd` task; do not add a boot-time task.

---

## File structure

| Path | Responsibility |
| --- | --- |
| `linked/wpm/autohotkey-watchdog.ps1` | Detect, start, pause, and log management of the script. |
| `linked/wpm/autohotkey-watchdog.toml` | Start and restart the watchdog with wpm. |
| `linked/wpm/tests/AutoHotkeyWatchdog.Tests.ps1` | Pester behavior tests. |
| `linked/wpm/README.md` | Installation, reload, and pause instructions. |

### Task 1: Build the reload-safe watchdog

**Files:**
- Create: `linked/wpm/autohotkey-watchdog.ps1`
- Create: `linked/wpm/tests/AutoHotkeyWatchdog.Tests.ps1`

**Interfaces:**
- Consumes: `Win32_Process` rows with `Name`, `ProcessId`, and `CommandLine`.
- Produces: `Get-ManagedAutoHotkeyProcess`, `Start-ManagedAutoHotkey`, and `Invoke-AutoHotkeyWatchdogCheck`; `-NoRun` loads functions without the loop.

- [ ] **Step 1: Write failing Pester tests**

```powershell
$watchdog = Join-Path $PSScriptRoot '..\autohotkey-watchdog.ps1'
. $watchdog -NoRun
Describe 'AutoHotkey watchdog' {
    BeforeEach { Mock Get-CimInstance { @() }; Mock Start-Process {} }
    It 'accepts a replacement PID for the same script' {
        Mock Get-CimInstance { @(
            [pscustomobject]@{ Name='AutoHotkey64.exe'; ProcessId=101; CommandLine='"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" "C:\Users\simsr\.config\autohotkey\autohotkey.ahk"' },
            [pscustomobject]@{ Name='AutoHotkey64.exe'; ProcessId=202; CommandLine='"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" "C:\Users\simsr\.config\autohotkey\autohotkey.ahk"' }
        ) }
        (Get-ManagedAutoHotkeyProcess).ProcessId | Should -Be @(101, 202)
    }
    It 'starts immediately when initially absent' {
        (Invoke-AutoHotkeyWatchdogCheck -Initial -DryRun).Action | Should -Be 'start'
    }
    It 'waits during a later missing grace period' {
        (Invoke-AutoHotkeyWatchdogCheck -MissingSince (Get-Date) -DryRun).Action | Should -Be 'wait'
    }
}
```

- [ ] **Step 2: Verify the tests fail**

Run: `Invoke-Pester .\linked\wpm\tests\AutoHotkeyWatchdog.Tests.ps1 -Output Detailed`

Expected: FAIL because the watchdog does not exist.

- [ ] **Step 3: Implement the watchdog**

```powershell
param(
    [string]$AutoHotkeyExe='C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe',
    [string]$ScriptPath='C:\Users\simsr\.config\autohotkey\autohotkey.ahk',
    [int]$IntervalSec=2, [int]$MissingGraceSec=5,
    [string]$PauseFile=(Join-Path $env:LOCALAPPDATA 'wpm\autohotkey-watchdog.pause'),
    [switch]$NoRun
)
$ErrorActionPreference='Stop'
$script:CanonicalScriptPath=[IO.Path]::GetFullPath($ScriptPath)
function Write-WatchdogLog([string]$Message) { Write-Output ('{0:yyyy-MM-ddTHH:mm:ss} {1}' -f (Get-Date),$Message) }
function Get-ManagedAutoHotkeyProcess {
    @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'AutoHotkey64.exe'" | Where-Object {
        $_.CommandLine -and $_.CommandLine.IndexOf($script:CanonicalScriptPath,[StringComparison]::OrdinalIgnoreCase) -ge 0
    })
}
function Start-ManagedAutoHotkey([switch]$DryRun) {
    if(-not (Test-Path -LiteralPath $AutoHotkeyExe)){throw "AutoHotkey executable not found: $AutoHotkeyExe"}
    if(-not (Test-Path -LiteralPath $script:CanonicalScriptPath)){throw "AutoHotkey script not found: $script:CanonicalScriptPath"}
    Write-WatchdogLog "starting $script:CanonicalScriptPath"
    if(-not $DryRun){Start-Process -FilePath $AutoHotkeyExe -ArgumentList @($script:CanonicalScriptPath) -WorkingDirectory (Split-Path -Parent $script:CanonicalScriptPath)}
}
function Invoke-AutoHotkeyWatchdogCheck {
    param([datetime]$MissingSince,[switch]$Initial,[switch]$DryRun)
    if(Test-Path -LiteralPath $PauseFile){return [pscustomobject]@{Action='paused';MissingSince=$null}}
    $procs=@(Get-ManagedAutoHotkeyProcess)
    if($procs.Count){return [pscustomobject]@{Action='healthy';MissingSince=$null;Pids=@($procs.ProcessId)}}
    if($Initial -or -not $MissingSince -or ((Get-Date)-$MissingSince).TotalSeconds -ge $MissingGraceSec){
        Start-ManagedAutoHotkey -DryRun:$DryRun; return [pscustomobject]@{Action='start';MissingSince=Get-Date}
    }
    [pscustomobject]@{Action='wait';MissingSince=$MissingSince}
}
if($NoRun){return}
Write-WatchdogLog "watching $script:CanonicalScriptPath"
$missingSince=$null; $initial=$true
while($true){
    $result=Invoke-AutoHotkeyWatchdogCheck -MissingSince $missingSince -Initial:$initial
    $missingSince=$result.MissingSince; $initial=$false
    Start-Sleep -Seconds $IntervalSec
}
```

- [ ] **Step 4: Verify tests pass**

Run: `Invoke-Pester .\linked\wpm\tests\AutoHotkeyWatchdog.Tests.ps1 -Output Detailed`

Expected: all three tests PASS.

- [ ] **Step 5: Commit**

```powershell
git add linked/wpm/autohotkey-watchdog.ps1 linked/wpm/tests/AutoHotkeyWatchdog.Tests.ps1
git commit -m "feat: add reload-safe AutoHotkey watchdog"
```

### Task 2: Add the unit and documentation

**Files:**
- Create: `linked/wpm/autohotkey-watchdog.toml`
- Modify: `linked/wpm/README.md`

**Interfaces:**
- Consumes: the watchdog through `powershell.exe -File`.
- Produces: a unit managed by `wpmctl start|stop|status|log autohotkey-watchdog`.

- [ ] **Step 1: Write a failing configuration assertion**

```powershell
$unit=Get-Content -Raw .\linked\wpm\autohotkey-watchdog.toml -ErrorAction SilentlyContinue
if($unit -notmatch 'Autostart = true' -or $unit -notmatch 'Restart = "Always"'){throw 'AutoHotkey wpm unit is absent or not restartable.'}
if(-not ((Get-Content -Raw .\linked\wpm\README.md) -match 'autohotkey-watchdog')){throw 'README does not document the AutoHotkey unit.'}
```

Expected: FAIL before the unit and documentation are added.

- [ ] **Step 2: Create the unit**

```toml
[Unit]
Name = "autohotkey-watchdog"
Description = "Keeps the primary AutoHotkey script running across reloads"

[Service]
Kind = "Simple"
Autostart = true
Restart = "Always"
RestartSec = 2

[Service.ExecStart]
Executable = "powershell.exe"
Arguments = [
    "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
    "-File", "$USERPROFILE/.config/wpm/autohotkey-watchdog.ps1",
]

[Service.Healthcheck.Process]
DelaySec = 2
```

- [ ] **Step 3: Document operation**

Add the two files to the README table. Document `wpmctl reload`, `wpmctl start autohotkey-watchdog`, and `wpmctl log autohotkey-watchdog`; document the pause file `%LOCALAPPDATA%\wpm\autohotkey-watchdog.pause`; state that PID-changing script reloads are supported because matching uses the script command line; state that the Startup shortcut is removed only after verification.

- [ ] **Step 4: Validate**

```powershell
$unit=Get-Content -Raw .\linked\wpm\autohotkey-watchdog.toml
if($unit -notmatch 'Autostart = true' -or $unit -notmatch 'Restart = "Always"'){throw 'AutoHotkey wpm unit is absent or not restartable.'}
if(-not ((Get-Content -Raw .\linked\wpm\README.md) -match 'autohotkey-watchdog')){throw 'README does not document the AutoHotkey unit.'}
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\linked\wpm\autohotkey-watchdog.ps1 -NoRun
```

Expected: no assertion failure and PowerShell exits 0.

- [ ] **Step 5: Commit**

```powershell
git add linked/wpm/autohotkey-watchdog.toml linked/wpm/README.md
git commit -m "feat: manage AutoHotkey with wpm"
```

### Task 3: Activate and remove duplicate startup

**Files:**
- Delete: `C:\Users\simsr\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\autohotkey.ahk.lnk`

- [ ] **Step 1: Load and start the unit**

```powershell
wpmctl reload
wpmctl start autohotkey-watchdog
wpmctl status autohotkey-watchdog
```

Expected: status reports running.

- [ ] **Step 2: Verify reload-safe ownership**

```powershell
wpmctl log autohotkey-watchdog
Get-CimInstance Win32_Process -Filter "Name = 'AutoHotkey64.exe'" | Where-Object CommandLine -match [regex]::Escape('C:\Users\simsr\.config\autohotkey\autohotkey.ahk') | Select-Object ProcessId,CommandLine
```

Expected: one matching process. Trigger the normal script reload once and repeat the query; a new PID is valid, with the watchdog still running and no duplicate script process.

- [ ] **Step 3: Remove only the confirmed duplicate shortcut**

```powershell
$shortcut='C:\Users\simsr\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\autohotkey.ahk.lnk'
if(-not (Test-Path -LiteralPath $shortcut)){throw "Expected Startup shortcut not found: $shortcut"}
Remove-Item -LiteralPath $shortcut
```

Expected: only the verified AutoHotkey Startup entry is removed.

- [ ] **Step 4: Verify final state**

```powershell
Test-Path -LiteralPath 'C:\Users\simsr\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\autohotkey.ahk.lnk'
wpmctl status autohotkey-watchdog
```

Expected: `False` and a running unit.
