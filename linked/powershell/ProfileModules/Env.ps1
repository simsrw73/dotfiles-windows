#Requires -Version 7.0

# Editor
$env:EDITOR = 'zed --wait'
$env:VISUAL = 'zed --wait'
$env:GIT_EDITOR = 'micro'

# Make sure to always run gsudo
#   FIXME: We should juggle the paths ourselves.
# gsudo config PathPrecedence true

#  This function is case sensitive, somehow.
Add-DotenvPattern -Pattern "${Env:USERPROFILE}\projects\**\.env"
echo "${Env:USERPROFILE}\projects\**\.env"
# Themes
$env:GLAMOUR_STYLE = Join-Path -Path $Env:XDG_CONFIG_HOME 'glamour' 'themes' 'catppuccin-mocha.json'

# if (Get-Command vivid.exe -ErrorAction Ignore) {
#     $env:LS_COLORS = (vivid generate catppuccin-mocha)
# }

# Terminal detection — set $isVSCodeTerm; fill TERM_PROGRAM for terminals that don't set it
$isVSCodeTerm = $Env:TERM_PROGRAM -eq 'vscode'
if (-not $Env:TERM_PROGRAM) {
    if ($Env:ALACRITTY_LOG) {
        $Env:TERM_PROGRAM = 'Alacritty'
    } elseif ($Env:LC_EXTRATERM_COOKIE) {
        $Env:TERM_PROGRAM = 'ExtraTerm'
    } elseif ($env:WT_SESSION) {
        $Env:TERM_PROGRAM = 'wt'
    }
}

# Personal paths that are not managed by a DotForge tool record.
Add-DFToPath (Join-Path -Path $home -ChildPath 'scripts')

# GPG
$env:GNUPGHOME = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'gnupg'

# yazi
$env:YAZI_CONFIG_HOME = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'yazi'
function y {
    $tmp = (New-TemporaryFile).FullName
    yazi.exe @args --cwd-file="$tmp"
    $cwd = Get-Content -Path $tmp -Encoding UTF8
    if ($cwd -and $cwd -ne $PWD.Path -and (Test-Path -LiteralPath $cwd -PathType Container)) {
        Set-Location -LiteralPath (Resolve-Path -LiteralPath $cwd).Path
    }
    Remove-Item -Path $tmp
}

#   - yazi requires the file command, and the best version we have is the one that comes with Git for Windows.
function Get-GitUsrBinPath {
    $cmd = Get-Command git.exe -ErrorAction SilentlyContinue
    if (-not $cmd) {
        return $null
    }

    # Git for Windows: <root>\cmd\git.exe. Scoop's git.exe is a shim, so look in the app dir.
    $candidates = @(
        Join-Path (Split-Path (Split-Path $cmd.Source -Parent) -Parent) 'usr\bin'
        if ($Env:SCOOP) { Join-Path $Env:SCOOP 'apps\git\current\usr\bin' }
    )
    foreach ($usrBin in $candidates) {
        if (Test-Path $usrBin) {
            return $usrBin
        }
    }

    return $null
}

if (-not (Get-Command 'file' -ErrorAction Ignore)) {
    $gitUsrBin = Get-GitUsrBinPath
    if ($gitUsrBin) {
        $gitFile = Join-Path $gitUsrBin 'file.exe'
        if (Test-Path $gitFile) {
            $env:YAZI_FILE_ONE = $gitFile
        } else {
            Write-Warning "file.exe not found in Git usr/bin directory. yazi may not work correctly."
        }
        # $destFileShim = Join-Path $Env:XDG_BIN_HOME 'file.cmd'
        # if (-not (Test-Path $destFileShim)) {
        #     New-DFShim $gitFile
        # }
    } else {
        Write-Warning "file.exe not found in PATH or in Git usr/bin directory. yazi may not work correctly."
    }
}

# PNPM
#    ~\.local\share\pnpm
$Env:PNPM_HOME = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'pnpm'
Add-DFToPath (Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'pnpm')

# Python
$Env:PYTHONUTF8 = 1

# Pipx
$Env:PIPX_HOME = Join-`Path -Path $Env:XDG_DATA_HOME -ChildPath 'pipx'

# Bun
$Env:BUN_INSTALL = Join-Path -Path $Env:XDG_DATA_HOME -ChildPath 'bun'
Add-DFToPath $Env:BUN_INSTALL

# Claude
$Env:CLAUDE_CODE_USE_POWERSHELL_TOOL = 1
$Env:CLAUDE_CONFIG_DIR = Join-Path -Path $Env:XDG_CONFIG_HOME -ChildPath 'claude'

# Other tool paths
Add-DFToPath (Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Programs', 'Pulsar')

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
$Env:KOMOREBI_AHK_EXE = "$Env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
