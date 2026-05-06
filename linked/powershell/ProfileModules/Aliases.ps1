#Requires -Version 7.0

Remove-Alias -Name r -Force -Scope Global -ErrorAction SilentlyContinue

Set-Alias -Name cz -Value chezmoi -Scope Global

if (Get-Command z -ErrorAction SilentlyContinue) {
    Set-Alias -Name cd -Value z -Scope Global -Option AllScope
}

Set-Alias -Name printenv    -Value Show-Environment -Scope Global
Set-Alias -Name printpath   -Value Show-Path        -Scope Global
Set-Alias -Name touch       -Value New-File         -Scope Global
Set-Alias -Name rmrf        -Value Remove-All       -Scope Global
Set-Alias -Name mqtt        -Value Invoke-MQTT      -Scope Global
# cat alias (Join-Files) moved to cli_tools_config.ps1
Set-Alias -Name glazewm     -Value Start-GlazeWM    -Scope Global
Set-Alias -Name ssh-copy-id -Value Copy-SSHID       -Scope Global

if (Test-Path -Path 'C:\Program Files\Notepad++\notepad++.exe' -PathType Leaf) {
    Set-Alias -Name edit -Value 'C:\Program Files\Notepad++\notepad++.exe' -Scope Global
} else {
    Set-Alias -Name edit -Value 'C:\Windows\system32\notepad.exe' -Scope Global
}

# Note: ls/ll/la/tree aliases are set in Functions.ps1 alongside the eza function definitions
