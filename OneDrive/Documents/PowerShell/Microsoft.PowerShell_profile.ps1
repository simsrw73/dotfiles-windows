Import-Module oh-my-posh
Import-Module posh-git
Import-Module Terminal-Icons
Import-Module PSReadLine

# $env:PAGER = 'less'
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
