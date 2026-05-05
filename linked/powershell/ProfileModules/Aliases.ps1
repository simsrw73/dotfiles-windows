#Requires -Version 7.0

Remove-Alias -Name r -Force -ErrorAction SilentlyContinue

Set-Alias -Name cz -Value chezmoi

if (Get-Command z -ErrorAction SilentlyContinue) {
    Set-Alias -Name cd -Value z -Option AllScope
}

Set-Alias -Name printenv    -Value Show-Environment
Set-Alias -Name printpath   -Value Show-Path
Set-Alias -Name touch       -Value New-File
Set-Alias -Name rmrf        -Value Remove-All
Set-Alias -Name mqtt        -Value Invoke-MQTT
Set-Alias -Name cat         -Value Join-Files -Force
Set-Alias -Name glazewm     -Value Start-GlazeWM
Set-Alias -Name ssh-copy-id -Value Copy-SSHID

if (Test-Path -Path 'C:\Program Files\Notepad++\notepad++.exe' -PathType Leaf) {
    Set-Alias -Name edit -Value 'C:\Program Files\Notepad++\notepad++.exe'
} else {
    Set-Alias -Name edit -Value 'C:\Windows\system32\notepad.exe'
}

# Note: ls/ll/la/tree aliases are set in Functions.ps1 alongside the eza function definitions
