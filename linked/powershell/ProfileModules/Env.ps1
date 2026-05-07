#Requires -Version 7.0

# ── PATH helper ────────────────────────────────────────────────────────────────
function script:Add-ToPath {
    param([string]$Dir, [switch]$Prepend)
    if (-not $Dir) { return }
    if (-not [IO.Path]::IsPathRooted($Dir)) {
        Write-Warning "Add-ToPath: '$Dir' is not an absolute path — skipped."
        return
    }
    $normalized = [IO.Path]::GetFullPath($Dir)
    $existing = ($Env:Path -split [IO.Path]::PathSeparator) |
        Where-Object { $_ -and [IO.Path]::IsPathRooted($_) } |
        ForEach-Object { try { [IO.Path]::GetFullPath($_) } catch { $_ } }
    if ($normalized -notin $existing) {
        if ($Prepend) { $Env:Path = $normalized + [IO.Path]::PathSeparator + $Env:Path }
        else          { $Env:Path += [IO.Path]::PathSeparator + $normalized }
    }
}
# ─────────────────────────────────────────────────────────────────────────────

# Editor
$env:EDITOR     = 'code --wait'   # wait for VS Code tab to close (needed by git, etc.)
$env:VISUAL     = 'code --wait'   # POSIX tools that prefer VISUAL over EDITOR
$env:GIT_EDITOR = 'micro'         # terminal editor for git commit/rebase messages

# Terminal detection — set $isVSCodeTerm; fill TERM_PROGRAM for terminals that don't set it
$isVSCodeTerm = $Env:TERM_PROGRAM -eq 'vscode'
if (-not $Env:TERM_PROGRAM) {
    if      ($Env:ALACRITTY_LOG)        { $Env:TERM_PROGRAM = 'Alacritty' }
    elseif  ($Env:LC_EXTRATERM_COOKIE)  { $Env:TERM_PROGRAM = 'ExtraTerm' }
    elseif  ($env:WT_SESSION)           { $Env:TERM_PROGRAM = 'wt' }
}

# XDG Base Directory
$Env:XDG_CONFIG_HOME = Join-Path $home '.config'
$Env:XDG_DATA_HOME   = Join-Path $home '.local' 'share'
$Env:XDG_STATE_HOME  = Join-Path $home '.local' 'state'
$Env:XDG_CACHE_HOME  = Join-Path $home '.cache'
New-Item -ItemType Directory -Force -Path $Env:XDG_STATE_HOME -ErrorAction SilentlyContinue | Out-Null

# PATH: personal scripts
Add-ToPath (Join-Path $home 'scripts')

# Rust / Cargo — kept in Env.ps1 because PATH must be set before cli_tools_config.ps1
$Env:RUSTUP_HOME = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'rustup'
$Env:CARGO_HOME = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'cargo'
Add-ToPath (Join-Path $Env:CARGO_HOME 'bin')

# Python
if (Get-Command python -ErrorAction Ignore) {
    $pythonScripts = python -c "import sysconfig; print(sysconfig.get_path('scripts'))" 2>$null
    if ($LASTEXITCODE -ne 0) { $pythonScripts = $null }
    if ($pythonScripts) { Add-ToPath $pythonScripts -Prepend }
}
$Env:PYTHONPYCACHEPREFIX = Join-Path -Path $Env:XDG_CACHE_HOME -ChildPath 'python'
$Env:PYTHONUSERBASE = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'python'

# TODO: More XDG paths (https://wiki.archlinux.org/title/XDG_Base_Directory)
# DOCKER_CONFIG=$XDG_CONFIG_HOME/docker
# NPM_CONFIG_USERCONFIG=$XDG_CONFIG_HOME/npm/npmrc
# NVM_DIR=$XDG_DATA_HOME/nvm
# NODE_REPL_HISTORY=$XDG_DATA_HOME/node_repl_history
# GOPATH=$XDG_DATA_HOME/go

# Other tool paths
Add-ToPath (Join-Path $env:LOCALAPPDATA 'Programs' 'Pulsar')
$Env:GNUPGHOME = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'gnupg'

# Pager
if (Get-Command moor.exe -ErrorAction Ignore) {
    $Env:PAGER = 'moor'
    $Env:MOOR = '-style catppuccin-mocha -no-linenumbers'
} elseif (Get-Command bat.exe -ErrorAction Ignore) {
    $Env:PAGER = 'bat'
} elseif (Get-Command less.exe -ErrorAction Ignore) {
    $Env:PAGER = 'less -R'
} else {
    $Env:PAGER = 'more'
}

# Window manager configs
$Env:KOMOREBI_CONFIG_HOME = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'komorebi'

# PowerShell command defaults
$PSDefaultParameterValues = @{
    'Install-Module:Scope'      = 'CurrentUser'
    'Install-Module:Repository' = 'PSGallery'
    'Format-Table:AutoSize'     = $true
}

$Env:CLAUDE_CODE_USE_POWERSHELL_TOOL = '1'