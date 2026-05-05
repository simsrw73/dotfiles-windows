# #Requires -Version 7.0

Set-StrictMode -Version 'Latest'
$ErrorActionPreference = 'Stop'

$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

$profileRoot = Split-Path -Parent $PROFILE
$moduleRoot = Join-Path $profileRoot 'ProfileModules'


. Join-Path $moduleRoot 'Env.ps1'
. Join-Path $moduleRoot 'Aliases.ps1'
. Join-Path $moduleRoot 'Functions.ps1'
. Join-Path $moduleRoot 'Completers.ps1'
. Join-Path $moduleRoot 'PSReadline.ps1'


. Join-Path $moduleRoot 'Show-HelpColor.ps1'
Write-Host 'After importing Show-HelpColor.ps1:' -ForegroundColor Green
# Get-Command Show-HelpColor -ErrorAction SilentlyContinue | Format-List Name, CommandType, Source

#
# Install required modules
#   gsudo
#
#

# Set execution policy first if needed
# Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Install essentials
# Install-Module -Name PSReadLine -Scope CurrentUser -Force -SkipPublisherCheck
# Install-Module -Name command-not-found -Scope CurrentUser -Force
# Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -Repository PSGallery
# Install-Module -Name posh-git -Scope CurrentUser -Force
# Install-Module -Name PwshSpectreConsole -Scope CurrentUser -Force
# Install-Module -Name ImportExcel -Scope CurrentUser -Force
# Install-Module -Name Microsoft.PowerShell.SecretManagement -Scope CurrentUser -Force
# Install-Module -Name Microsoft.PowerShell.SecretStore -Scope CurrentUser -Force
# Install-Module -Name Microsoft.PowerShell.PSResourceGet -Scope CurrentUser -Force
# Install-Module -Name PSWindowsUpdate -Scope CurrentUser -Force
# Install-Module -Name Microsoft.PowerShell.PSResourceGet -Scope CurrentUser  # Install by default PS 7.4+
# Microsoft.WinGet.CommandNotFound
# winget install JanDeDobbeleer.OhMyPosh -s winget


# Temp set default security protocol to 1.2 for compat
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# To use this profile, edit $profile (`code $profile`) to add the lines:
#   $profile_ps1 = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'pwsh' 'profile.ps1'
#   . $profile_ps1

# # while ($ps -and 0 -eq [int] $ps.MainWindowHandle) {
# #     $ps = Get-Process -ErrorAction Ignore -Id (Get-CimInstance Win32_Process -Filter "ProcessID = $($ps.Id)").ParentProcessId
# #     Write-Output $ps.Name
# }

$VerbosePreference = 'SilentlyContinue' # Normal: 'SilentlyContinue', Debugging:'Continue'

$PSInfo = Get-Process -Id $pid | Get-Item
Write-Output "Current shell: $PSInfo"

$env:EDITOR = 'code'

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
    # conhost??? other???
    Write-Host 'Terminal not detected'
}


$TermInfo = $Host.UI.RawUI
if ($termInfo.WindowSize.Height -le 20) {
    Write-Output 'Terminal size is small.'
} else {
    Write-Output 'Terminal size is normal.'
}

function isAdminUser {
    $wi = [Security.Principal.WindowsIdentity]::GetCurrent()
    $wp = New-Object Security.Principal.WindowsPrincipal($wi)
    if ( $wp.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) ) {
        return $true
    } else {
        return $false
    }
}

$isAdmin = isAdminUser
if ($isAdmin) {
    Write-Output 'Running as Administrator'
}


# Builtins: $isWindows, $isLinux, $isMacOS


