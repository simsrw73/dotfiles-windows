#Requires -Version 7.0

Set-StrictMode -Version 'Latest'

$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding


if (Get-Command -Name 'FastFetch' -ErrorAction Ignore) {
    Clear-Host
    FastFetch
    $v = $PSVersionTable.PSVersion
    'PowerShell {0}.{1}.{2} ({3})' -f $v.Major, $v.Minor, $v.Patch, $PSVersionTable.PSEdition
}


# Preferred Setup
#
# Modules:
#
# Utilities:
#   Oh-My-Posh, Carapace
#


$profileRoot = Split-Path -Parent $PROFILE
$moduleRoot = Join-Path $profileRoot 'ProfileModules'

# ── Output verbosity ─────────────────────────────────────────────────────────
# Set $Global:ProfileLogLevel to control startup output:
#   [LogLevel]::Warn  — warnings/errors only (scripting, CI)
#   [LogLevel]::Info  — key status lines (default)
#   [LogLevel]::Debug — full detail: modules, file loads, tool inventory
enum LogLevel { Error = 0; Warn = 1; Info = 2; Debug = 3 }
$Global:ProfileLogLevel = [LogLevel]::Info

$isDebuggingProfile = $false
if ($isDebuggingProfile) {
    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'

    $Global:ProfileLogLevel = [LogLevel]::Debug
    Write-Host 'Debug mode: verbose output enabled' -ForegroundColor Yellow
}


function global:Write-ProfileMsg {
    param(
        [Parameter(Mandatory)][string]$Message,
        [LogLevel]$Level = [LogLevel]::Info,
        [string]$Color = ''
    )
    $_effectiveLevel = if ($null -eq $Global:ProfileLogLevel) { [LogLevel]::Info } else { $Global:ProfileLogLevel }
    if ([int]$Level -gt [int]$_effectiveLevel) { return }
    switch ($Level) {
        ([LogLevel]::Error) { Write-Error $Message; return }
        ([LogLevel]::Warn) { Write-Warning $Message; return }
    }
    $c = if ($Color) { $Color } else {
        switch ($Level) {
            ([LogLevel]::Info) { 'Cyan' }
            ([LogLevel]::Debug) { 'DarkGray' }
            default { 'White' }
        }
    }
    Write-Host $Message -ForegroundColor $c
}

# ── DotForge config (set BEFORE Import-Module DotForge) ──────────────────────
$DFConfig = @{
    PackageManagerOrder = @('scoop', 'winget')
    SkipTools           = @('lsd')  # lsd conflicts with eza FIXME: this should be automatically resolved. Adopt a default tool and let the user specify their preference.
    CompletionMode      = 'Native'
    PSReadLineEditMode  = 'Emacs'
    PSReadLineTheme     = 'catppuccin-mocha'
}

# Set OMP theme before DotForge::Register-DFTool initializes posh-git and oh-my-posh
$Env:POSH_THEME = Join-Path $HOME '.config' 'oh-my-posh' 'catpow.omp.yaml'

# ── VS Code integrated terminal: fast / lite init ────────────────────────────
# Skips: oh-my-posh, VS Dev Shell, transcript, diagnostics, weekly updates.
# Keeps: env vars, all aliases/functions, and tool completers.
if ($Env:TERM_PROGRAM -eq 'vscode') {
    Import-Module DotForge -ErrorAction SilentlyContinue
    Initialize-DFEnvironment
    . (Join-Path $moduleRoot 'Env.ps1')
    . (Join-Path $moduleRoot 'Aliases.ps1')
    . (Join-Path $moduleRoot 'Functions.ps1')
    . (Join-Path $moduleRoot 'Completers.ps1')
    Register-DFTool -All
    return
}

# ── Full init (standard terminals) ───────────────────────────────────────────

$_modsOk = [System.Collections.Generic.List[string]]::new()
$_modsFail = [System.Collections.Generic.List[string]]::new()
foreach ($mod in @('powershell-yaml', 'Microsoft.PowerShell.SecretManagement')) {
    try {
        Import-Module -Name $mod -ErrorAction Stop
        $null = $_modsOk.Add($mod)
    } catch {
        $null = $_modsFail.Add($mod)
        Write-Warning "Module '$mod' failed to load: $($_.Exception.Message)"
    }
}
if ($_modsOk.Count -gt 0) {
    Write-ProfileMsg ('  Modules: ' + (($_modsOk | ForEach-Object { "✓ $_" }) -join '  ')) -Level Debug -Color Green
}
if ($_modsFail.Count -gt 0) {
    Write-ProfileMsg ('  Failed:  ' + (($_modsFail | ForEach-Object { "· $_" }) -join '  ')) -Level Debug -Color DarkYellow
}

$_sshAgent = Get-Service ssh-agent -ErrorAction Ignore
if (-not $_sshAgent -or $_sshAgent.Status -ne 'Running') {
    Write-ProfileMsg '  · ssh-agent not running — run: Start-Service ssh-agent (requires admin)' -Level Debug
}

Import-Module DotForge -ErrorAction Continue
Initialize-DFEnvironment
. (Join-Path $moduleRoot 'Env.ps1')
Write-ProfileMsg "  Terminal: $($Env:TERM_PROGRAM ?? 'unknown')" -Level Debug
. (Join-Path $moduleRoot 'Aliases.ps1')
. (Join-Path $moduleRoot 'Functions.ps1')
. (Join-Path $moduleRoot 'Completers.ps1')

Register-DFTool -All


# Weekly module update (every Friday, once per day)
if ((Get-Date).DayOfWeek -eq 'Friday') {
    $_sentinel = Join-Path ($Env:XDG_STATE_HOME ?? "$HOME/.local/state") 'ps_friday_maintenance'
    $_today = Get-Date -Format 'yyyy-MM-dd'
    $_lastRun = if (Test-Path $_sentinel) { (Get-Content $_sentinel -Raw).Trim() } else { '' }
    if ($_lastRun -ne $_today) {
        Write-ProfileMsg '⚙  Running weekly module update…'
        Update-AllModules
        Set-Content $_sentinel $_today -NoNewline
    }
}

# # VS Dev Shell
# $vsWhere = "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
# if (Test-Path $vsWhere) {
#     $vsInstallationPath = & $vsWhere -products * -latest -property installationPath
#     if ($vsInstallationPath) {
#         & "${vsInstallationPath}\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64 -SkipAutomaticLocation | Out-Null
#         Write-ProfileMsg '⚙  VS Dev Shell ready'
#     }
# }

# Transcript
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
        Write-ProfileMsg "  → Transcript: $tsPath" -Level Debug
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
