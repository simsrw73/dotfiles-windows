#Requires -Version 7.0

# Editor
$env:EDITOR = 'code'

# Terminal detection
$isVSCodeTerm = $false
if ($Env:TERM_PROGRAM -eq 'WezTerm') {
    Write-Host 'WezTerm detected'
} elseif ($Env:TERM_PROGRAM -eq 'Tabby') {
    Write-Host 'Tabby detected'
} elseif ($Env:TERM_PROGRAM -eq 'Hyper') {
    Write-Host 'Hyper Terminal detected'
} elseif ($Env:TERM_PROGRAM -eq 'vscode') {
    $isVSCodeTerm = $true
    Write-Host 'VS Code Terminal'
} elseif ($Env:TERM_PROGRAM -ilike 'sublime') {
    # eg Terminus-Sublime
    Write-Host 'Sublime Terminal'
} elseif ($Env:ALACRITTY_LOG) {
    $Env:TERM_PROGRAM = 'Alacritty'
    Write-Host 'Alacritty Terminal detected'
} elseif ($Env:LC_EXTRATERM_COOKIE) {
    $Env:TERM_PROGRAM = 'ExtraTerm'
    Write-Host 'ExtraTerm detected'
} elseif ($env:WT_SESSION) {
    # unreliable; this can be true if editor is launched from wt
    $Env:TERM_PROGRAM = 'wt'
    Write-Host 'Windows Terminal detected'
} else {
    Write-Host 'Terminal not detected'
}

# XDG Base Directory
$Env:XDG_CONFIG_HOME = Join-Path -Path $home -ChildPath '.config'
$Env:XDG_DATA_HOME = Join-Path -Path $home -ChildPath '.local' 'share'
$Env:XDG_STATE_HOME = Join-Path -Path $home -ChildPath '.local' 'state'
$Env:XDG_CACHE_HOME = Join-Path -Path $home -ChildPath '.cache'

# PATH: personal scripts
$Env:Path += [IO.Path]::PathSeparator + (Join-Path $home 'scripts')

# Rust / Cargo
$Env:RUSTUP_HOME = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'rustup'
$Env:CARGO_HOME = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'cargo'
$Env:Path += [IO.Path]::PathSeparator + (Join-Path $Env:CARGO_HOME 'bin')

# Python
$pythonScriptsPath = python -c "import sysconfig; print(sysconfig.get_path('scripts'))" 2>$null
if ($pythonScriptsPath -and ($env:Path -split ';' -notcontains $pythonScriptsPath)) {
    $env:Path = "$pythonScriptsPath;$env:Path"
}
$Env:PYTHONPYCACHEPREFIX = Join-Path -Path $Env:XDG_CACHE_HOME -ChildPath 'python'
$Env:PYTHONUSERBASE = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'python'
$Env:Path += [IO.Path]::PathSeparator + (Join-Path $Env:XDG_DATA_HOME 'python' 'Python311' 'Scripts')

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
if (Get-Command moor.exe -ErrorAction SilentlyContinue) {
    $Env:PAGER = 'moor'
    $Env:MOOR = '-style catppuccin-mocha -no-linenumbers'
} elseif (Get-Command bat.exe -ErrorAction SilentlyContinue) {
    $Env:PAGER = 'bat'
} elseif (Get-Command less.exe -ErrorAction SilentlyContinue) {
    $Env:PAGER = 'less -R'
} else {
    $Env:PAGER = 'more'
}

# bat config moved to cli_tools_config.ps1

# oh-my-posh
$Env:POSH_GIT_ENABLED = $true

# fzf — Catppuccin Mocha theme
$Env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git'
$Env:FZF_ALT_C_COMMAND = 'fd -H -L -E .git -t d'
$Env:FZF_ALT_C_OPTS = '--preview "eza -a --icons --group-directories-first --color=always {}"'
$Env:FZF_DEFAULT_OPTS = @'
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
--exact
--no-sort
--layout=reverse
--border
--cycle
--height 50%
'@
$Env:FZF_CTRL_T_OPTS = '--preview "bat --color=always --line-range=:500 {}"'
$Env:FZF_CTRL_T_COMMAND = 'fd -H -L -E .git -t f'

# zoxide data dir (must be set before zoxide init in Completers.ps1)
$Env:_ZO_DATA_DIR = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'zoxide'

# Window manager configs
$Env:KOMOREBI_CONFIG_HOME = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'komorebi'

# PowerShell command defaults
$PSDefaultParameterValues = @{
    'Install-Module:Scope'      = 'CurrentUser'
    'Install-Module:Repository' = 'PSGallery'
    'Format-Table:AutoSize'     = $true
    'Get-Help:ShowWindow'       = $true
}

Set-Variable CLAUDE_CODE_USE_POWERSHELL_TOOL=1