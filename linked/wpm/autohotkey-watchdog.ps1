<#
.SYNOPSIS
    Keeps the primary AutoHotkey script running across PID-changing reloads.

.DESCRIPTION
    wpm supervises this script. This watchdog finds the AutoHotkey process by
    its script argument rather than PID, so normal AutoHotkey reloads are
    accepted without creating a duplicate instance.
#>
param(
    [string] $AutoHotkeyExe = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64_UIA.exe',
    [string] $ScriptPath = 'C:\Users\simsr\.config\autohotkey\autohotkey.ahk',
    [int] $IntervalSec = 5,
    [int] $MissingGraceSec = 5,
    [string] $PauseFile = (Join-Path $env:LOCALAPPDATA 'wpm\autohotkey-watchdog.pause'),
    [switch] $NoRun
)

$ErrorActionPreference = 'Stop'
$script:CanonicalScriptPath = [IO.Path]::GetFullPath($ScriptPath)

function Write-WatchdogLog([string] $Message) {
    Write-Output ('{0:yyyy-MM-ddTHH:mm:ss} {1}' -f (Get-Date), $Message)
}

function Get-ManagedAutoHotkeyProcess {
    @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'AutoHotkey64_UIA.exe'" |
        Where-Object {
            $_.CommandLine -and
            $_.CommandLine.IndexOf($script:CanonicalScriptPath, [StringComparison]::OrdinalIgnoreCase) -ge 0
        })
}

function Start-ManagedAutoHotkey([switch] $DryRun) {
    if (-not (Test-Path -LiteralPath $AutoHotkeyExe)) {
        throw "AutoHotkey executable not found: $AutoHotkeyExe"
    }
    if (-not (Test-Path -LiteralPath $script:CanonicalScriptPath)) {
        throw "AutoHotkey script not found: $script:CanonicalScriptPath"
    }

    if (-not $DryRun) {
        Start-Process -FilePath $AutoHotkeyExe -ArgumentList @($script:CanonicalScriptPath) -WorkingDirectory (Split-Path -Parent $script:CanonicalScriptPath)
    }
}

function Invoke-AutoHotkeyWatchdogCheck {
    param(
        [Nullable[datetime]] $MissingSince,
        [switch] $Initial,
        [switch] $DryRun
    )

    if (Test-Path -LiteralPath $PauseFile) {
        return [pscustomobject]@{ Action = 'paused'; MissingSince = $null }
    }

    $procs = @(Get-ManagedAutoHotkeyProcess)
    if ($procs.Count -gt 0) {
        return [pscustomobject]@{
            Action = 'healthy'
            MissingSince = $null
            Pids = @($procs.ProcessId)
        }
    }

    if ($Initial -or -not $MissingSince -or
        ((Get-Date) - $MissingSince).TotalSeconds -ge $MissingGraceSec) {
        Start-ManagedAutoHotkey -DryRun:$DryRun
        return [pscustomobject]@{ Action = 'start'; MissingSince = Get-Date }
    }

    [pscustomobject]@{ Action = 'wait'; MissingSince = $MissingSince }
}

if ($NoRun) {
    return
}

Write-WatchdogLog "watching $script:CanonicalScriptPath (interval ${IntervalSec}s, missing grace ${MissingGraceSec}s)"
$missingSince = $null
$initial = $true
$paused = $false

while ($true) {
    $result = Invoke-AutoHotkeyWatchdogCheck -MissingSince $missingSince -Initial:$initial
    if ($result.Action -eq 'healthy' -and $initial) {
        Write-WatchdogLog "managed script already running (PID $($result.Pids -join ', '))"
    }
    elseif ($result.Action -eq 'start') {
        Write-WatchdogLog "starting $script:CanonicalScriptPath"
    }
    elseif ($result.Action -eq 'paused' -and -not $paused) {
        Write-WatchdogLog 'paused'
        $paused = $true
    }
    elseif ($paused -and $result.Action -ne 'paused') {
        Write-WatchdogLog 'resumed'
        $paused = $false
    }

    $missingSince = $result.MissingSince
    $initial = $false
    Start-Sleep -Seconds $IntervalSec
}
