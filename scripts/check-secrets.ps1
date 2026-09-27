#Requires -Version 7
<#
Checks that the Bitwarden-backed templates reproduce this machine's secrets,
without printing any secret values. Run with Bitwarden unlocked:
    $env:BW_SESSION = bw unlock --raw
    pwsh -File scripts/check-secrets.ps1 [-Source <chezmoi source dir>]
#>
param([string] $Source = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
if (-not $env:BW_SESSION) { throw 'Set $env:BW_SESSION = (bw unlock --raw) first.' }
$fail = 0

Write-Host '--- secret files: template output vs live file (hash compare)'
foreach ($t in '.ssh/id_ed25519', '.ssh/id_a24', '.ssh/private_key', '.ssh/routeros_rsa', '.env') {
    $live = Join-Path $HOME $t
    $tmp = New-TemporaryFile
    try {
        chezmoi --source $Source cat "~/$t" | Out-Null   # surface template errors
        if ($LASTEXITCODE -ne 0) { Write-Host "FAIL $t (template error)"; $fail++; continue }
        # cat through cmd to keep the bytes exactly as chezmoi prints them
        cmd /c "chezmoi --source `"$Source`" cat `"$live`" > `"$tmp`""
        $same = (Get-FileHash $tmp).Hash -eq (Get-FileHash $live).Hash
        if ($same) { Write-Host "ok   $t" }
        else {
            $a = (Get-Content $tmp) -join "`n"; $b = (Get-Content $live) -join "`n"
            if ($a -eq $b) { Write-Host "ok   $t (line endings differ only)" }
            else { Write-Host "DIFF $t"; $fail++ }
        }
    }
    finally { Remove-Item $tmp -Force }
}

Write-Host '--- scripts render with secrets'
$gpg = Get-Content (Join-Path $Source 'home/.chezmoiscripts/run_onchange_after_30-gpg-import.ps1.tmpl') -Raw | chezmoi --source $Source execute-template
if (($gpg -join "`n") -match 'BEGIN PGP PRIVATE KEY BLOCK') { Write-Host 'ok   gpg key present in import script' } else { Write-Host 'FAIL gpg import script'; $fail++ }
$flow = Get-Content (Join-Path $Source 'home/.chezmoiscripts/run_onchange_after_15-flow-github-token.ps1.tmpl') -Raw | chezmoi --source $Source execute-template
$flowLive = Join-Path $HOME '.config\FlowLauncher\Settings\Plugins\Github Quick Launcher\Settings.json'
if (($flow -join "`n").Contains(((Get-Content $flowLive) -join "`n").Trim())) { Write-Host 'ok   FlowLauncher settings match' } else { Write-Host 'FAIL FlowLauncher settings'; $fail++ }

Write-Host '--- a missing item must fail loudly'
'{{ (bitwarden "item" "no-such-item-xyz").id }}' | chezmoi --source $Source execute-template *> $null
if ($LASTEXITCODE -ne 0) { Write-Host "ok   missing item -> exit $LASTEXITCODE" } else { Write-Host 'FAIL missing item did not error'; $fail++ }

Write-Host '--- chezmoi status (paths only)'
chezmoi --source $Source status

Write-Host ''
if ($fail) { Write-Host "$fail check(s) failed"; exit 1 } else { Write-Host 'all secret checks passed' }
