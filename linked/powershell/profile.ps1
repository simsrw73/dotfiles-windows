# #Requires -Version 7.0

Set-StrictMode -Version 'Latest'
$ErrorActionPreference = 'Stop'

$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

$profileRoot = Split-Path -Parent $PROFILE
$moduleRoot = Join-Path $profileRoot 'ProfileModules'

$VerbosePreference = 'SilentlyContinue' # Normal: 'SilentlyContinue', Debugging: 'Continue'

# ── VS Code integrated terminal: fast / lite init ───────────────────────────
# Skips: oh-my-posh, VS Dev Shell, transcript, diagnostics, weekly updates.
# Keeps: env vars, all aliases/functions, PSReadLine, fzf, tool completers.
if ($Env:TERM_PROGRAM -eq 'vscode') {
    foreach ($mod in @('PSReadLine', 'PSFzf')) {
        try {
            Import-Module -Name $mod -ErrorAction Stop
        } catch {
            Write-Warning "Module '$mod' failed to load: $($_.Exception.Message)"
        }
    }
    . (Join-Path $moduleRoot 'Env.ps1')
    . (Join-Path $moduleRoot 'Aliases.ps1')
    . (Join-Path $moduleRoot 'Functions.ps1')
    . (Join-Path $moduleRoot 'Completers.ps1')
    . (Join-Path $moduleRoot 'PSReadline.ps1')
    . (Join-Path $moduleRoot 'cli_tools_config.ps1')
    . (Join-Path $moduleRoot 'Show-HelpColor.ps1')
    return
}
# ── Full init (standard terminals) ──────────────────────────────────────────

# Import modules before dot-sourcing ProfileModules (Completers.ps1 and PSReadline.ps1 depend on these)
# Use SilentlyContinue so a broken/missing module never aborts the profile
foreach ($mod in @(
        'PSReadLine', 'PSFzf', 'powershell-yaml',
        'Microsoft.PowerShell.SecretManagement'
        # DockerCompletion: imported in cli_tools_config.ps1 (#region DockerCompletion)
        # scoop-completion: handled by PSFzf -EnableAliasFuzzyScoop in cli_tools_config.ps1
    )) {
    try {
        Import-Module -Name $mod -ErrorAction Stop
    } catch {
        Write-Warning "Module '$mod' failed to load: $($_.Exception.Message)"
    }
}

. (Join-Path $moduleRoot 'Env.ps1')
. (Join-Path $moduleRoot 'Aliases.ps1')
. (Join-Path $moduleRoot 'Functions.ps1')
. (Join-Path $moduleRoot 'Completers.ps1')
. (Join-Path $moduleRoot 'PSReadline.ps1')
. (Join-Path $moduleRoot 'cli_tools_config.ps1')
. (Join-Path $moduleRoot 'Show-HelpColor.ps1')

# Startup diagnostics
$PSInfo = Get-Process -Id $pid | Get-Item
Write-Output "Current shell: $PSInfo"

$termInfo = $Host.UI.RawUI
if ($termInfo.WindowSize.Height -le 20) {
    Write-Output 'Terminal size is small.'
} else {
    Write-Output 'Terminal size is normal.'
}

# Weekly module update (every Friday)
if ((Get-Date).DayOfWeek -eq 'Friday') {
    Write-Host 'Running weekly module update...' -ForegroundColor Cyan
    Update-AllModules
}

# Enable experimental features
$experimentalFeatures = Get-ExperimentalFeature
if ($experimentalFeatures.Name -contains 'PSFeedbackProvider') {
    Write-Host 'Enabling experimental feature: PSFeedbackProvider'
    Enable-ExperimentalFeature PSFeedbackProvider
}

# oh-my-posh init moved to cli_tools_config.ps1

# VS Dev Shell
Write-Host 'Setting up MS Dev Environment... ' -ForegroundColor Green -NoNewline
$vsWhere = "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsInstallationPath = & $vsWhere -products * -latest -property installationPath
& "${vsInstallationPath}\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64 -SkipAutomaticLocation | Out-Null
Write-Host 'Done.' -ForegroundColor Green

# --- Transcript ---
if ($Host.Name -eq 'ConsoleHost') {
    $myDocuments = [Environment]::GetFolderPath('MyDocuments')
    $TranscriptRoot = Join-Path $myDocuments 'PowerShell.Transcripts'
    $RetentionDays = 7

    if (-not (Test-Path $TranscriptRoot)) {
        New-Item -Path $TranscriptRoot -ItemType Directory -Force | Out-Null
    }

    $todayFolder = Join-Path $TranscriptRoot (Get-Date -Format 'yyyy-MM-dd')
    if (-not (Test-Path $todayFolder)) {
        New-Item -Path $todayFolder -ItemType Directory -Force | Out-Null
    }

    $tsName = "Transcript_$($env:USERNAME)_$($env:COMPUTERNAME)_PS$($PSVersionTable.PSVersion)_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $tsPath = Join-Path $todayFolder $tsName

    try {
        Start-Transcript -LiteralPath $tsPath -Append -IncludeInvocationHeader -ErrorAction Stop | Out-Null
    } catch {
        Write-Warning "Failed to start transcript: $($_.Exception.Message)"
    }

    # Prune transcripts older than $RetentionDays
    try {
        $cutoff = (Get-Date).AddDays(-$RetentionDays)

        Get-ChildItem -Path $TranscriptRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff } |
            Remove-Item -Force -ErrorAction SilentlyContinue

        Get-ChildItem -Path $TranscriptRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { -not (Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue) } |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Failed to prune old transcripts: $($_.Exception.Message)"
    }
}
