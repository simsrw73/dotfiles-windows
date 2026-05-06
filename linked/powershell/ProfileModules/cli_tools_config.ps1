#Requires -Version 7.0
# cli_tools_config.ps1  -  Per-tool configuration: XDG paths, functions, aliases, completers, fzf pickers
# Each tool gets one #region/#endregion block. Guards check tool availability before applying config.

$ErrorActionPreference = 'Stop'

# ── Tool availability tracking ────────────────────────────────────────────────
$script:_toolsFound   = [System.Collections.Generic.List[string]]::new()
$script:_toolsMissing = [System.Collections.Generic.List[string]]::new()

function script:_HasCmd {
    param([string]$Label, [string]$Exe = '')
    if (-not $Exe) { $Exe = "$Label.exe" }
    if ($null -ne (Get-Command $Exe -ErrorAction Ignore)) {
        $null = $script:_toolsFound.Add($Label); $true
    } else {
        $null = $script:_toolsMissing.Add($Label); $false
    }
}

function script:_HasMod {
    param([string]$Label, [string]$Module = '')
    if (-not $Module) { $Module = $Label }
    if ($null -ne (Get-Module -Name $Module)) {
        $null = $script:_toolsFound.Add($Label); $true
    } else {
        $null = $script:_toolsMissing.Add($Label); $false
    }
}
# ─────────────────────────────────────────────────────────────────────────────

# ==============================================================================
# Group 1  -  File/directory tools
# ==============================================================================

#region eza  -  modern ls replacement
if (_HasCmd 'eza') {
    # --- Functions / Aliases ---
    $eza = (Get-Command eza.exe).Path.ToString()
    function global:_ls { & $eza --color=auto --icons --group-directories-first @args }
    function global:_ll { & $eza --all --long --header @args }
    function global:_la { & $eza --all --group @args }
    function global:_tree { & $eza --tree @args }
    Set-Alias -Name ls -Value _ls -Scope Global
    Set-Alias -Name ll -Value _ll -Scope Global
    Set-Alias -Name la -Value _la -Scope Global
    Set-Alias -Name tree -Value _tree -Scope Global
    # --- Completers ---
    Register-ArgumentCompleter -Native -CommandName eza -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $flags = @(
            '--long', '--all', '--tree', '--icons', '--git', '--color',
            '--group-directories-first', '--sort', '--reverse', '--header',
            '--group', '--oneline', '--classify', '--level', '--ignore-glob',
            '--time-style', '--hyperlink', '--no-permissions', '--no-filesize',
            '--no-user', '--no-time', '--stdin', '--list-dirs', '--dereference'
        )
        $flags | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
    # --- Fzf Pickers ---
    function global:Select-File {
        [CmdletBinding()]
        param([string]$Path = '.')
        $result = eza --icons -1 --color=always $Path |
            fzf --ansi --preview 'bat --color=always --line-range=:200 {}' `
                --preview-window 'right:55%' `
                --header 'Select file (Enter to open, Ctrl-C to cancel)'
        if ($result) { $result }
    }
    Set-Alias -Name ff -Value Select-File -Scope Global
}
#endregion eza

#region bat  -  modern cat replacement
# Join-Files works with or without bat (falls back to Get-Content)
function global:Join-Files {
    if (Get-Command bat.exe -ErrorAction Ignore) {
        $bat = (Get-Command bat.exe).Path.ToString()
        & $bat -pp $args
    } else {
        Get-Content $args
    }
}
Set-Alias -Name cat -Value Join-Files -Scope Global -Force

if (_HasCmd 'bat') {
    # --- XDG / Config paths ---
    $Env:BAT_CONFIG_PATH = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'bat' 'bat.conf'
    # --- Completers ---
    Register-ArgumentCompleter -Native -CommandName bat -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $flags = @(
            '--language', '--theme', '--style', '--paging', '--color',
            '--line-range', '--highlight-line', '--diff', '--show-all',
            '--plain', '--number', '--decorations', '--italic-text',
            '--tabs', '--wrap', '--terminal-width', '--map-syntax',
            '--list-languages', '--list-themes'
        )
        $flags | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
    # TODO: Fzf Pickers
}
#endregion bat

