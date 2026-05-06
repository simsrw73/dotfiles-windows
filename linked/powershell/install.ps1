#Requires -Version 7.0
<#
.SYNOPSIS
    Bootstrap a new Windows 11 machine with the full PowerShell profile toolchain.
.DESCRIPTION
    Installs scoop and scoop packages, npm globals, PS modules, creates XDG directories,
    configures git, optionally initialises chezmoi, copies Windows Terminal config,
    and installs VS Code extensions.
.PARAMETER WhatIf
    Show what would be done without making any changes.
.EXAMPLE
    pwsh -File install.ps1
    pwsh -File install.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest

# ── Helpers ──────────────────────────────────────────────────────────────────
function Write-Step  { param([string]$Msg) Write-Host "`n⚙  $Msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Msg) Write-Host "  ✓ $Msg" -ForegroundColor Green }
function Write-Skip  { param([string]$Msg) Write-Host "  · $Msg" -ForegroundColor DarkYellow }
function Write-Fail  { param([string]$Msg) Write-Warning $Msg }

$profileRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# ── 1. Prerequisites ──────────────────────────────────────────────────────────
Write-Step 'Checking prerequisites'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Fail 'PowerShell 7+ required. Install from https://aka.ms/powershell'
    exit 1
}
Write-Ok "PowerShell $($PSVersionTable.PSVersion)"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Skip 'Not running as Administrator — some steps may be skipped'
}

# ── 2. Scoop ──────────────────────────────────────────────────────────────────
Write-Step 'Scoop package manager'

if (-not (Get-Command scoop -ErrorAction Ignore)) {
    if ($PSCmdlet.ShouldProcess('scoop', 'Install')) {
        Invoke-RestMethod https://get.scoop.sh | Invoke-Expression
    }
} else {
    Write-Ok 'scoop already installed'
}

foreach ($bucket in @('main', 'extras')) {
    if ($PSCmdlet.ShouldProcess("scoop bucket $bucket", 'Add')) {
        scoop bucket add $bucket 2>$null
    }
}

# ── 3. Scoop packages ─────────────────────────────────────────────────────────
Write-Step 'Scoop packages'

$scoopPackages = @(
    'bat', 'broot', 'chezmoi', 'clink', 'cmake', 'curl', 'delta', 'diffutils',
    'dua', 'duf', 'eza', 'fd', 'fzf', 'gdu', 'gh', 'glow', 'grep', 'gsudo',
    'iperf3', 'jid', 'jq', 'lazygit', 'less', 'lsd', 'micro', 'moor', 'nano',
    'nircmd', 'ntop', 'nvm', 'procs', 'psfzf', 'ripgrep', 'scoop-search', 'sed',
    'sfsu', 'sysinternals', 'vcpkg', 'wget', 'which', 'win32yank', 'winfetch', 'zoxide'
)

foreach ($pkg in $scoopPackages) {
    if ($PSCmdlet.ShouldProcess($pkg, 'scoop install')) {
        $installed = scoop list 2>$null | Select-String "^$pkg\s"
        if ($installed) {
            Write-Ok "$pkg already installed"
        } else {
            Write-Host "  Installing $pkg…" -ForegroundColor DarkGray -NoNewline
            scoop install $pkg 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Host ' ✓' -ForegroundColor Green }
            else                     { Write-Host ' failed' -ForegroundColor Red }
        }
    }
}

# ── 4. Node / npm globals ─────────────────────────────────────────────────────
Write-Step 'Node.js and npm global packages'

if (Get-Command nvm -ErrorAction Ignore) {
    if ($PSCmdlet.ShouldProcess('node LTS', 'nvm install')) {
        nvm install lts 2>$null
        nvm use lts   2>$null
    }
    $npmPackages = @(
        '@anthropic-ai/mcpb',
        '@bitwarden/cli',
        '@google/gemini-cli',
        '@playwright/cli'
    )
    foreach ($pkg in $npmPackages) {
        if ($PSCmdlet.ShouldProcess($pkg, 'npm install -g')) {
            Write-Host "  Installing $pkg…" -ForegroundColor DarkGray -NoNewline
            npm install -g $pkg 2>$null | Out-Null
            Write-Host ' ✓' -ForegroundColor Green
        }
    }
} else {
    Write-Skip 'nvm not found — skipping Node setup'
}

# ── 5. PowerShell modules ─────────────────────────────────────────────────────
Write-Step 'PowerShell modules'

$psModules = @(
    'PSReadLine', 'PSFzf', 'posh-git', 'Terminal-Icons',  # oh-my-posh is a scoop package, not a PSResource
    'PSAISuite', 'PowerType', 'DockerCompletion', 'PSWindowsUpdate',
    'Admin', 'powershell-yaml', 'Microsoft.PowerShell.SecretManagement',
    'Microsoft.PowerShell.SecretStore', 'scoop-completion'
)

Set-PSResourceRepository -Name PSGallery -Trusted -ErrorAction Ignore

