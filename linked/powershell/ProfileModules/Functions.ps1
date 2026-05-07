#Requires -Version 7.0

function global:Test-AdminRole {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$Global:IsAdmin = Test-AdminRole
if ($Global:IsAdmin) {
    Write-ProfileMsg '⚡ Administrator' -Color Cyan
}


function global:Update-AllModules {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Set-PSResourceRepository -Name PSGallery -Trusted -ErrorAction SilentlyContinue

    $installed = Get-InstalledPSResource | Sort-Object Name

    # --- Phase 1: Prune stale entries ---
    Write-Host "`n⚙  Phase 1 — Pruning stale entries" -ForegroundColor Cyan

    $stale = $installed | Where-Object { -not (Test-Path $_.InstalledLocation) }

    if (-not $stale) {
        Write-Host '  ✓ No stale entries' -ForegroundColor Green
    } else {
        foreach ($module in $stale) {
            Write-Warning "Stale entry: $($module.Name) v$($module.Version) — $($module.InstalledLocation)"
            if ($PSCmdlet.ShouldProcess("$($module.Name) v$($module.Version)", 'Uninstall stale entry')) {
                Uninstall-PSResource -Name $module.Name -Version $module.Version -ErrorAction SilentlyContinue
            }
        }
    }

    # --- Phase 2: Update installed modules ---
    Write-Host "`n⚙  Phase 2 — Updating modules" -ForegroundColor Cyan

    $valid  = $installed | Where-Object { Test-Path $_.InstalledLocation }
    $unique = $valid | Sort-Object Name -Unique
    $total  = @($unique).Count
    $i = 0

    foreach ($module in $unique) {
        $i++
        $scope = if ($module.InstalledLocation -like "*$env:USERPROFILE*") { 'CurrentUser' } else { 'AllUsers' }

        if ($scope -eq 'AllUsers' -and -not $Global:IsAdmin) {
            Write-Host "  · [$i/$total] $($module.Name) — needs admin" -ForegroundColor DarkYellow
            continue
        }

        Write-Host "  [$i/$total] $($module.Name)…" -ForegroundColor DarkGray -NoNewline

        Update-PSResource -Name $module.Name -Scope $scope -ErrorAction SilentlyContinue

        $allVersions = @(Get-InstalledPSResource -Name $module.Name |
            Where-Object { Test-Path $_.InstalledLocation } |
            Sort-Object Version -Descending)

        if ($allVersions.Count -gt 1) {
            $allVersions[1..($allVersions.Count - 1)] | ForEach-Object {
                Uninstall-PSResource -Name $_.Name -Version $_.Version -ErrorAction SilentlyContinue
            }
        }

        Write-Host ' ✓' -ForegroundColor Green
    }

    # --- Phase 3: Update help files ---
    Write-Host "`n⚙  Phase 3 — Updating help files" -ForegroundColor Cyan

    try {
        if ($PSCmdlet.ShouldProcess('PowerShell help content', 'Update help files')) {
            Update-Help -Force -ErrorAction Continue
        }
        Write-Host '  ✓ Help updated' -ForegroundColor Green
    } catch {
        Write-Warning "Help update failed: $($_.Exception.Message)"
    }

    Write-Host "`n✓ Done" -ForegroundColor Green
}


function global:cd...  { Set-Location ..\.. }
function global:cd.... { Set-Location ..\..\.. }

function global:Show-Environment {
    Get-ChildItem env:* | Sort-Object name | Format-Table -AutoSize
}

function global:Show-Path {
    Write-Output $Env:Path.Split(';')
}

function global:New-File {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)
    if (-not (Test-Path $Name)) {
        New-Item -ItemType File -Path $Name | Out-Null
    }
}

function global:Remove-All {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Path)
    Remove-Item -Force -Recurse @Path
}

function global:Get-PubIP {
    [CmdletBinding()]
    param()
    try {
        (Invoke-WebRequest 'https://ifconfig.me/ip' -UseBasicParsing).Content.Trim()
    } catch {
        Write-Warning "Could not reach ifconfig.me: $($_.Exception.Message)"
    }
}

function global:Copy-SSHID {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Destination)
    try {
        Get-Content "$Env:USERPROFILE\.ssh\id_rsa.pub" |
            ssh $Destination 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'
    } catch {
        Write-Warning "Error copying key to $Destination`: $($_.Exception.Message)"
    }
}

function global:Reload-Profile {
    . $PROFILE
    Write-ProfileMsg '✓ Profile reloaded' -Color Green
}

function global:Measure-Profile {
    $t = Measure-Command { . $PROFILE }
    Write-ProfileMsg "Profile load: $([math]::Round($t.TotalMilliseconds))ms" -Color Cyan
}
