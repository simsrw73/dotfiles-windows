#Requires -Version 7.0
# cli_tools_config.ps1  -  Per-tool configuration: XDG paths, functions, aliases, completers, fzf pickers
# Each tool gets one #region/#endregion block. Guards check tool availability before applying config.

$ErrorActionPreference = 'Stop'

# ==============================================================================
# Group 1  -  File/directory tools
# ==============================================================================

#region eza  -  modern ls replacement
if (Get-Command eza.exe -ErrorAction SilentlyContinue) {
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
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion eza

#region bat  -  modern cat replacement
# Join-Files works with or without bat (falls back to Get-Content)
function global:Join-Files {
    if (Get-Command bat.exe -ErrorAction SilentlyContinue) {
        $bat = (Get-Command bat.exe).Path.ToString()
        & $bat -pp $args
    } else {
        Get-Content $args
    }
}
Set-Alias -Name cat -Value Join-Files -Scope Global -Force

if (Get-Command bat.exe -ErrorAction SilentlyContinue) {
    # --- XDG / Config paths ---
    $Env:BAT_CONFIG_PATH = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'bat' 'bat.conf'
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion bat

#region fd  -  modern find replacement
if (Get-Command fd.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion fd

#region ripgrep  -  fast grep
if (Get-Command rg.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion ripgrep

#region broot  -  interactive file browser
if (Get-Command broot.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion broot

#region lsd  -  another ls alternative
# NOTE: lsd conflicts with eza; enable only if eza is removed
if (Get-Command lsd.exe -ErrorAction SilentlyContinue) {
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
if (Get-Command jq.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion jq

#region fx  -  interactive JSON viewer
if (Get-Command fx.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion fx

#region jid  -  interactive JSON editor
if (Get-Command jid.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion jid

#region glow  -  markdown reader
if (Get-Command glow.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion glow

# ==============================================================================
# Group 3  -  System tools
# ==============================================================================

#region procs  -  modern ps replacement
if (Get-Command procs.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion procs

#region duf  -  modern df replacement
if (Get-Command duf.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion duf

#region dua  -  disk usage analyzer
if (Get-Command dua.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion dua

#region gdu  -  disk usage TUI
if (Get-Command gdu.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion gdu

#region ntop  -  TUI process monitor
if (Get-Command ntop.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion ntop

#region winfetch  -  system info
if (Get-Command winfetch -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion winfetch

# ==============================================================================
# Group 4  -  Network/download tools
# ==============================================================================

#region curl  -  HTTP client
if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion curl

#region wget  -  downloader
if (Get-Command wget.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion wget

# ==============================================================================
# Group 5  -  Editors
# ==============================================================================

#region nano  -  text editor
if (Get-Command nano.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion nano

#region micro  -  modern terminal editor
if (Get-Command micro.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
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
if (Get-Command fzf.exe -ErrorAction SilentlyContinue) {
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
if (Get-Command zoxide.exe -ErrorAction SilentlyContinue) {
    # --- XDG / Config paths ---
    $Env:_ZO_DATA_DIR = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'zoxide'

    # --- Init ---
    Invoke-Expression (& {
            $hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
            (zoxide init --hook $hook powershell | Out-String)
        })

    # --- Aliases ---
    if (Get-Command z -ErrorAction SilentlyContinue) {
        Set-Alias -Name cd -Value z -Scope Global -Option AllScope
    }
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion zoxide

# ==============================================================================
# Group 8  -  Pagers
# ==============================================================================

#region moor  -  modern pager
if (Get-Command moor.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion moor

#region less  -  pager
if (Get-Command less.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion less

# ==============================================================================
# Group 9  -  Package managers
# ==============================================================================

#region scoop  -  Windows package manager
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    # --- scoop-search hook ---
    if (Get-Command scoop-search -ErrorAction SilentlyContinue) {
        . ([ScriptBlock]::Create((& scoop-search --hook | Out-String)))
    }
    # --- Functions ---
    function global:sstat { scoop update; scoop status }
    function global:supd { scoop update *; scoop cleanup * }
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion scoop

#region sfsu  -  fast scoop CLI
if (Get-Command sfsu.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion sfsu

#region winget  -  Windows package manager
if (Get-Command winget -ErrorAction SilentlyContinue) {
    # --- Functions ---
    function global:wstat { winget upgrade }
    function global:wupd { winget upgrade --all }
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion winget

# ==============================================================================
# Group 10  -  Dev tools
# ==============================================================================

#region cargo  -  Rust package manager
if (Get-Command cargo.exe -ErrorAction SilentlyContinue) {
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion cargo

#region rustup  -  Rust toolchain manager
if (Get-Command rustup.exe -ErrorAction SilentlyContinue) {
    # --- Completers ---
    rustup completions powershell | Out-String | Invoke-Expression
    # TODO: Fzf Pickers
}
#endregion rustup

#region nvm  -  Node version manager
if (Get-Command nvm -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion nvm

#region npm  -  Node package manager
if (Get-Command npm -ErrorAction SilentlyContinue) {
    # --- Functions ---
    function global:nls { npm list -g --depth=0 }
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion npm

# ==============================================================================
# Group 11  -  Python tools
# ==============================================================================

#region uv  -  fast Python package manager
if (Get-Command uv.exe -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion uv

# ==============================================================================
# Group 12  -  Dotfiles/config management
# ==============================================================================

#region chezmoi  -  dotfile manager
if (Get-Command chezmoi.exe -ErrorAction SilentlyContinue) {
    # --- Aliases ---
    Set-Alias -Name cz -Value chezmoi -Scope Global
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion chezmoi

# ==============================================================================
# Group 13  -  Security/secrets
# ==============================================================================

#region bitwarden  -  secrets manager
if (Get-Command bw -ErrorAction SilentlyContinue) {
    # TODO: XDG / Config paths
    # TODO: Functions / Aliases
    # TODO: Completers
    # TODO: Fzf Pickers
}
#endregion bitwarden

# ==============================================================================
# Group 14  -  AI tools
# ==============================================================================

#region gemini  -  Gemini CLI
if (Get-Command gemini -ErrorAction SilentlyContinue) {
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
if (Get-Command win32yank.exe -ErrorAction SilentlyContinue) {
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
if (Get-Module -Name gsudoModule -ListAvailable) {
    Import-Module gsudoModule -ErrorAction SilentlyContinue
    # TODO: Completers / Fzf Pickers
}
#endregion gsudo

# ==============================================================================
# Group 17  -  Window management
# ==============================================================================

#region glazewm  -  tiling window manager
if (Get-Command glazewm.exe -ErrorAction SilentlyContinue) {
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
if (Get-Command mosquitto.exe -ErrorAction SilentlyContinue) {
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
if (Get-Module -Name posh-git -ListAvailable) {
    Import-Module posh-git -ErrorAction SilentlyContinue
    # TODO: Completers / Fzf Pickers
}
#endregion posh-git

#region Terminal-Icons  -  file icons in terminal
if (Get-Module -Name Terminal-Icons -ListAvailable) {
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
}
#endregion Terminal-Icons

#region oh-my-posh  -  prompt theme
if (Get-Command oh-my-posh.exe -ErrorAction SilentlyContinue) {
    $Env:POSH_GIT_ENABLED = $true
    $ompConfig = Join-Path $home '.config' 'oh-my-posh' 'catpow.omp.yaml'
    oh-my-posh init pwsh --config $ompConfig | Invoke-Expression
    # TODO: Fzf Pickers (Select-PoshTheme)
}
#endregion oh-my-posh

#region PSFzf  -  fzf PS integration
if (Get-Module -Name PSFzf -ListAvailable) {
    # PSFzf is imported in profile.ps1; configure it here
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
if (Get-Module -Name scoop-completion -ListAvailable) {
    # TODO: Import
    # TODO: Config
    # TODO: Completers / Fzf Pickers
}
#endregion scoop-completion

#region DockerCompletion  -  Docker tab completions
if (Get-Module -Name DockerCompletion -ListAvailable) {
    # TODO: Import
    # TODO: Config
    # TODO: Completers / Fzf Pickers
}
#endregion DockerCompletion

#region PowerType  -  AI tab completions
if (Get-Module -Name PowerType -ListAvailable) {
    # TODO: Import
    # TODO: Config
    # TODO: Completers / Fzf Pickers
}
#endregion PowerType

#region PSAISuite  -  AI PS suite
if (Get-Module -Name PSAISuite -ListAvailable) {
    # TODO: Import
    # TODO: Config
    # TODO: Completers / Fzf Pickers
}
#endregion PSAISuite

#region PSWindowsUpdate  -  Windows Update
if (Get-Module -Name PSWindowsUpdate -ListAvailable) {
    # TODO: Import
    # TODO: Config
    # TODO: Completers / Fzf Pickers
}
#endregion PSWindowsUpdate

#region Admin  -  admin utilities
if (Get-Module -Name Admin -ListAvailable) {
    # TODO: Import
    # TODO: Config
    # TODO: Completers / Fzf Pickers
}
#endregion Admin
