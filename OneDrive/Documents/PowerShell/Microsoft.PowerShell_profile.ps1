Import-Module oh-my-posh
Import-Module posh-git
Import-Module Terminal-Icons
Import-Module PSReadLine

# $env:PAGER = 'less'
$env:POSH_GIT_ENABLED = $true

Set-PoshPrompt ~/simple.omp.json

Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows

Remove-Alias -Name r -Force -ErrorAction SilentlyContinue
