#Requires -Version 7.0

Remove-Alias -Name r -Force -Scope Global -ErrorAction SilentlyContinue

Set-Alias -Name printenv    -Value Show-Environment -Scope Global
Set-Alias -Name printpath   -Value Show-Path        -Scope Global
Set-Alias -Name touch       -Value New-File         -Scope Global
Set-Alias -Name rmrf        -Value Remove-All       -Scope Global
Set-Alias -Name ssh-copy-id -Value Copy-SSHID       -Scope Global

# Note: ls/ll/la/tree aliases are set in Functions.ps1 alongside the eza function definitions
