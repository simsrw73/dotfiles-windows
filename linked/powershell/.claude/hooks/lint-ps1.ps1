#!/usr/bin/env pwsh
param()

$json = $input | ConvertFrom-Json
$filePath = $json.tool_input.file_path

if (-not $filePath -or $filePath -notmatch '\.ps1$') { exit 0 }
if (-not (Test-Path $filePath)) { exit 0 }
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer -ErrorAction SilentlyContinue)) { exit 0 }

Import-Module PSScriptAnalyzer -ErrorAction SilentlyContinue
$results = Invoke-ScriptAnalyzer -Path $filePath -Severity Warning, Error -ErrorAction SilentlyContinue

if ($results) {
    $count = $results.Count
    Write-Host "PSScriptAnalyzer: $count issue(s) in $(Split-Path $filePath -Leaf)" -ForegroundColor Yellow
    $results | Format-Table -Property Severity, Line, RuleName, Message -AutoSize
}
