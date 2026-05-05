#Requires -Version 7.0

function isAdminUser {
    $wi = [Security.Principal.WindowsIdentity]::GetCurrent()
    $wp = New-Object Security.Principal.WindowsPrincipal($wi)
    $wp.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$isAdmin = isAdminUser
if ($isAdmin) {
    Write-Output 'Running as Administrator'
}


function Update-AllModules {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Set-PSResourceRepository -Name PSGallery -Trusted -ErrorAction SilentlyContinue

    $installed = Get-InstalledPSResource | Sort-Object Name

    # --- Phase 1: Prune stale entries ---
    Write-Host "`n=== Phase 1: Pruning stale module entries ===" -ForegroundColor Yellow

    $stale = $installed | Where-Object { -not (Test-Path $_.InstalledLocation) }

    if (-not $stale) {
        Write-Host 'No stale entries found.' -ForegroundColor Green
    } else {
        foreach ($module in $stale) {
            Write-Host "  Stale: $($module.Name) v$($module.Version) -> $($module.InstalledLocation)" -ForegroundColor Red
            if ($PSCmdlet.ShouldProcess("$($module.Name) v$($module.Version)", 'Uninstall stale entry')) {
                Uninstall-PSResource -Name $module.Name -Version $module.Version -ErrorAction SilentlyContinue
            }
        }
    }

    # --- Phase 2: Update installed modules ---
    Write-Host "`n=== Phase 2: Updating installed modules ===" -ForegroundColor Yellow

    $valid  = $installed | Where-Object { Test-Path $_.InstalledLocation }
    $unique = $valid | Sort-Object Name -Unique
    $total  = @($unique).Count
    $i = 0

    foreach ($module in $unique) {
        $i++
        $scope = if ($module.InstalledLocation -like "*$env:USERPROFILE*") { 'CurrentUser' } else { 'AllUsers' }

        if ($scope -eq 'AllUsers' -and -not $isAdmin) {
            Write-Host "  [$i/$total] SKIP (needs admin): $($module.Name) [$scope]" -ForegroundColor DarkYellow
            continue
        }

        Write-Host "  [$i/$total] $($module.Name) [$scope]..." -NoNewline

        Update-PSResource -Name $module.Name -Scope $scope -ErrorAction SilentlyContinue

        $allVersions = @(Get-InstalledPSResource -Name $module.Name |
            Where-Object { Test-Path $_.InstalledLocation } |
            Sort-Object Version -Descending)

        if ($allVersions.Count -gt 1) {
            $allVersions[1..($allVersions.Count - 1)] | ForEach-Object {
                Uninstall-PSResource -Name $_.Name -Version $_.Version -ErrorAction SilentlyContinue
            }
        }

        Write-Host ' Done.' -ForegroundColor Green
    }

    # --- Phase 3: Update help files ---
    Write-Host "`n=== Phase 3: Updating help files ===" -ForegroundColor Yellow

    try {
        if ($PSCmdlet.ShouldProcess('PowerShell help content', 'Update help files')) {
            Update-Help -Force -ErrorAction Continue
        }
        Write-Host 'Help update complete.' -ForegroundColor Green
    } catch {
        Write-Host "Help update encountered errors: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }

    Write-Host "`nAll done." -ForegroundColor Cyan
}


function nls { npm list -g --depth=0 }

function sstat { scoop update && scoop status }
function supd  { scoop update * && scoop cleanup * }

function wstat { winget upgrade }
function wupd  { winget upgrade --all }


function Test-Syntax {
    # Demo PSReadLine syntax highlighting
    [CmdletBinding()]
    param([IO.FileInfo]$Path)
    end {
        Write-Verbose "Testing in $(Split-Path $PSScriptRoot -Leaf)" -Verbose
        $Env:PSModulePath -split ';' -notcontains $Path.FullName
    }
}

function cd...  { Set-Location ..\.. }
function cd.... { Set-Location ..\..\.. }

function Show-Environment {
    Get-ChildItem env:* | Sort-Object name | Format-Table -AutoSize
}

function Show-Path {
    Write-Output $Env:Path.Split(';')
}

function New-File($filename) {
    Write-Output $null | Out-File $filename -Encoding utf8
}

function Remove-All {
    Remove-Item -Force -Recurse $args
}

function Get-PubIP {
    (Invoke-WebRequest http://ifconfig.me/ip).Content
}

function Invoke-MQTT {
    $mqtt_config_file = Join-Path -Path $home -ChildPath '.mosquitto' 'config'
    mosquitto -v -c $mqtt_config_file
}

function Join-Files {
    if (Get-Command bat.exe -ErrorAction SilentlyContinue) {
        $bat = (Get-Command bat.exe).Path.ToString()
        & $bat -pp $args
    } else {
        Get-Content $args
    }
}

# eza: functions and aliases are defined together since _ls/_ll/_la/_tree close over $eza
if (Get-Command eza.exe -ErrorAction SilentlyContinue) {
    $eza = (Get-Command eza.exe).Path.ToString()
    function _ls   { & $eza --color=auto --icons --group-directories-first @args }
    function _ll   { & $eza --all --long --header @args }
    function _la   { & $eza --all --group @args }
    function _tree { & $eza --tree @args }
    Set-Alias -Name ls   -Value _ls
    Set-Alias -Name ll   -Value _ll
    Set-Alias -Name la   -Value _la
    Set-Alias -Name tree -Value _tree
}

function Start-GlazeWM {
    if (Get-Command glazewm.exe -ErrorAction SilentlyContinue) {
        $wm = (Get-Command glazewm.exe).Path.ToString()
        $glaze_config = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'glazewm' 'config.yaml'
        & $wm --config=$glaze_config $args
    }
}

function Copy-SSHID($dest) {
    try {
        Get-Content $Env:USERPROFILE\.ssh\id_rsa.pub | ssh $dest 'mkdir ~/.ssh; cat >> ~/.ssh/authorized_keys'
    } catch {
        Write-Warning "Error copying key to $dest"
        Write-Host $_
    }
}