function Update-AllModules {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Set-PSResourceRepository -Name PSGallery -Trusted -ErrorAction SilentlyContinue

    $installed = Get-InstalledPSResource | Sort-Object Name

    # --- Phase 1: Prune stale entries ---
    Write-Host "`n=== Phase 1: Pruning stale module entries ===" -ForegroundColor Yellow

    $stale = $installed | Where-Object { -not (Test-Path $_.InstalledLocation) }

    if (-not $stale) {
        Write-Host 'No stale entries found.' -ForegroundColor Green
    } else {
        foreach ($module in $stale) {
            Write-Host "  Stale: $($module.Name) v$($module.Version) -> $($module.InstalledLocation)" -ForegroundColor Red
            if ($PSCmdlet.ShouldProcess("$($module.Name) v$($module.Version)", 'Uninstall stale entry')) {
                Uninstall-PSResource -Name $module.Name -Version $module.Version -ErrorAction SilentlyContinue
            }
        }
    }

    # --- Phase 2: Update installed modules ---
    Write-Host "`n=== Phase 2: Updating installed modules ===" -ForegroundColor Yellow

    $valid = $installed | Where-Object { Test-Path $_.InstalledLocation }
    $unique = $valid | Sort-Object Name -Unique
    $total = @($unique).Count
    $i = 0

    foreach ($module in $unique) {
        $i++
        $scope = if ($module.InstalledLocation -like "*$env:USERPROFILE*") {
            'CurrentUser'
        } else {
            'AllUsers'
        }

        # Skip AllUsers if not elevated
        if ($scope -eq 'AllUsers') {

            if (-not $isAdmin) {
                Write-Host "  [$i/$total] SKIP (needs admin): $($module.Name) [$scope]" -ForegroundColor DarkYellow
                continue
            }
        }

        Write-Host "  [$i/$total] $($module.Name) [$scope]..." -NoNewline

        Update-PSResource -Name $module.Name -Scope $scope -ErrorAction SilentlyContinue

        # --- Clean up old versions for this module ---
        $allVersions = @(Get-InstalledPSResource -Name $module.Name |
                Where-Object { Test-Path $_.InstalledLocation } |
                Sort-Object Version -Descending)

        if ($allVersions.Count -gt 1) {
            # keep index 0 (latest), uninstall the rest
            $allVersions[1..($allVersions.Count - 1)] | ForEach-Object {
                Uninstall-PSResource -Name $_.Name -Version $_.Version -ErrorAction SilentlyContinue
            }
        }

        Write-Host ' Done.' -ForegroundColor Green
    }

    # --- Phase 3: Update help files ---
    Write-Host "`n=== Phase 3: Updating help files ===" -ForegroundColor Yellow

    try {
        if ($PSCmdlet.ShouldProcess('PowerShell help content', 'Update help files')) {
            Update-Help -Force -ErrorAction Continue
        }
        Write-Host 'Help update complete.' -ForegroundColor Green
    } catch {
        Write-Host "Help update encountered errors: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }

    Write-Host "`nAll done." -ForegroundColor Cyan
}

# Optional: auto-run once a week (e.g., every Friday)
if ((Get-Date).DayOfWeek -eq 'Friday') {
    Write-Host 'Running weekly module update...' -ForegroundColor Cyan
    Update-AllModules
}

# Enable experimental features
$experimentalFeatures = Get-ExperimentalFeature;
if ($experimentalFeatures.Name -contains 'PSFeedbackProvider') {
    Write-Host 'Enabling experimental feature: PSFeedbackProvider'
    Enable-ExperimentalFeature PSFeedbackProvider
}

Import-Module -Name posh-git
Import-Module -Name Terminal-Icons
Import-Module -Name PSReadLine
Import-Module -Name DockerCompletion
Import-Module -Name scoop-completion
Import-Module -Name PSFzf
Import-Module -Name powershell-yaml
Import-Module -Name gsudoModule
Import-Module -Name Microsoft.WinGet.CommandNotFound
Import-Module Microsoft.PowerShell.SecretManagement

# Set some default parameter values for PowerShell commands
$PSDefaultParameterValues = @{
    'Install-Module:Scope'      = 'CurrentUser'
    'Install-Module:Repository' = 'PSGallery'
    'Format-Table:AutoSize'     = $true
    'Get-Help:ShowWindow'       = $true
}

# $ENV:PerplexityKey = Get-Secret -Name PerplexityKey -AsPlainText

$Env:XDG_CONFIG_HOME = Join-Path -Path $home -ChildPath '.config'
$Env:XDG_DATA_HOME = Join-Path -Path $home -ChildPath '.local' 'share'
$Env:XDG_STATE_HOME = Join-Path -Path $home -ChildPath '.local' 'state'
$Env:XDG_CACHE_HOME = Join-Path -Path $home -ChildPath '.cache'

$scripts_dir = Join-Path -Path $home -ChildPath 'scripts'
$Env:Path += [IO.Path]::PathSeparator + $scripts_dir

# $Env:Path += 'C:\devel\winlibs\mingw-w64ucrt\bin'

# Setup Rust/Cargo environent
$Env:RUSTUP_HOME = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'rustup'
$Env:CARGO_HOME = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'cargo'
$cargo_bin = Join-Path -Path $Env:CARGO_HOME -ChildPath 'bin'
$Env:Path += [IO.Path]::PathSeparator + $cargo_bin
if (Get-Command rustup.exe -ErrorAction SilentlyContinue) {
    rustup completions powershell | Out-String | Invoke-Expression
}

# Setup Python environment
# Get the Python scripts directory dynamically
$pythonScriptsPath = python -c "import sysconfig; print(sysconfig.get_path('scripts'))" 2>$null

# Add it to the session Path if it's found and not already present
if ($pythonScriptsPath -and ($env:Path -split ';' -notcontains $pythonScriptsPath)) {
    $env:Path = "$pythonScriptsPath;$env:Path"
}

# TODO: ...
$Env:PYTHONPYCACHEPREFIX = Join-Path -Path $Env:XDG_CACHE_HOME -ChildPath 'python'
$Env:PYTHONUSERBASE = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'python'
$python_bin = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'python' 'Python311' 'Scripts'
$Env:Path += [IO.Path]::PathSeparator + $python_bin


# ...
$Env:Path += [IO.Path]::PathSeparator + 'C:\Users\simsrw\AppData\Local\Programs\Pulsar'

$Env:GNUPGHOME = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'gnupg'

# TODO: More paths  (https://wiki.archlinux.org/title/XDG_Base_Directory)
# GNUPGHOME=$XDG_CONFIG_HOME/gnupg ???    Is this working --- Untested
# DOCKER_CONFIG=$XDG_CONFIG_HOME/docker
# NPM_CONFIG_USERCONFIG=$XDG_CONFIG_HOME/npm/npmrc
# NVM_DIR=$XDG_DATA_HOME/nvm
# NODE_REPL_HISTORY=$XDG_DATA_HOME/node_repl_history
# GOPATH=$XDG_DATA_HOME/go
# LUAROCKS_CONFIG =cd
# GEM_HOME
# GEM_PATH

# Javascript / Typescript
function nls {
    npm list -g --depth=0
}


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

# Scoop config

. ([ScriptBlock]::Create((& scoop-search --hook | Out-String)))

# if (Get-Command scoop-search.exe -ErrorAction SilentlyContinue) {
#     Invoke-Expression (&scoop-search --hook)
# }

# Invoke-Expression (&sfsu hook)


# function admin {
#     if ($args.Count -gt 0) {
#         $argList = "& '" + $args + "'"
#         Start-Process "$psHome\powershell.exe" -Verb runAs -ArgumentList $argList
#     } else {
#         Start-Process "$psHome\powershell.exe" -Verb runAs
#     }
# }

# Set-Alias -Name psudo -Value admin

# function Elevate-Process {
#     $file, [string]$arguments = $args
#     $psi = New-Object System.Diagnostics.ProcessStartInfo $file
#     $psi.Arguments = $arguments
#     $psi.Verb = 'runas'

#     $psi.WorkingDirectory = Get-Location
#     [System.Diagnostics.Process]::Start($psi)
# }
# Set-Alias sudo Elevate-Process


# Configure scoop and install core utils

# Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Confirm
# Invoke-RestMethod get.scoop.sh | Invoke-Expression

# $Buckets = Get-Content .\scoop-buckets.json | ConvertFrom-Json
# $Packages = Get-Content .\scoop-packages.json | ConvertFrom-Json

# ForEach ($Bucket in $Buckets)
# {
#     scoop bucket add $Bucket.Name $Bucket.Url
# }


# ForEach ($Package in $Packages)
# {
#     scoop install $Package
# }

function sstat { scoop update && scoop status }
function supd { scoop update * && scoop cleanup * }

# Winget config

function wstat { winget upgrade }
function wupd { winget upgrade --all }

# Setup theme
$Env:POSH_GIT_ENABLED = $true

# oh-my-posh init pwsh --config "$Env:POSH_THEMES_PATH\powerlevel10k_classic.omp.json" | Invoke-Expression
# oh-my-posh init pwsh --config "$Env:POSH_THEMES_PATH\catppuccin.omp.json" | Invoke-Expression
oh-my-posh init pwsh --config "$home\.config\oh-my-posh\catpow.omp.yaml" | Invoke-Expression

#Enable-PowerType

# TODO: Save history, etc. to $XDG

# ReadLine Options
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -Colors @{ InlinePrediction = '#ffdd99' }
# Set-PSReadLineKeyHandler -Key Tab -Function Complete
Remove-PSReadLineKeyHandler 'Ctrl+r'
Remove-PSReadLineKeyHandler 'Ctrl+t'

Set-PSReadLineKeyHandler -Chord Ctrl+p -Function PreviousHistory
Set-PSReadLineKeyHandler -Chord Ctrl+n -Function NextHistory

$catppuccinMochaTheme = @{
    Rosewater = '#f5e0dc';
    Flamingo  = '#f2cdcd';
    Pink      = '#f5c2e7';
    Mauve     = '#cba6f7';
    Red       = '#f38ba8';
    Maroon    = '#eba0ac';
    Peach     = '#fab387';
    Yellow    = '#f9e2af';
    Green     = '#a6e3a1';
    Teal      = '#94e2d5';
    Sky       = '#89dceb';
    Sapphire  = '#74c7ec';
    Blue      = '#89b4fa'; ;
    Lavender  = '#b4befe';
    Text      = '#cdd6f4';
    Subtext1  = '#bac2de';
    Subtext0  = '#a6adc8';
    Overlay2  = '#9399b2';
    Overlay1  = '#7f849c';
    Overlay0  = '#6c7086';
    Surface2  = '#585b70';
    Surface1  = '#45475a';
    Surface0  = '#313244';
    Base      = '#1e1e2e';
    Mantle    = '#181825';
    Crust     = '#11111b';
}

$catppuccin = $catppuccinMochaTheme

$catppuccinSyntaxTheme2 = @{
    Command            = $catppuccin.Green;
    Comment            = $catppuccin.Surface2;
    ContinuationPrompt = $catppuccin.Text;
    Default            = $catppuccin.Text;
    Emphasis           = $catppuccin.Yellow;
    Error              = $catppuccin.Red;
    # InlinePrediction = '';
    Keyword            = $catppuccin.Green;
    # ListPrediction = '';
    # ListPredictionSelected = '';
    Member             = $catppuccin.Blue;
    Number             = $catppuccin.Peach;
    Operator           = $catppuccin.Sky;
    Parameter          = $catppuccin.Pink;
    # Selection          = $catppuccin.Yellow;
    String             = $catppuccin.Lavender;
    Type               = $catppuccin.Blue;
    Variable           = $catppuccin.Flamingo
}

$catppuccinSyntaxTheme3 = @{
    Command            = $catppuccin.Blue;
    Comment            = $catppuccin.Blue;
    ContinuationPrompt = $catppuccin.Yellow;
    Default            = $catppuccin.Text;
    Emphasis           = $catppuccin.Yellow;
    Error              = $catppuccin.Red;
    # InlinePrediction = '';
    Keyword            = $catppuccin.Red;
    # ListPrediction = '';
    # ListPredictionSelected = '';
    Member             = $catppuccin.Lavender;
    Number             = $catppuccin.Peach;
    Operator           = $catppuccin.Sky;
    Parameter          = $catppuccin.Pink;
    Selection          = $catppuccin.Surface2;
    String             = $catppuccin.Green;
    Type               = $catppuccin.Peach;
    Variable           = $catppuccin.Flamingo
}

$catppuccinSyntaxTheme = @{
    Command            = $catppuccin.Blue;
    Comment            = $catppuccin.Overlay0;
    ContinuationPrompt = $catppuccin.Yellow;
    Default            = $catppuccin.Peach;
    Emphasis           = $catppuccin.Yellow;
    Error              = $catppuccin.Red;
    # InlinePrediction = '';
    Keyword            = $catppuccin.Sky;
    # ListPrediction = '';
    # ListPredictionSelected = '';
    Member             = $catppuccin.Flamingo;
    Number             = $catppuccin.Peach;
    Operator           = $catppuccin.Sky;
    Parameter          = $catppuccin.Lavender;
    Selection          = $catppuccin.Surface2;
    String             = $catppuccin.Green;
    Type               = $catppuccin.Red;
    Variable           = $catppuccin.Text
}

# Set-PSReadLineTheme
Set-PSReadLineOption -Colors $catppuccinSyntaxTheme

function Test-Syntax {
    # Demo Syntax Highlighting
    [CmdletBinding()]
    param([IO.FileInfo]$Path)
    end {
        Write-Verbose "Testing in $(Split-Path $PSScriptRoot -Leaf)" -Verbose
        $Env:PSModulePath -split ';' -notcontains $Path.FullName
    }
}

function cd... { Set-Location ..\.. }
function cd.... { Set-Location ..\..\.. }

# TODO: don't reference tools like exa, eza, bat, moor directly in profile; instead,
# have a separate script that configures them and is imported by the profile.
# This way if the tools aren't installed, the profile won't fail to load.


# Configure fzf
$Env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git'
$Env:FZF_ALT_C_COMMAND = 'fd -H -L -E .git -t d'
$Env:FZF_ALT_C_OPTS = '--preview "eza -a --icons --group-directories-first --color=always {}"'
# Catppuccin theme
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

# TODO: Use default pager and ls
$Env:FZF_CTRL_T_OPTS = '--preview "bat --color=always --line-range=:500 {}"'
$Env:FZF_CTRL_T_COMMAND = 'fd -H -L -E .git -t f'

Set-PsFzfOption -EnableFd

# replace 'Ctrl+t' and 'Ctrl+r' with your preferred bindings:
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' `
    -PSReadlineChordReverseHistory 'Ctrl+r'

$commandOverride = [ScriptBlock] { param($Location) Set-Location $Location }
Set-PsFzfOption -AltCCommand $commandOverride

Set-PsFzfOption -EnableAliasFuzzyScoop

Set-PsFzfOption -TabExpansion
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }


