#Requires -Version 7.0

#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module

Import-Module -Name Microsoft.WinGet.CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58

# rustup tab completions
if (Get-Command rustup.exe -ErrorAction SilentlyContinue) {
    rustup completions powershell | Out-String | Invoke-Expression
}

# scoop-search hook moved to cli_tools_config.ps1
# PSFzf moved to cli_tools_config.ps1
# zoxide moved to cli_tools_config.ps1
