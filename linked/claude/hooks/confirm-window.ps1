#Requires -Version 7
<#
PreToolUse hook: before Claude runs a shell command that opens a window (AutoHotkey
scripts, Start-Process, GUI apps), ask first so you can stop typing. Cancel is the
default button, so a stray Enter or Space while you are typing cancels instead of
confirming. Headless runs (AHK /Validate, test runners) are not asked about.
#>
$ErrorActionPreference = 'Stop'
$payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
$cmd = [string]$payload.tool_input.command
if (-not $cmd) { exit 0 }

$opensWindow = '(?i)AutoHotkey(64|32|_UIA)?\.exe|Start-Process|Invoke-Item|(^|[;&|(]\s*)(ii|start|explorer|notepad|mspaint)(\.exe)?\s'
$headless = '(?i)/Validate\b|Run-Tests\.ps1|Verify-AutoHotkeyStructure\.ps1'
if ($cmd -notmatch $opensWindow -or $cmd -match $headless) { exit 0 }

Add-Type -AssemblyName System.Windows.Forms
$preview = if ($cmd.Length -gt 400) { $cmd.Substring(0, 400) + ' …' } else { $cmd }
$owner = [System.Windows.Forms.Form]@{ TopMost = $true; ShowInTaskbar = $false; Opacity = 0 }
$owner.Show()
$answer = [System.Windows.Forms.MessageBox]::Show($owner,
    "Claude is about to run a command that opens a window.`n`nStop typing, then click OK to let it run (Cancel blocks it).`n`n$preview",
    'Claude: window coming up',
    [System.Windows.Forms.MessageBoxButtons]::OKCancel,
    [System.Windows.Forms.MessageBoxIcon]::Warning,
    [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
$owner.Dispose()

if ($answer -ne [System.Windows.Forms.DialogResult]::OK) {
    @{ hookSpecificOutput = @{
        hookEventName = 'PreToolUse'
        permissionDecision = 'deny'
        permissionDecisionReason = 'The user cancelled: not ready for a window to open. Ask before trying again.'
    } } | ConvertTo-Json -Depth 3 -Compress
}
exit 0
