# Import-Module oh-my-posh
Import-Module posh-git
Import-Module Terminal-Icons
Import-Module PSReadLine
Import-Module DockerCompletion
Import-Module scoop-completion
Import-Module PSFzf

$Env:XDG_CONFIG_HOME = Join-Path -Path $home -ChildPath '.config'
$Env:XDG_DATA_HOME = Join-Path -Path $home -ChildPath '.local' 'share'
$Env:XDG_STATE_HOME = Join-Path -Path $home -ChildPath '.local' 'state'
$Env:XDG_CACHE_HOME = Join-Path -Path $home -ChildPath '.cache'

$scripts_dir = Join-Path -Path $home -ChildPath 'scripts'
$Env:Path += [IO.Path]::PathSeparator + $scripts_dir

# Setup Rust/Cargo environent
# $Env:CARGO_HOME = Join-Path -Path $home -ChildPath '.cargo'
# $cargo_bin = Join-Path -Path $home -ChildPath 'bin'
# $Env:Path += [IO.Path]::PathSeparator + $cargo_bin
if (Get-Command rustup.exe -ErrorAction SilentlyContinue) {
    rustup completions powershell | Out-String | Invoke-Expression
}


if (Get-Command moar.exe -ErrorAction SilentlyContinue) {
    $Env:PAGER = 'moar'
    $Env:MOAR = '--style catppuccin-mocha'
} elseif (Get-Command bat.exe -ErrorAction SilentlyContinue) {
    $Env:PAGER = 'bat'
} elseif (Get-Command less.exe -ErrorAction SilentlyContinue) {
    $Env:PAGER = 'less -R'
} else {
    $Env:PAGER = 'more'
}

$Env:GNUPGHOME = Join-Path $Env:APPDATA 'gnupg'

# Scoop config
if (Get-Command scoop-search.exe -ErrorAction SilentlyContinue) {
    Invoke-Expression (&scoop-search --hook)
}

Function sstat { scoop update && scoop status }
Function supd { scoop update * && scoop cleanup * }

# Winget config

Function wstat { winget upgrade }
Function wupd { winget upgrade --all }

# Setup theme
$Env:POSH_GIT_ENABLED = $true

# oh-my-posh init pwsh --config "$Env:POSH_THEMES_PATH\powerlevel10k_classic.omp.json" | Invoke-Expression
# oh-my-posh init pwsh --config "$Env:POSH_THEMES_PATH\catppuccin.omp.json" | Invoke-Expression
oh-my-posh init pwsh --config "$home\.config\oh-my-posh\catpow.omp.json" | Invoke-Expression

#Enable-PowerType

# ReadLine Options
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -Colors @{ InlinePrediction = '#ffdd99' }
Set-PSReadLineKeyHandler -Key Tab -Function Complete
Remove-PSReadlineKeyHandler 'Ctrl+r'
Remove-PSReadlineKeyHandler 'Ctrl+t'

# Configure fzf
$Env:FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
$Env:FZF_ALT_C_COMMAND='fd -H -L -E .git -t d'
$Env:FZF_ALT_C_OPTS='--preview "exa -a --icons --group-directories-first --color=always {}"'
$Env:FZF_DEFAULT_OPTS=@"
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
--exact
--no-sort
--layout=reverse
--border
--cycle
--height 40%
"@

# TODO: Use default pager and ls
$Env:FZF_CTRL_T_OPTS='--preview "bat --color=always --line-range=:500 {}"'
$Env:FZF_CTRL_T_COMMAND='fd -H -L -E .git -t f'

Set-PsFzfOption -EnableFd

# replace 'Ctrl+t' and 'Ctrl+r' with your preferred bindings:
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' `
                -PSReadlineChordReverseHistory 'Ctrl+r'

$commandOverride = [ScriptBlock]{ param($Location) Set-Location $Location }
Set-PsFzfOption -AltCCommand $commandOverride

Set-PsFzfOption -EnableAliasFuzzyScoop

Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }

# Configure zoxide
Invoke-Expression (& {
    $hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
    (zoxide init --hook $hook powershell | Out-String)
})

# Aliases

# Useful shortcuts for traversing directories
function cd...  { Set-Location ..\.. }
function cd.... { Set-Location ..\..\.. }

Remove-Alias -Name r -Force -ErrorAction SilentlyContinue

Set-Alias -Name cz -Value chezmoi

if (Get-Command z -ErrorAction SilentlyContinue) {
    Set-Alias -Name cd -Value z -Option AllScope
}

Function Show-Environment {
    Get-ChildItem env:* | Sort-Object name | Format-Table -AutoSize
}
Set-Alias -Name printenv -Value Show-Environment

function Show-Path {
    Write-Output $Env:Path.Split(';')
}
Set-Alias -Name printpath -Value Show-Path

function New-File($filename) {
    Write-Output $null | Out-File $filename -Encoding utf8
}
Set-Alias -Name touch -Value New-File

function Remove-All {
    Remove-Item -Force -Recurse $args
}
Set-Alias -Name rmrf -Value Remove-All

Function Get-PubIP {
    (Invoke-WebRequest http://ifconfig.me/ip ).Content
}

Function Invoke-MQTT {
    $mqtt_config_file = Join-Path -Path $home -ChildPath '.mosquitto' 'config'
    mosquitto -v -c $mqtt_config_file
}
Set-Alias -Name mqtt -Value Invoke-MQTT

# Configure bat
if (Get-Command bat.exe -ErrorAction SilentlyContinue) {
    $Env:BAT_CONFIG_PATH = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'bat' 'bat.conf'
}

Function Join-Files {
    if (Get-Command bat.exe -ErrorAction SilentlyContinue) {
        $bat = (Get-Command bat.exe).Path.ToString()
        & $bat -pp $args
    } else {
        Get-Content $args
    }
}

Set-Alias -Name cat -Value "Join-Files" -Force

if (Get-Command exa.exe -ErrorAction SilentlyContinue) {
    $exa = (Get-Command exa.exe).Path.ToString()
    Function _ls { & $exa --color=auto --icons --group-directories-first @args }
    Set-Alias -Name ls -Value _ls
    Function _ll { & $exa --all --long --header @args }
    Set-Alias -Name ll -Value _ll
    Function _la { & $exa --all --group @args }
    Set-Alias -Name la -Value _la
    Function _tree { & $exa --tree @args }
    Set-Alias -Name tree -Value _tree
}

Function Start-GlazeWM {
    if (Get-Command glazewm.exe -ErrorAction SilentlyContinue) {
        $wm = (Get-Command glazewm.exe).Path.ToString()
        $glaze_config = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'glazewm' 'config.yaml'
        & $wm --config=$glaze_config $args
    } else {
    }
}
Set-Alias -Name 'glazewm' -Value Start-GlazeWM

$Env:KOMOREBI_CONFIG_HOME = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'komorebi'

# TODO: add keyfile as a paramater with a default instead of hardcoding
Function Copy-SSHID($dest) {
    try {
        Get-Content $Env:USERPROFILE\.ssh\id_rsa.pub | ssh $dest "mkdir ~/.ssh; cat >> ~/.ssh/authorized_keys"
    } catch {
        Write-Warning "Error copying key to $dest"
        Write-Host $_
    }
}
Set-Alias -Name ssh-copy-id -Value Copy-SSHID

if (Test-Path -Path "C:\Program Files\Notepad++\notepad++.exe" -PathType Leaf) {
    Set-Alias -Name "npp" -Value "C:\Program Files\Notepad++\notepad++.exe"
}


# Keybinds Set-PSReadLineKeyHandler -Chord Ctrl+o -ScriptBlock { [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine() [Microsoft.PowerShell.PSConsoleReadLine]::Insert('lfcd.ps1') [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine() }
# One-Time Configs
# sudo Add-MpPreference -ExclusionPath 'C:\Users\simsr\scoop'
# sudo Add-MpPreference -ExclusionPath 'C:\ProgramData\scoop'
