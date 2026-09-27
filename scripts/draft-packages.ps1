#Requires -Version 7
$ErrorActionPreference = 'Stop'
$out = Join-Path $PSScriptRoot '..\home\.chezmoidata\packages.yaml'
$buckets = scoop bucket list | ForEach-Object { [pscustomobject]@{ name = $_.Name; url = $_.Source } }
$scoopApps = (scoop export | ConvertFrom-Json).apps | Where-Object Source | ForEach-Object { if ($_.Source -in 'main','extras') { $_.Name } else { "$($_.Source)/$($_.Name)" } }
$wingetJson = Join-Path $env:TEMP 'winget-export.json'
winget export -o $wingetJson --source winget --accept-source-agreements | Out-Null
$winget = (Get-Content $wingetJson | ConvertFrom-Json).Sources[0].Packages.PackageIdentifier
$builtIn = 'PackageManagement','PowerShellGet','PSReadLine','DotForge','Microsoft.PowerShell.SecretManagement','Microsoft.PowerShell.SecretStore','Microsoft.PowerToys.Configure'
$docs = [Environment]::GetFolderPath('MyDocuments')
$mods = Get-ChildItem (Join-Path $docs 'PowerShell\Modules') -Directory | % Name | Where-Object { $_ -notin $builtIn }
$lines = @('packages:', '  scoop:', '    buckets:')
$lines += $buckets | ForEach-Object { "      - name: $($_.name)"; if ($_.url -and $_.name -notin 'main','extras','nirsoft') { "        url: $($_.url)" } }
$lines += '    apps:'; $lines += $scoopApps | Sort-Object | ForEach-Object { "      - $_" }
$lines += '  winget:', '    user:'; $lines += $winget | Sort-Object | ForEach-Object { "      - $_" }
$lines += '    elevated: []', '  pwsh:'; $lines += $mods | Sort-Object | ForEach-Object { "    - $_" }
Set-Content $out $lines
Write-Host "draft written: $out"