foreach ($mod in $psModules) {
    if ($PSCmdlet.ShouldProcess($mod, 'Install-PSResource')) {
        $existing = Get-InstalledPSResource -Name $mod -ErrorAction Ignore
        if ($existing) {
            Write-Ok "$mod already installed"
        } else {
            Write-Host "  Installing $mod…" -ForegroundColor DarkGray -NoNewline
            Install-PSResource -Name $mod -Scope CurrentUser -ErrorAction Continue | Out-Null
            Write-Host ' ✓' -ForegroundColor Green
        }
    }
}

# ── 6. XDG directories ────────────────────────────────────────────────────────
Write-Step 'XDG base directories'

$xdgDirs = @(
    (Join-Path $home '.config'),
    (Join-Path $home '.local' 'share'),
    (Join-Path $home '.local' 'state'),
    (Join-Path $home '.cache')
)
foreach ($dir in $xdgDirs) {
    if ($PSCmdlet.ShouldProcess($dir, 'Create directory')) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Write-Ok $dir
    }
}

# ── 7. Git configuration ──────────────────────────────────────────────────────
Write-Step 'Git configuration'

$gitName  = $env:GIT_AUTHOR_NAME  ?? (Read-Host 'Git user.name')
$gitEmail = $env:GIT_AUTHOR_EMAIL ?? (Read-Host 'Git user.email')

if ($PSCmdlet.ShouldProcess('git config', 'Apply')) {
    git config --global user.name  $gitName
    git config --global user.email $gitEmail
    git config --global core.pager 'delta'
    git config --global delta.navigate       'true'
    git config --global delta.side-by-side   'true'
    git config --global delta.syntax-theme   'Catppuccin-mocha'
    git config --global interactive.diffFilter 'delta --color-only'
    Write-Ok "user.name=$gitName  user.email=$gitEmail  core.pager=delta"
}

# ── 8. chezmoi ────────────────────────────────────────────────────────────────
Write-Step 'chezmoi dotfile manager'

$chezmoiRepo = $env:CHEZMOI_REPO
if ($chezmoiRepo) {
    if ($PSCmdlet.ShouldProcess("chezmoi init $chezmoiRepo", 'Run')) {
        chezmoi init --apply $chezmoiRepo
        Write-Ok "chezmoi initialised from $chezmoiRepo"
    }
} else {
    Write-Skip 'CHEZMOI_REPO not set — skipping chezmoi init (set env var and re-run)'
}

# ── 9. Windows Terminal ───────────────────────────────────────────────────────
Write-Step 'Windows Terminal settings'

$wtSource = Join-Path $profileRoot 'WindowsTerminal' 'settings.json'
$wtDest   = Join-Path $env:LOCALAPPDATA 'Packages' `
    'Microsoft.WindowsTerminal_8wekyb3d8bbwe' 'LocalState' 'settings.json'

if (Test-Path $wtSource) {
    if ($PSCmdlet.ShouldProcess($wtDest, 'Copy Windows Terminal settings')) {
        Copy-Item -Path $wtSource -Destination $wtDest -Force
        Write-Ok 'Windows Terminal settings copied'
    }
} else {
    Write-Skip "No WindowsTerminal/settings.json in profile root — skipping"
}

# ── 10. VS Code extensions ────────────────────────────────────────────────────
Write-Step 'VS Code extensions'

$extensions = @(
    'ms-vscode.powershell',          # PowerShell
    'eamodio.gitlens',               # GitLens
    'catppuccin.catppuccin-vsc',     # Catppuccin theme
    'catppuccin.catppuccin-vsc-icons', # Catppuccin icons
    'ms-vscode-remote.remote-wsl',   # WSL
    'github.copilot'                 # Copilot (license required)
)

if (Get-Command code -ErrorAction Ignore) {
    foreach ($ext in $extensions) {
        if ($PSCmdlet.ShouldProcess($ext, 'code --install-extension')) {
            Write-Host "  Installing $ext…" -ForegroundColor DarkGray -NoNewline
            code --install-extension $ext 2>$null | Out-Null
            Write-Host ' ✓' -ForegroundColor Green
        }
    }
} else {
    Write-Skip 'VS Code CLI (code) not found — skipping extensions'
}

# ── 11. Profile symlink ───────────────────────────────────────────────────────
Write-Step 'Profile symlink'

$profilePath   = $PROFILE
$profileTarget = Join-Path $profileRoot 'profile.ps1'

if (Test-Path $profilePath) {
    Write-Ok "$profilePath already exists"
} else {
    if ($PSCmdlet.ShouldProcess("$profilePath → $profileTarget", 'Create symlink')) {
        New-Item -ItemType SymbolicLink -Path $profilePath -Target $profileTarget | Out-Null
        Write-Ok "Symlink created: $profilePath → $profileTarget"
    }
}

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host "`n✓ Bootstrap complete. Open a new terminal to load the profile." -ForegroundColor Green