#region fd  -  modern find replacement
if (_HasCmd 'fd') {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # --- Completers ---
    fd --gen-completions powershell | Out-String | Invoke-Expression
    # --- Fzf Pickers ---
    function global:Select-FdResult {
        [CmdletBinding()]
        param(
            [string]$Pattern = '',
            [string]$Path = '.',
            [ValidateSet('file', 'directory', 'any')]
            [string]$Type = 'file'
        )
        $fdArgs = @('--color=always')
        if ($Pattern) { $fdArgs += $Pattern }
        if ($Path -ne '.') { $fdArgs += $Path }
        if ($Type -ne 'any') { $fdArgs += '--type'; $fdArgs += $Type }
        $result = fd @fdArgs 2>$null |
            fzf --ansi `
                --preview 'bat --color=always --line-range=:100 {} 2>/dev/null || eza --icons --color=always {}' `
                --preview-window 'right:50%' `
                --header 'Select file/dir'
        if ($result) { $result }
    }
    Set-Alias -Name ffd -Value Select-FdResult -Scope Global
}
#endregion fd

#region ripgrep  -  fast grep
if (_HasCmd 'rg') {
    # --- XDG / Config paths ---
    $Env:RIPGREP_CONFIG_PATH = Join-Path $Env:XDG_CONFIG_HOME 'ripgrep' 'ripgreprc'
    # Create a default ripgreprc if it doesn't exist
    $ripgrepDir = Join-Path $Env:XDG_CONFIG_HOME 'ripgrep'
    if (-not (Test-Path $ripgrepDir)) {
        New-Item -ItemType Directory -Force -Path $ripgrepDir | Out-Null
        Set-Content -Path $Env:RIPGREP_CONFIG_PATH -Value "# ripgrep config`n--smart-case`n--hidden" -Encoding UTF8
    }
    # TODO: Functions / Aliases
    # --- Completers ---
    rg --generate complete-powershell | Out-String | Invoke-Expression
    # --- Fzf Pickers ---
    function global:Select-RipgrepResult {
        [CmdletBinding()]
        param(
            [string]$Pattern = '',
            [string]$Path = '.'
        )
        if (-not $Pattern) { $Pattern = Read-Host 'Search pattern' }
        $result = rg --line-number --no-heading --color=always $Pattern $Path 2>$null |
            fzf --ansi `
                --delimiter ':' `
                --preview 'bat --color=always --highlight-line {2} {1}' `
                --preview-window 'right:55%:+{2}+3/3' `
                --header 'Select result (Enter to open in $EDITOR)'
        if ($result) {
            $file, $line = ($result -split ':')[0..1]
            & $Env:EDITOR $file
        }
    }
    Set-Alias -Name frg -Value Select-RipgrepResult -Scope Global
}
#endregion ripgrep

#region broot  -  interactive file browser
if (_HasCmd 'broot') {
    # --- XDG / Config paths ---
    # broot respects $XDG_CONFIG_HOME on all platforms when set
    $brootConfig = Join-Path $Env:XDG_CONFIG_HOME 'broot'
    New-Item -ItemType Directory -Force -Path $brootConfig | Out-Null
    # TODO: Functions / Aliases
    # --- Completers ---
    Register-ArgumentCompleter -Native -CommandName broot -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $flags = @(
            '--sizes', '--dates', '--permissions', '--hidden', '--git-ignored',
            '--no-sizes', '--no-dates', '--no-permissions',
            '--color', '--cmd', '--conf', '--outcmd',
            '--sort-by-count', '--sort-by-date', '--sort-by-size',
            '--whale-spotting', '--only-folders', '--show-root-fs',
            '--install', '--print-shell-function', '--help', '--version'
        )
        $flags | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
    # TODO: Fzf Pickers
}
#endregion broot

#region lsd  -  another ls alternative
# NOTE: lsd conflicts with eza; enable only if eza is removed
if (_HasCmd 'lsd') {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion lsd

# ==============================================================================
# Group 2  -  Text/data tools
# ==============================================================================

#region jq  -  JSON processor
if (_HasCmd 'jq') {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # --- Fzf Pickers ---
    function global:Select-JsonPath {
        [CmdletBinding()]
        param([string]$File = '')
        if (-not $File) {
            $File = fzf --header 'Select JSON file' --preview 'bat --color=always {}'
        }
        if (-not $File -or -not (Test-Path $File)) { return }
        # Interactive jq filter: pipe JSON through fzf, updating preview with each keystroke
        $json = Get-Content $File -Raw
        $filter = Read-Host 'jq filter (default: .)'
        if (-not $filter) { $filter = '.' }
        $json | jq $filter
    }
    Set-Alias -Name fjq -Value Select-JsonPath -Scope Global
}
#endregion jq

#region fx  -  interactive JSON viewer
if (_HasCmd 'fx') {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion fx

#region jid  -  interactive JSON editor
if (_HasCmd 'jid') {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion jid

#region glow  -  markdown reader
if (_HasCmd 'glow') {
    # --- XDG / Config paths ---
    $Env:GLOW_CONFIG_DIR = Join-Path $Env:XDG_CONFIG_HOME 'glow'
    New-Item -ItemType Directory -Force -Path $Env:GLOW_CONFIG_DIR | Out-Null
    # TODO: Functions / Aliases
    # --- Completers ---
    glow completion powershell | Out-String | Invoke-Expression
    # --- Fzf Pickers ---
    function global:Read-MarkdownFile {
        [CmdletBinding()]
        param([string]$Path = '.')
        $file = Get-ChildItem -Path $Path -Recurse -Filter '*.md' -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName |
            fzf --preview 'glow --style dark {}' `
                --preview-window 'right:60%' `
                --header 'Select markdown file (Enter to render with glow)'
        if ($file) { glow $file }
    }
    Set-Alias -Name fgl -Value Read-MarkdownFile -Scope Global
}
#endregion glow

# ==============================================================================
# Group 3  -  System tools
# ==============================================================================

#region procs  -  modern ps replacement
if (_HasCmd 'procs') {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # --- Completers ---
    procs --gen-completion-out powershell | Out-String | Invoke-Expression
    # --- Fzf Pickers ---
    function global:Select-Process {
        [CmdletBinding()]
        param()
        $proc = procs --color=always 2>$null |
            Select-Object -Skip 1 |
            fzf --ansi `
                --header 'Select process to kill (Enter to Stop-Process, Ctrl-C to cancel)' `
                --preview-window 'hidden'
        if ($proc) {
            $procId = ($proc -split '\s+')[1]
            if ($procId -match '^\d+$') {
                Stop-Process -Id $procId -Confirm
            }
        }
    }
    Set-Alias -Name fkill -Value Select-Process -Scope Global
}
#endregion procs

#region duf  -  modern df replacement
if (_HasCmd 'duf') {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion duf

#region dua  -  disk usage analyzer
if (_HasCmd 'dua') {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion dua

#region gdu  -  disk usage TUI
if (_HasCmd 'gdu') {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion gdu

#region ntop  -  TUI process monitor
if (_HasCmd 'ntop') {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion ntop

#region winfetch  -  system info
if (_HasCmd 'winfetch' -Exe 'winfetch') {
    # --- XDG / Config paths ---
    $Env:WINFETCH_CONFIG_PATH = Join-Path $Env:XDG_CONFIG_HOME 'winfetch' 'config.ps1'
    $winfetchDir = Join-Path $Env:XDG_CONFIG_HOME 'winfetch'
    if (-not (Test-Path $winfetchDir)) {
        New-Item -ItemType Directory -Force -Path $winfetchDir | Out-Null
    }
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion winfetch

# ==============================================================================
# Group 4  -  Network/download tools
# ==============================================================================

#region curl  -  HTTP client
if (_HasCmd 'curl') {
    # --- XDG / Config paths ---
    $Env:CURL_HOME = Join-Path $Env:XDG_CONFIG_HOME 'curl'
    New-Item -ItemType Directory -Force -Path $Env:CURL_HOME | Out-Null
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion curl

#region wget  -  downloader
if (_HasCmd 'wget') {
    # --- XDG / Config paths ---
    $Env:WGETRC = Join-Path $Env:XDG_CONFIG_HOME 'wget' 'wgetrc'
    $wgetDir = Join-Path $Env:XDG_CONFIG_HOME 'wget'
    if (-not (Test-Path $wgetDir)) {
        New-Item -ItemType Directory -Force -Path $wgetDir | Out-Null
        New-Item -ItemType File -Force -Path $Env:WGETRC | Out-Null
    }
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion wget

#region docker  -  container runtime
# Set DOCKER_CONFIG unconditionally so docker-compose and other tools use XDG path
$Env:DOCKER_CONFIG = Join-Path $Env:XDG_CONFIG_HOME 'docker'
New-Item -ItemType Directory -Force -Path $Env:DOCKER_CONFIG | Out-Null
if (_HasCmd 'docker' -Exe 'docker') {
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion docker

# ==============================================================================
# Group 5  -  Editors
# ==============================================================================

#region nano  -  text editor
if (_HasCmd 'nano') {
    # --- XDG / Config paths ---
    $Env:NANORC = Join-Path $Env:XDG_CONFIG_HOME 'nano' 'nanorc'
    $nanoDir = Join-Path $Env:XDG_CONFIG_HOME 'nano'
    if (-not (Test-Path $nanoDir)) {
        New-Item -ItemType Directory -Force -Path $nanoDir | Out-Null
        New-Item -ItemType File -Force -Path $Env:NANORC | Out-Null
    }
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion nano

#region micro  -  modern terminal editor
if (_HasCmd 'micro') {
    # --- XDG / Config paths ---
    $Env:MICRO_CONF_DIR = Join-Path $Env:XDG_CONFIG_HOME 'micro'
    New-Item -ItemType Directory -Force -Path $Env:MICRO_CONF_DIR | Out-Null
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion micro

#region notepadplusplus  -  Notepad++ text editor
# edit alias: use Notepad++ if installed, fall back to notepad.exe
if (Test-Path -Path 'C:\Program Files\Notepad++\notepad++.exe' -PathType Leaf) {
    Set-Alias -Name edit -Value 'C:\Program Files\Notepad++\notepad++.exe' -Scope Global
} else {
    Set-Alias -Name edit -Value 'C:\Windows\system32\notepad.exe' -Scope Global
}
#endregion notepadplusplus

# ==============================================================================
# Group 6  -  Fuzzy finder
# ==============================================================================

#region fzf  -  fuzzy finder
if (_HasCmd 'fzf') {
    # --- Config ---
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
    # TODO: Fzf Pickers
}
#endregion fzf

# ==============================================================================
# Group 7  -  Navigation
# ==============================================================================

#region zoxide  -  smart cd
if (_HasCmd 'zoxide') {
    # --- XDG / Config paths ---
    $Env:_ZO_DATA_DIR = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'zoxide'

    # --- Init ---
    Invoke-Expression (& {
            $hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
            (zoxide init --hook $hook powershell | Out-String)
        })

    # --- Aliases ---
    if (Get-Command z -ErrorAction Ignore) {
        Set-Alias -Name cd -Value z -Scope Global -Option AllScope
    }
    # TODO: Completers
    # --- Fzf Pickers ---
    function global:Select-Directory {
        [CmdletBinding()]
        param()
        $dir = zoxide query --list |
            fzf --preview 'eza --icons --color=always {}' `
                --preview-window 'right:40%' `
                --header 'Select directory (Enter to cd)'
        if ($dir) { Set-Location $dir }
    }
    Set-Alias -Name fcd -Value Select-Directory -Scope Global
}
#endregion zoxide

# ==============================================================================
# Group 8  -  Pagers
# ==============================================================================

#region moor  -  modern pager
if (_HasCmd 'moor') {
    # PAGER and $Env:MOOR are set in Env.ps1 (PAGER detection runs early)
    # TODO: Fzf Pickers
}
#endregion moor

#region less  -  pager
if (_HasCmd 'less') {
    # --- XDG / Config paths ---
    $Env:LESSHISTFILE = Join-Path $Env:XDG_STATE_HOME 'less' 'history'
    $Env:LESSKEY      = Join-Path $Env:XDG_CONFIG_HOME 'less' 'lesskey'
    $lessStateDir  = Join-Path $Env:XDG_STATE_HOME 'less'
    $lessConfigDir = Join-Path $Env:XDG_CONFIG_HOME 'less'
    New-Item -ItemType Directory -Force -Path $lessStateDir  | Out-Null
    New-Item -ItemType Directory -Force -Path $lessConfigDir | Out-Null
    # --- Best-practice options ---
    $Env:LESS = '--RAW-CONTROL-CHARS --quit-if-one-screen --no-init'
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion less

# ==============================================================================
# Group 9  -  Package managers
# ==============================================================================

#region scoop  -  Windows package manager
if (_HasCmd 'scoop' -Exe 'scoop') {
    # --- scoop-search hook ---
    if (Get-Command scoop-search -ErrorAction Ignore) {
        . ([ScriptBlock]::Create((& scoop-search --hook | Out-String)))
    }
    # --- Functions ---
    function global:sstat { scoop update; scoop status }
    function global:supd { scoop update *; scoop cleanup * }
    # TODO: Completers
    # --- Fzf Pickers ---
    function global:Select-ScoopPackage {
        [CmdletBinding()]
        param([string]$Query = '')
        $pkg = sfsu search $Query 2>$null |
            fzf --header 'Select package to install (Enter to scoop install)' `
                --preview 'sfsu info {}' `
                --preview-window 'right:45%'
        if ($pkg) {
            $name = ($pkg -split '\s+')[0]
            Write-Host "Installing $name..." -ForegroundColor Cyan
            scoop install $name
        }
    }
    Set-Alias -Name sins -Value Select-ScoopPackage -Scope Global

    function global:Remove-ScoopPackage {
        [CmdletBinding()]
        param()
        $pkg = scoop list 2>$null | Select-Object -Skip 2 |
            Where-Object { $_ -match '\S' } |
            fzf --header 'Select package to uninstall (Enter to scoop uninstall)'
        if ($pkg) {
            $name = ($pkg -split '\s+')[0]
            Write-Host "Uninstalling $name..." -ForegroundColor Yellow
            scoop uninstall $name
        }
    }
    Set-Alias -Name srm -Value Remove-ScoopPackage -Scope Global
}
#endregion scoop

#region sfsu  -  fast scoop CLI
if (_HasCmd 'sfsu') {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # --- Completers ---
    Register-ArgumentCompleter -Native -CommandName sfsu -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $subcommands = @(
            'search', 'info', 'install', 'update', 'upgrade',
            'status', 'depends', 'checkver', 'cat', 'virustotal'
        )
        $subcommands | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
    # TODO: Fzf Pickers
}
#endregion sfsu

#region winget  -  Windows package manager
if (_HasCmd 'winget' -Exe 'winget') {
    # --- Functions ---
    function global:wstat { winget upgrade }
    function global:wupd { winget upgrade --all }
    # --- Completers ---
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
        $Local:word = $wordToComplete.Replace('"', '""')
        $Local:ast  = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
    }
    # --- Fzf Pickers ---
    function global:Select-WingetPackage {
        [CmdletBinding()]
        param([string]$Query = '')
        if (-not $Query) { $Query = Read-Host 'Search winget packages' }
        $pkg = winget search $Query 2>$null |
            Select-Object -Skip 2 |
            Where-Object { $_ -match '\S' } |
            fzf --header 'Select package to install (Enter to winget install)'
        if ($pkg) {
            $id = ($pkg -split '\s{2,}')[1]
            Write-Host "Installing $id..." -ForegroundColor Cyan
            winget install --id $id
        }
    }
    Set-Alias -Name wins -Value Select-WingetPackage -Scope Global

    function global:Remove-WingetPackage {
        [CmdletBinding()]
        param()
        $pkg = winget list 2>$null |
            Select-Object -Skip 3 |
            Where-Object { $_ -match '\S' } |
            fzf --header 'Select package to uninstall (Enter to winget uninstall)'
        if ($pkg) {
            $id = ($pkg -split '\s{2,}')[1]
            Write-Host "Uninstalling $id..." -ForegroundColor Yellow
            winget uninstall --id $id
        }
    }
    Set-Alias -Name wrm -Value Remove-WingetPackage -Scope Global
}
#endregion winget

# ==============================================================================
# Group 10  -  Dev tools
# ==============================================================================

#region cargo  -  Rust package manager
if (_HasCmd 'cargo') {
    # --- XDG / Config paths ---
    # CARGO_HOME and RUSTUP_HOME are set in Env.ps1 (PATH ordering requirement)
    # CARGO_HOME = $XDG_DATA_HOME/cargo, RUSTUP_HOME = $XDG_DATA_HOME/rustup
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion cargo

#region rustup  -  Rust toolchain manager
if (_HasCmd 'rustup') {
    # --- Completers ---
    rustup completions powershell | Out-String | Invoke-Expression
    # --- Fzf Pickers ---
    function global:Select-RustupToolchain {
        [CmdletBinding()]
        param()
        $toolchain = rustup toolchain list 2>$null |
            fzf --header 'Select Rust toolchain (Enter to rustup default)'
        if ($toolchain) {
            $name = ($toolchain -split '\s+')[0]
            rustup default $name
        }
    }
    Set-Alias -Name frtc -Value Select-RustupToolchain -Scope Global
}
#endregion rustup

#region nvm  -  Node version manager
if (_HasCmd 'nvm' -Exe 'nvm') {
    # --- XDG / Config paths ---
    $Env:NVM_DIR = Join-Path $Env:XDG_DATA_HOME 'nvm'
    # Note: nvm for Windows (scoop) uses NVM_HOME/NVM_SYMLINK instead; NVM_DIR is for Unix nvm
    # TODO: Functions / Aliases
    # --- Completers ---
    Register-ArgumentCompleter -Native -CommandName nvm -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $subcommands = @(
            'install', 'uninstall', 'use', 'list', 'ls', 'list available',
            'ls-remote', 'current', 'alias', 'unalias', 'reinstall-packages',
            'version', 'version-remote', 'deactivate', 'root', 'arch', 'node_mirror', 'npm_mirror'
        )
        $subcommands | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
    # --- Fzf Pickers ---
    function global:Select-NodeVersion {
        [CmdletBinding()]
        param()
        $version = nvm list 2>$null |
            Where-Object { $_ -match '\d+\.\d+' } |
            fzf --header 'Select Node.js version (Enter to nvm use)'
        if ($version) {
            $ver = ($version -replace '[^\d.]', '').Trim()
            nvm use $ver
        }
    }
    Set-Alias -Name fnv -Value Select-NodeVersion -Scope Global
}
#endregion nvm

#region npm  -  Node package manager
if (_HasCmd 'npm' -Exe 'npm') {
    # --- XDG / Config paths ---
    $Env:NPM_CONFIG_USERCONFIG = Join-Path $Env:XDG_CONFIG_HOME 'npm' 'npmrc'
    $npmConfigDir = Join-Path $Env:XDG_CONFIG_HOME 'npm'
    if (-not (Test-Path $npmConfigDir)) {
        New-Item -ItemType Directory -Force -Path $npmConfigDir | Out-Null
    }
    $Env:NODE_REPL_HISTORY = Join-Path $Env:XDG_DATA_HOME 'node_repl_history'
    # --- Functions ---
    function global:nls { npm list -g --depth=0 }
    # --- Completers ---
    Register-ArgumentCompleter -Native -CommandName npm -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $subcommands = @(
            'install', 'uninstall', 'update', 'run', 'start', 'stop', 'test',
            'list', 'link', 'unlink', 'publish', 'pack', 'version', 'view',
            'search', 'audit', 'fund', 'init', 'exec', 'prefix', 'config',
            'cache', 'rebuild', 'prune', 'outdated', 'ci', 'dedupe', 'diff'
        )
        $subcommands | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
    # --- Fzf Pickers ---
    function global:Select-NpmScript {
        [CmdletBinding()]
        param()
        if (-not (Test-Path 'package.json')) {
            Write-Warning 'No package.json in current directory'
            return
        }
        $scripts = (Get-Content 'package.json' -Raw | ConvertFrom-Json).scripts.PSObject.Properties |
            ForEach-Object { "$($_.Name)" }
        $script = $scripts | fzf --header 'Select npm script (Enter to npm run)'
        if ($script) { npm run $script }
    }
    Set-Alias -Name fns -Value Select-NpmScript -Scope Global
}
#endregion npm

# ==============================================================================
# Group 11  -  Python tools
# ==============================================================================

#region uv  -  fast Python package manager
if (_HasCmd 'uv') {
    # --- XDG / Config paths ---
    $Env:UV_CACHE_DIR = Join-Path $Env:XDG_CACHE_HOME 'uv'
    $Env:UV_DATA_DIR  = Join-Path $Env:XDG_DATA_HOME  'uv'
    New-Item -ItemType Directory -Force -Path $Env:UV_CACHE_DIR | Out-Null
    New-Item -ItemType Directory -Force -Path $Env:UV_DATA_DIR  | Out-Null
    # TODO: Functions / Aliases
    # --- Completers ---
    Register-ArgumentCompleter -Native -CommandName uv -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $subcommands = @(
            'pip', 'venv', 'run', 'sync', 'lock', 'add', 'remove', 'tool',
            'python', 'init', 'build', 'publish', 'cache', 'self', 'version',
            'help', 'export', 'tree', 'generate-shell-completion'
        )
        $subcommands | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
    # --- Fzf Pickers ---
    function global:Select-UvVenv {
        [CmdletBinding()]
        param([string]$SearchPath = $home)
        $venv = Get-ChildItem -Path $SearchPath -Recurse -Depth 4 -Filter 'pyvenv.cfg' -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty DirectoryName |
            fzf --preview 'cat {}/pyvenv.cfg' `
                --preview-window 'right:40%' `
                --header 'Select Python venv to activate'
        if ($venv) {
            $activate = Join-Path $venv 'Scripts' 'Activate.ps1'
            if (Test-Path $activate) { & $activate }
            else { Write-Warning "No Activate.ps1 found in $venv" }
        }
    }
    Set-Alias -Name fvenv -Value Select-UvVenv -Scope Global
}
#endregion uv

# ==============================================================================
# Group 12  -  Dotfiles/config management
# ==============================================================================

#region chezmoi  -  dotfile manager
if (_HasCmd 'chezmoi') {
    # --- XDG / Config paths ---
    $Env:CHEZMOI_CONFIG_DIR = Join-Path $Env:XDG_CONFIG_HOME 'chezmoi'
    New-Item -ItemType Directory -Force -Path $Env:CHEZMOI_CONFIG_DIR | Out-Null
    # --- Aliases ---
    Set-Alias -Name cz -Value chezmoi -Scope Global
    # --- Completers ---
    chezmoi completion powershell | Out-String | Invoke-Expression
    # --- Fzf Pickers ---
    function global:Edit-DotFile {
        [CmdletBinding()]
        param()
        $file = chezmoi managed 2>$null |
            fzf --preview 'bat --color=always {}' `
                --preview-window 'right:55%' `
                --header 'Select dotfile to edit (Enter to chezmoi edit)'
        if ($file) { chezmoi edit $file }
    }
    Set-Alias -Name czf -Value Edit-DotFile -Scope Global
}
#endregion chezmoi

# ==============================================================================
# Group 13  -  Security/secrets
# ==============================================================================

#region bitwarden  -  secrets manager
if (_HasCmd 'bw' -Exe 'bw') {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # --- Completers ---
    Register-ArgumentCompleter -Native -CommandName bw -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $subcommands = @(
            'login', 'logout', 'lock', 'unlock', 'sync', 'list', 'get',
            'create', 'edit', 'delete', 'restore', 'move', 'confirm',
            'import', 'export', 'generate', 'encode', 'config', 'update',
            'completion', 'status', 'serve', 'receive'
        )
        $subcommands | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
    # --- Fzf Pickers ---
    function global:Select-BwItem {
        [CmdletBinding()]
        param(
            [ValidateSet('login', 'note', 'card', 'identity', 'all')]
            [string]$Type = 'all'
        )
        $bwArgs = @('list', 'items')
        if ($Type -ne 'all') { $bwArgs += '--search'; $bwArgs += $Type }
        $items = bw @bwArgs 2>$null | ConvertFrom-Json
        if (-not $items) { Write-Warning 'No items found. Are you logged in? Run: bw login'; return }
        $selected = $items | ForEach-Object { "$($_.name)`t$($_.id)" } |
            fzf --delimiter "`t" --with-nth 1 `
                --header 'Select vault item (Enter to copy password)'
        if ($selected) {
            $id = ($selected -split "`t")[1]
            bw get password $id | Set-Clipboard
            Write-Host 'Password copied to clipboard.' -ForegroundColor Green
        }
    }
    Set-Alias -Name fbw -Value Select-BwItem -Scope Global
}
#endregion bitwarden

