<#
Fresh-machine setup for simsrw73/dotfiles-windows (chezmoi).

The repo is private, so get this file from the GitHub web UI (or a USB copy /
clone) and run it from Windows PowerShell or pwsh:
    powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1

It sets the XDG folders, turns on Developer Mode (one UAC prompt), installs
scoop + the tools chezmoi needs, signs in to GitHub and Bitwarden, then runs
`chezmoi init --apply`, which installs everything else.
#>
$ErrorActionPreference = 'Stop'

# The folders come first: every later install and sign-in (gh, bw) reads them,
# or writes to AppData. Keep in step with run_before_05-user-env.ps1.tmpl, which
# sets them again on every apply (tests/Dotfiles.Tests.ps1 checks the two match).
# Written to the registry without a broadcast: the sign-out at the end applies them.
$base = [ordered]@{
    XDG_CONFIG_HOME = Join-Path $HOME '.config'
    XDG_DATA_HOME   = Join-Path $HOME '.local\share'
    XDG_STATE_HOME  = Join-Path $HOME '.local\state'
    XDG_CACHE_HOME  = Join-Path $HOME '.cache'
    XDG_BIN_HOME    = Join-Path $HOME '.local\bin'
    SCOOP           = Join-Path $HOME '.local\share\scoop'
}
foreach ($k in $base.Keys) {
    Set-ItemProperty -Path 'HKCU:\Environment' -Name $k -Value $base[$k]
    Set-Item "env:$k" $base[$k]
}

# Developer Mode lets winget link its portable apps into one folder on PATH;
# without it, winget adds each app's own folder to PATH instead.
$devMode = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
if ((Get-ItemProperty $devMode -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense -ne 1) {
    $reg = Start-Process reg.exe -Verb RunAs -Wait -PassThru -ArgumentList 'add',
        'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock',
        '/v', 'AllowDevelopmentWithoutDevLicense', '/t', 'REG_DWORD', '/d', '1', '/f'
    if ($reg.ExitCode -ne 0) { throw "Turning on Developer Mode failed (reg.exe exit $($reg.ExitCode))." }
}

if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
    Invoke-RestMethod get.scoop.sh | Invoke-Expression
}
$env:PATH = "$env:SCOOP\shims;$env:PATH"

scoop install git
scoop bucket add extras
scoop install chezmoi bitwarden-cli gsudo gh gitleaks

# pwsh from winget (Microsoft's own package, MSIX: no admin, `pwsh` is on PATH at once).
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    winget install --id Microsoft.PowerShell --exact --source winget --disable-interactivity `
        --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "winget could not install PowerShell (exit $LASTEXITCODE)." }
}

gh auth status *> $null
if ($LASTEXITCODE -ne 0) { gh auth login --hostname github.com --git-protocol https --web }
gh auth setup-git

if ((bw status | ConvertFrom-Json).status -eq 'unauthenticated') { bw login }

$src = Join-Path $HOME '.local\share\chezmoi'
chezmoi init https://github.com/simsrw73/dotfiles-windows.git --source $src
git -C $src config core.hooksPath .githooks
git -C $src config filter.flowstate.clean "sed -E -f lib/flow-state.sed"
chezmoi apply -v

Write-Host ''
Write-Host 'Done. Sign out and back in (env vars, wpmd logon task), then open a new terminal.'
Write-Host 'Re-login where needed: gh (done), Claude Code, Copilot, Docker, OneDrive.'
Write-Host 'Scoop install notes (reg imports, context menus): ~\.local\state\dotfiles\scoop-notes-*.md'
