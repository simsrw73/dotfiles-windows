#Requires -Version 7.0

#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module

Import-Module -Name Microsoft.WinGet.CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58

# rustup tab completions
if (Get-Command rustup.exe -ErrorAction SilentlyContinue) {
    rustup completions powershell | Out-String | Invoke-Expression
}

# scoop-search hook
. ([ScriptBlock]::Create((& scoop-search --hook | Out-String)))

# PSFzf
Set-PsFzfOption -EnableFd

Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' `
    -PSReadlineChordReverseHistory 'Ctrl+r'

$commandOverride = [ScriptBlock] { param($Location) Set-Location $Location }
Set-PsFzfOption -AltCCommand $commandOverride

Set-PsFzfOption -EnableAliasFuzzyScoop
Set-PsFzfOption -TabExpansion
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }

# zoxide (requires $Env:_ZO_DATA_DIR set in Env.ps1)
Invoke-Expression (& {
    $hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
    (zoxide init --hook $hook powershell | Out-String)
})