# ==============================================================================
# Group 14  -  AI tools
# ==============================================================================

#region gemini  -  Gemini CLI
if (_HasCmd 'gemini' -Exe 'gemini') {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion gemini

# ==============================================================================
# Group 15  -  Clipboard
# ==============================================================================

#region win32yank  -  clipboard utility
if (_HasCmd 'win32yank') {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion win32yank

# ==============================================================================
# Group 16  -  Elevation
# ==============================================================================

#region gsudo  -  elevation tool
if (_HasMod 'gsudo' -Module 'gsudoModule') {
    Import-Module gsudoModule -ErrorAction SilentlyContinue
    # TODO: Completers / Fzf Pickers
}
#endregion gsudo

# ==============================================================================
# Group 17  -  Window management
# ==============================================================================

#region glazewm  -  tiling window manager
if (_HasCmd 'glazewm') {
    # --- Functions ---
    function global:Start-GlazeWM {
        $wm = (Get-Command glazewm.exe).Path.ToString()
        $glaze_config = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'glazewm' 'config.yaml'
        & $wm --config=$glaze_config $args
    }
    # --- Aliases ---
    Set-Alias -Name glazewm -Value Start-GlazeWM -Scope Global
}
#endregion glazewm

# ==============================================================================
# Group 18  -  Misc utilities
# ==============================================================================

#region mosquitto  -  MQTT client
if (_HasCmd 'mosquitto') {
    # --- Functions ---
    function global:Invoke-MQTT {
        $mqtt_config_file = Join-Path -Path $home -ChildPath '.mosquitto' 'config'
        mosquitto -v -c $mqtt_config_file
    }
    # --- Aliases ---
    Set-Alias -Name mqtt -Value Invoke-MQTT -Scope Global
}
#endregion mosquitto

# ==============================================================================
# Group 19  -  PowerShell modules
# ==============================================================================

#region posh-git  -  git prompt info
if (_HasMod 'posh-git') {
    Import-Module posh-git -ErrorAction SilentlyContinue
    # --- Fzf Pickers ---
    function global:Select-GitBranch {
        [CmdletBinding()]
        param()
        $branch = git branch --all --color=always |
            fzf --ansi --preview 'git log --oneline --color=always {1}' `
                --preview-window 'right:55%' `
                --header 'Select branch (Enter to checkout)'
        if ($branch) {
            $branch = $branch.Trim() -replace '^\* ', '' -replace '^remotes/origin/', ''
            git checkout $branch
        }
    }
    Set-Alias -Name fco -Value Select-GitBranch -Scope Global

    function global:Select-GitLog {
        [CmdletBinding()]
        param()
        $commit = git log --oneline --color=always |
            fzf --ansi --preview 'git show --color=always {1}' `
                --preview-window 'right:55%' `
                --header 'Select commit (Enter to show, Ctrl-C to cancel)'
        if ($commit) {
            $sha = ($commit -split ' ')[0]
            git show $sha
        }
    }
    Set-Alias -Name flog -Value Select-GitLog -Scope Global

    function global:Select-GitFile {
        [CmdletBinding()]
        param()
        $files = git status --short |
            fzf --ansi --multi `
                --preview 'git diff --color=always {2}' `
                --preview-window 'right:55%' `
                --header 'Select files to stage (Tab=multi-select, Enter to git add)'
        if ($files) {
            $files | ForEach-Object {
                $file = ($_ -split '\s+', 2)[1]
                git add $file
            }
            git status --short
        }
    }
    Set-Alias -Name fga -Value Select-GitFile -Scope Global

    function global:Select-GitStash {
        [CmdletBinding()]
        param()
        $stash = git stash list |
            fzf --preview 'git stash show -p {1}' `
                --preview-window 'right:55%' `
                --header 'Select stash (Enter to apply, Del to drop)'
        if ($stash) {
            $stashRef = ($stash -split ':')[0]
            $action = Read-Host "Apply or drop? [a/d]"
            if ($action -eq 'd') { git stash drop $stashRef }
            else { git stash apply $stashRef }
        }
    }
    Set-Alias -Name fstash -Value Select-GitStash -Scope Global
}
#endregion posh-git

#region Terminal-Icons  -  file icons in terminal
if (_HasMod 'Terminal-Icons') {
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
}
#endregion Terminal-Icons

#region oh-my-posh  -  prompt theme
if (_HasCmd 'oh-my-posh') {
    $Env:POSH_GIT_ENABLED = $true
    if (-not $isVSCodeTerm) {
        # Skip in VS Code integrated terminal — uses plain PS prompt there
        $ompConfig = Join-Path $home '.config' 'oh-my-posh' 'catpow.omp.yaml'
        oh-my-posh init pwsh --config $ompConfig | Invoke-Expression
    }
    # --- Fzf Pickers ---
    function global:Select-PoshTheme {
        [CmdletBinding()]
        param()
        $themesPath = $Env:POSH_THEMES_PATH
        if (-not $themesPath -or -not (Test-Path $themesPath)) { return }
        $theme = Get-ChildItem $themesPath -Filter '*.omp.json' |
            Select-Object -ExpandProperty Name |
            fzf --preview "oh-my-posh print primary --config '$themesPath\{}' --shell pwsh" `
                --preview-window 'bottom:3' `
                --header 'Select oh-my-posh theme (Enter to apply for this session)'
        if ($theme) {
            oh-my-posh init pwsh --config "$themesPath\$theme" | Invoke-Expression
            Write-Host "Applied theme: $theme (add to cli_tools_config.ps1 to persist)" -ForegroundColor Cyan
        }
    }
    Set-Alias -Name fpot -Value Select-PoshTheme -Scope Global
}
#endregion oh-my-posh

#region PSFzf  -  fzf PS integration
if (_HasMod 'PSFzf') {
    # Guard checks loaded (not just installed) — Set-PsFzfOption requires PSFzf to be imported
    Set-PsFzfOption -EnableFd

    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' `
        -PSReadlineChordReverseHistory 'Ctrl+r'

    $commandOverride = [ScriptBlock] { param($Location) Set-Location $Location }
    Set-PsFzfOption -AltCCommand $commandOverride

    Set-PsFzfOption -EnableAliasFuzzyScoop
    Set-PsFzfOption -TabExpansion
    Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
}
#endregion PSFzf

#region scoop-completion  -  scoop tab completions
if (_HasMod 'scoop-completion') {
    # TODO: Import
    # TODO: Config
    # TODO: Completers / Fzf Pickers
}
#endregion scoop-completion

#region DockerCompletion  -  Docker tab completions
if (_HasMod 'DockerCompletion') {
    Import-Module DockerCompletion -ErrorAction SilentlyContinue
}
#endregion DockerCompletion

#region PowerType  -  AI tab completions
if (_HasMod 'PowerType') {
    Import-Module PowerType -ErrorAction SilentlyContinue
    Enable-PowerType
}
#endregion PowerType

#region PSAISuite  -  AI PS suite
if (_HasMod 'PSAISuite') {
    # TODO: Import
    # TODO: Config
    # TODO: Completers / Fzf Pickers
}
#endregion PSAISuite

#region PSWindowsUpdate  -  Windows Update
if (_HasMod 'PSWindowsUpdate') {
    # TODO: Import
    # TODO: Config
    # TODO: Completers / Fzf Pickers
}
#endregion PSWindowsUpdate

#region Admin  -  admin utilities
if (_HasMod 'Admin') {
    # TODO: Import
    # TODO: Config
    # TODO: Completers / Fzf Pickers
}
#endregion Admin

# ── Tool availability summary (emitted at Debug level) ───────────────────────
if ($script:_toolsFound.Count -gt 0 -or $script:_toolsMissing.Count -gt 0) {
    $found   = ($script:_toolsFound   | ForEach-Object { "✓ $_" }) -join '  '
    $missing = ($script:_toolsMissing | ForEach-Object { "· $_" }) -join '  '
    if ($found)   { Write-ProfileMsg "  $found"   -Level Debug -Color Green }
    if ($missing) { Write-ProfileMsg "  $missing" -Level Debug -Color DarkYellow }
}
