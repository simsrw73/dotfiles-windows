#Requires -Version 7.0

Remove-Alias -Name r -Force -Scope Global -ErrorAction SilentlyContinue

Set-Alias -Name rmrf -Value Remove-All -Scope Global
Set-Alias -Name ssh-copy-id -Value Copy-SSHID -Scope Global
Set-Alias -Name cc -Value claude

if (Get-Command thefuck -ErrorAction Ignore) {
    Invoke-Expression "$(thefuck --alias)"
}
