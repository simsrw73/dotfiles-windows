#Requires -Version 7.0

# Editor
$env:EDITOR = 'code'

# Terminal detection — set $isVSCodeTerm; fill TERM_PROGRAM for terminals that don't set it
$isVSCodeTerm = $Env:TERM_PROGRAM -eq 'vscode'
if (-not $Env:TERM_PROGRAM) {
    if      ($Env:ALACRITTY_LOG)        { $Env:TERM_PROGRAM = 'Alacritty' }
    elseif  ($Env:LC_EXTRATERM_COOKIE)  { $Env:TERM_PROGRAM = 'ExtraTerm' }
    elseif  ($env:WT_SESSION)           { $Env:TERM_PROGRAM = 'wt' }
}

# XDG Base Directory
$Env:XDG_CONFIG_HOME = Join-Path -Path $home -ChildPath '.config'
$Env:XDG_DATA_HOME = Join-Path -Path $home -ChildPath '.local' 'share'
$Env:XDG_STATE_HOME = Join-Path -Path $home -ChildPath '.local' 'state'
$Env:XDG_CACHE_HOME = Join-Path -Path $home -ChildPath '.cache'

# PATH: personal scripts
$Env:Path += [IO.Path]::PathSeparator + (Join-Path $home 'scripts')

# Rust / Cargo — kept in Env.ps1 because PATH must be set before cli_tools_config.ps1
$Env:RUSTUP_HOME = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'rustup'
$Env:CARGO_HOME = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'cargo'
$Env:Path += [IO.Path]::PathSeparator + (Join-Path $Env:CARGO_HOME 'bin')

# Python
if (Get-Command python -ErrorAction Ignore) {
    $pythonScriptsPath = python -c "import sysconfig; print(sysconfig.get_path('scripts'))" 2>$null
    if ($pythonScriptsPath -and ($env:Path -split ';' -notcontains $pythonScriptsPath)) {
        $env:Path = "$pythonScriptsPath;$env:Path"
    }
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
$Env:Path += [IO.Path]::PathSeparator + (Join-Path $env:LOCALAPPDATA 'Programs' 'Pulsar')
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

# bat config moved to cli_tools_config.ps1

# POSH_GIT_ENABLED moved to cli_tools_config.ps1

# fzf config moved to cli_tools_config.ps1
# zoxide config moved to cli_tools_config.ps1

# Window manager configs
$Env:KOMOREBI_CONFIG_HOME = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'komorebi'

# PowerShell command defaults
$PSDefaultParameterValues = @{
    'Install-Module:Scope'      = 'CurrentUser'
    'Install-Module:Repository' = 'PSGallery'
    'Format-Table:AutoSize'     = $true
}

$Env:CLAUDE_CODE_USE_POWERSHELL_TOOL = '1'