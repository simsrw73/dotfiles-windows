#Requires -Version 7.0

function global:Test-AdminRole {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
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

    # Get-InstalledPSResource lists only modules whose files exist. InstalledLocation is
    # read from each module's PSGetModuleInfo.xml and goes stale when the profile folder
    # moves (restore, rename), so never treat a missing InstalledLocation as a missing
    # module: Uninstall-PSResource -Name/-Version would delete the live copy.
    $installed = Get-InstalledPSResource | Sort-Object Name

    # --- Phase 1: Update installed modules ---
    Write-Host "`n⚙  Phase 1 — Updating modules" -ForegroundColor Cyan

    $unique = $installed | Sort-Object Name -Unique
    $total = @($unique).Count
    $i = 0

    foreach ($module in $unique) {
        $i++
        $scope = if ($module.InstalledLocation -like "$env:ProgramFiles*") { 'AllUsers' } else { 'CurrentUser' }

        if ($scope -eq 'AllUsers' -and -not $Global:IsAdmin) {
            Write-Host "  · [$i/$total] $($module.Name) — needs admin" -ForegroundColor DarkYellow
            continue
        }

        Write-Host "  [$i/$total] $($module.Name)…" -ForegroundColor DarkGray -NoNewline

        Update-PSResource -Name $module.Name -Scope $scope -ErrorAction SilentlyContinue

        $allVersions = @(Get-InstalledPSResource -Name $module.Name |
                Sort-Object Version -Descending)

        if ($allVersions.Count -gt 1) {
            $allVersions[1..($allVersions.Count - 1)] | ForEach-Object {
                Uninstall-PSResource -Name $_.Name -Version $_.Version -ErrorAction SilentlyContinue
            }
        }

        Write-Host ' ✓' -ForegroundColor Green
    }

    # --- Phase 2: Update help files ---
    Write-Host "`n⚙  Phase 2 — Updating help files" -ForegroundColor Cyan

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

function global:Measure-Profile {
    $t = Measure-Command { . $PROFILE }
    Write-ProfileMsg "Profile load: $([math]::Round($t.TotalMilliseconds))ms" -Color Cyan
}

# Recklessly allow Claude to run all over me
$script:ClaudeExe = (Get-Command claude -ErrorAction Ignore).Source
function clauded {
    if (-not $script:ClaudeExe) { Write-Warning 'claude is not on PATH'; return }
    & $script:ClaudeExe --dangerously-skip-permissions @Args
}