# Configure zoxide
$Env:_ZO_DATA_DIR = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'zoxide'
Invoke-Expression (& {
        $hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
        (zoxide init --hook $hook powershell | Out-String)
    })

# Aliases

Remove-Alias -Name r -Force -ErrorAction SilentlyContinue

Set-Alias -Name cz -Value chezmoi

if (Get-Command z -ErrorAction SilentlyContinue) {
    Set-Alias -Name cd -Value z -Option AllScope
}

function Show-Environment {
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

function Get-PubIP {
    (Invoke-WebRequest http://ifconfig.me/ip ).Content
}

function Invoke-MQTT {
    $mqtt_config_file = Join-Path -Path $home -ChildPath '.mosquitto' 'config'
    mosquitto -v -c $mqtt_config_file
}
Set-Alias -Name mqtt -Value Invoke-MQTT

# Configure bat
if (Get-Command bat.exe -ErrorAction SilentlyContinue) {
    $Env:BAT_CONFIG_PATH = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'bat' 'bat.conf'
}

function Join-Files {
    if (Get-Command bat.exe -ErrorAction SilentlyContinue) {
        $bat = (Get-Command bat.exe).Path.ToString()
        & $bat -pp $args
    } else {
        Get-Content $args
    }
}

Set-Alias -Name cat -Value 'Join-Files' -Force

# TODO: Think about changing to lsd--exa hasn't been updated in a long time and still doesn't have official Windows support
if (Get-Command eza.exe -ErrorAction SilentlyContinue) {
    $eza = (Get-Command eza.exe).Path.ToString()
    function _ls { & $eza --color=auto --icons --group-directories-first @args }
    Set-Alias -Name ls -Value _ls
    function _ll { & $eza --all --long --header @args }
    Set-Alias -Name ll -Value _ll
    function _la { & $eza --all --group @args }
    Set-Alias -Name la -Value _la
    function _tree { & $eza --tree @args }
    Set-Alias -Name tree -Value _tree
}

function Start-GlazeWM {
    if (Get-Command glazewm.exe -ErrorAction SilentlyContinue) {
        $wm = (Get-Command glazewm.exe).Path.ToString()
        $glaze_config = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'glazewm' 'config.yaml'
        & $wm --config=$glaze_config $args
    } else {
    }
}
Set-Alias -Name 'glazewm' -Value Start-GlazeWM

$Env:KOMOREBI_CONFIG_HOME = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'komorebi'

#     # Connect to your server and run the PowerShell using the $remotePowerShell variable
#     ssh username@domain1@contoso.com $remotePowershell
function Copy-SSHID($dest) {
    try {
        Get-Content $Env:USERPROFILE\.ssh\id_rsa.pub | ssh $dest 'mkdir ~/.ssh; cat >> ~/.ssh/authorized_keys'
    } catch {
        Write-Warning "Error copying key to $dest"
        Write-Host $_
    }
}
Set-Alias -Name ssh-copy-id -Value Copy-SSHID

if (Test-Path -Path 'C:\Program Files\Notepad++\notepad++.exe' -PathType Leaf) {
    Set-Alias -Name 'edit' -Value 'C:\Program Files\Notepad++\notepad++.exe'
} else {
    Set-Alias -Name 'edit' -Value 'C:\Windows\system32\notepad.exe'
}


# Keybinds Set-PSReadLineKeyHandler -Chord Ctrl+o -ScriptBlock { [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine() [Microsoft.PowerShell.PSConsoleReadLine]::Insert('lfcd.ps1') [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine() }
# One-Time Configs
# sudo Add-MpPreference -ExclusionPath 'C:\Users\simsr\scoop'
# sudo Add-MpPreference -ExclusionPath 'C:\ProgramData\scoop'


# Set sshd to use powershell as default shell for ssh connections
# New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value '"' + $((Get-Command -name pwsh).Path) + '"' -PropertyType String -Force

# Working version of above
# gsudo New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value '"C:\Program Files\PowerShell\7\pwsh.exe"' -PropertyType String -Force

#   --- or ---
# $pwshexe = (Get-Command -name pwsh).Path
# gsudo New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "'$pwshexe'" -PropertyType String -Force

Write-Host 'Setting up MS Dev Environment... ' -ForegroundColor Green -NoNewline
$vsWhere = "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsInstallationPath = & $vsWhere -products * -latest -property installationPath
# & "${vsInstallationPath}\Common7\Tools\Launch-VsDevShell.ps1" -List
& "${vsInstallationPath}\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64 -SkipAutomaticLocation | Out-Null
Write-Host 'Done.' -ForegroundColor Green



# --- Transcript configuration ---
if ($Host.Name -eq 'ConsoleHost') {
    $myDocuments = $([Environment]::GetFolderPath('MyDocuments'))
    $TranscriptRoot = Join-Path $myDocuments 'PowerShell.Transcripts'
    $RetentionDays = 7

    # Ensure base folder exists
    if (-not (Test-Path $TranscriptRoot)) {
        New-Item -Path $TranscriptRoot -ItemType Directory -Force | Out-Null
    }

    # Per-day subfolder (YYYY-MM-DD)
    $todayFolderName = Get-Date -Format 'yyyy-MM-dd'
    $todayFolder = Join-Path $TranscriptRoot $todayFolderName

    if (-not (Test-Path $todayFolder)) {
        New-Item -Path $todayFolder -ItemType Directory -Force | Out-Null
    }

    # Per-session transcript file name: user_host_psver_timestamp.txt
    $tsStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $user = $env:USERNAME
    $hostName = $env:COMPUTERNAME
    $psver = $PSVersionTable.PSVersion.ToString()
    $tsName = "Transcript_${user}_${hostName}_PS${psver}_${tsStamp}.txt"
    $tsPath = Join-Path $todayFolder $tsName

    # Start transcript for this session (append not strictly needed with unique name)
    try {
        Start-Transcript -LiteralPath $tsPath -Append -IncludeInvocationHeader -ErrorAction Stop | Out-Null
    } catch {
        Write-Warning "Failed to start transcript: $($_.Exception.Message)"
    }

    # --- Retention: prune transcripts older than N days ---
    try {
        $cutoff = (Get-Date).AddDays(-$RetentionDays)

        # Delete files older than cutoff
        Get-ChildItem -Path $TranscriptRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff } |
            Remove-Item -Force -ErrorAction SilentlyContinue

        # Remove now-empty date folders
        Get-ChildItem -Path $TranscriptRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { -not (Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue) } |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Failed to prune old transcripts: $($_.Exception.Message)"
    }
}

### TODO: cleanup old installed version of apps and modules: scoop cleanup, uninstall old PS modules, etc.
