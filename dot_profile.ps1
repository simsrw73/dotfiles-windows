Import-Module oh-my-posh
Import-Module posh-git
Import-Module Terminal-Icons
Import-Module PSReadLine
Import-Module DockerCompletion


# $env:PAGER = 'less'

# Scoop install GPG as a portable app, remove the ctl file so we can store the key in ~
$PATH_TO_GPGCONFCTL = $env:USERPROFILE + '\scoop\apps\gpg\current\bin\gpgconf.ctl'
if (Test-Path $PATH_TO_GPGCONFCTL -PathType Leaf) {
    Remove-Item -Path $PATH_TO_GPGCONFCTL -Force -ErrorAction SilentlyContinue
}
$env:GNUPGHOME = $env:USERPROFILE + '/.gnupg'

$env:POSH_GIT_ENABLED = $true

Set-PoshPrompt ~/Monochrome.omp.json

Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows

Remove-Alias -Name r -Force -ErrorAction SilentlyContinue
Set-Alias -Name cz -Value chezmoi
Set-Alias -Name printenv -Value "Get-ChildItem env:* | Sort-Object name"

Function Write-Environment {
    Get-ChildItem env:* | Sort-Object name | Format-Table -AutoSize
}
Set-Alias -Name printenv -Value Write-Environment
