#Requires -Version 7
<#
One-time switch from "~/.config is a git repo" to chezmoi.

Run from a plain pwsh window with Claude Code, komorebi, yasb, AutoHotkey,
FlowLauncher and wpmd closed. Safe to re-run if a step fails: nothing is
deleted; live folders are renamed to <name>.pre-chezmoi-<date>.
#>
$ErrorActionPreference = 'Stop'
$cfg = Join-Path $HOME '.config'
$src = Join-Path $HOME '.local\share\chezmoi'
$backup = Join-Path $HOME 'dotfiles-backup-2026-09-27'
$linkedNames = 'AutoHotKey', 'FlowLauncher', 'yasb', 'komorebi', 'wpm', 'claude', 'psmux', 'yazi', 'nvim'

$running = Get-Process -Name claude, komorebi, komorebi-bar, whkd, yasb, AutoHotkey64, AutoHotkey64_UIA, Flow.Launcher, wpmd -ErrorAction SilentlyContinue
if ($running) { throw "Close these first: $(($running.ProcessName | Sort-Object -Unique) -join ', ')" }

# 1. source repo
if (-not (Test-Path $src)) {
    git clone --recurse-submodules -b chezmoi https://github.com/simsrw73/dotfiles-windows.git $src
    if ($LASTEXITCODE) { throw 'clone failed' }
}
git -C $src config core.hooksPath .githooks
Import-Module (Join-Path $src 'lib\Dotfiles.psm1') -Force

# 2. ~/.config stops being a git repo
if (Test-Path (Join-Path $cfg '.git')) {
    Write-Host 'Uncommitted changes in ~/.config (live files win; review them afterwards with `chezmoi diff` / git status in the source):'
    git -C $cfg status --short
    Move-Item (Join-Path $cfg '.git') (Join-Path $backup 'dot-config.git')
}
foreach ($f in '.gitignore', '.gitmodules', 'README.md') {
    $p = Join-Path $cfg $f
    if (Test-Path $p) { Move-Item $p (Join-Path $backup "dot-config$f") -Force }
}

# 3. live folders -> linked/ (keeps ignored runtime files; live bytes win)
foreach ($n in $linkedNames) {
    $r = Move-IntoLinked -Live (Join-Path $cfg $n) -Linked (Join-Path $src "linked\$n")
    Write-Host "$n : $r"
}

Write-Host ''
Write-Host 'Next:'
Write-Host '  chezmoi init            # regenerates chezmoi.toml from the template'
Write-Host '  chezmoi diff            # expect: .env reorder, the two profile stubs, scripts'
Write-Host '  chezmoi apply -v        # Bitwarden prompt once'
Write-Host "  git -C $src status      # files where the live version differed from the commit"
