<#
Fresh-machine setup for simsrw73/dotfiles-windows (chezmoi).

The repo is private, so get this file from the GitHub web UI (or a USB copy /
clone) and run it from Windows PowerShell or pwsh:
    powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1

It installs scoop + the tools chezmoi needs, signs in to GitHub and Bitwarden,
then runs `chezmoi init --apply`, which installs everything else.
#>
$ErrorActionPreference = 'Stop'
$env:SCOOP = Join-Path $HOME '.local\share\scoop'
[Environment]::SetEnvironmentVariable('SCOOP', $env:SCOOP, 'User')

if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
    Invoke-RestMethod get.scoop.sh | Invoke-Expression
}
$env:PATH = "$env:SCOOP\shims;$env:PATH"

scoop install git
scoop bucket add extras
scoop install pwsh chezmoi bitwarden-cli gsudo gh gitleaks

gh auth status *> $null
if ($LASTEXITCODE -ne 0) { gh auth login --hostname github.com --git-protocol https --web }
gh auth setup-git

if ((bw status | ConvertFrom-Json).status -eq 'unauthenticated') { bw login }

$src = Join-Path $HOME '.local\share\chezmoi'
chezmoi init https://github.com/simsrw73/dotfiles-windows.git --source $src
git -C $src config core.hooksPath .githooks
chezmoi apply -v

Write-Host ''
Write-Host 'Done. Sign out and back in (env vars, wpmd logon task), then open a new terminal.'
Write-Host 'Re-login where needed: gh (done), Claude Code, Copilot, Docker, OneDrive.'
