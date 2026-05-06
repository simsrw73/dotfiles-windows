#Requires -Version 7.0

function global:isAdminUser {
    $wi = [Security.Principal.WindowsIdentity]::GetCurrent()
    $wp = New-Object Security.Principal.WindowsPrincipal($wi)
    $wp.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$global:isAdmin = isAdminUser
if ($global:isAdmin) {
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

        if ($scope -eq 'AllUsers' -and -not $global:isAdmin) {
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


# nls moved to cli_tools_config.ps1

# sstat/supd moved to cli_tools_config.ps1 (#region scoop)
# wstat/wupd moved to cli_tools_config.ps1 (#region winget)

function global:Test-Syntax {
    # Demo PSReadLine syntax highlighting
    [CmdletBinding()]
    param([IO.FileInfo]$Path)
    end {
        Write-Verbose "Testing in $(Split-Path $PSScriptRoot -Leaf)" -Verbose
        $Env:PSModulePath -split ';' -notcontains $Path.FullName
    }
}

function global:cd...  { Set-Location ..\.. }
function global:cd.... { Set-Location ..\..\.. }

function global:Show-Environment {
    Get-ChildItem env:* | Sort-Object name | Format-Table -AutoSize
}

function global:Show-Path {
    Write-Output $Env:Path.Split(';')
}

function global:New-File($filename) {
    Write-Output $null | Out-File $filename -Encoding utf8
}

function global:Remove-All {
    Remove-Item -Force -Recurse $args
}

function global:Get-PubIP {
    (Invoke-WebRequest http://ifconfig.me/ip).Content
}

# Invoke-MQTT moved to cli_tools_config.ps1

# bat/Join-Files moved to cli_tools_config.ps1

# eza config moved to cli_tools_config.ps1

# Start-GlazeWM moved to cli_tools_config.ps1

function global:Copy-SSHID($dest) {
    try {
        Get-Content $Env:USERPROFILE\.ssh\id_rsa.pub | ssh $dest 'mkdir ~/.ssh; cat >> ~/.ssh/authorized_keys'
    } catch {
        Write-Warning "Error copying key to $dest"
        Write-Host $_
    }
}
