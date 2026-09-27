# Load prompt modules
Import-Module posh-git
Import-Module Terminal-Icons
(@(& oh-my-posh.exe init pwsh --config='~/.config/oh-my-posh/themes/oh-my-posh.json' --print) -join "`n") | Invoke-Expression
Import-Module ZLocation

# Set custom prompt settings
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -BellStyle None
Set-PSReadLineOption -PredictionSource History
#Set-PSReadLineOption -PredictionViewStyle ListView
#Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
#Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
Set-PSReadLineKeyHandler -Chord 'Ctrl+Shift+f' -ScriptBlock { Invoke-PsFzfRipgrep }
$commandOverride = [ScriptBlock]{ param($Location) Write-Host $Location }
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' -EnableFd -AltCCommand $commandOverride

# Aliases
Set-Alias vim nvim
Set-Alias ll ls
Set-Alias g git
Set-Alias grep findstr
Set-Alias tig 'C:\Program Files\Git\usr\bin\tig.exe'
Set-Alias less 'C:\Program Files\Git\usr\bin\less.exe'

# Aliases to call fuzzy methods from PSFzf
New-Alias -Scope Global -Name fcd -Value Invoke-FuzzySetLocationWithFd -ErrorAction Ignore
New-Alias -Scope Global -Name fe -Value Invoke-FuzzyEdit -ErrorAction Ignore
New-Alias -Scope Global -Name fh -Value Invoke-FuzzyHistory -ErrorAction Ignore
New-Alias -Scope Global -Name fkill -Value Invoke-FuzzyKillProcess -ErrorAction Ignore
New-Alias -Scope Global -Name fz -Value Invoke-FuzzyZLocation -ErrorAction Ignore

# Show tips about newly added commands
function Get-Tips {

  $tips = @(
    [pscustomobject]@{
      Command     = 'fcd'
      Description = 'navigate to subdirectory'

    },
    [pscustomobject]@{
      Command     = 'ALT+C'
      Description = 'navigate to deep subdirectory'

    },
    [pscustomobject]@{
      Command     = 'z'
      Description = 'ZLocation'

    },
    [pscustomobject]@{
      Command     = 'fz'
      Description = 'ZLocation through fzf'

    },
    [pscustomobject]@{
      Command     = 'fe'
      Description = 'fuzzy edit file'

    },
    [pscustomobject]@{
      Command     = 'fh'
      Description = 'fuzzy invoke command from history'

    },
    [pscustomobject]@{
      Command     = 'fkill'
      Description = 'fuzzy stop process'

    },
    [pscustomobject]@{
      Command     = 'frg'
      Description = 'ripgrep through fzf'

    }
  )

  Write-Output $tips | Format-Table
}

# Utilities
function Invoke-FuzzySetLocationWithFd() {
  param($Directory = $null)

  if ($null -eq $Directory) {
    $Directory = $PWD.Path
  }

  $result = $null

  try {

    # Color output from fd to fzf if running in Windows Terminal
    $script:RunningInWindowsTerminal = [bool]($env:WT_Session)
    if ($script:RunningInWindowsTerminal) {
      $script:DefaultFileSystemFdCmd = "fd.exe --color always . {0}"
    }
    else {
      $script:DefaultFileSystemFdCmd = "fd.exe . {0}"
    }

    # Wrap $Directory in quotes if there is space (to be passed in fd)
    if ($Directory.Contains(' ')) {
      $strDir = """$Directory"""
    }
    else {
      $strDir = $Directory
    }

    # Call fd to get directory list and pass to fzf
    Invoke-Expression (($script:DefaultFileSystemFdCmd -f '--type directory {0} --max-depth 1') -f $strDir) | Invoke-Fzf | ForEach-Object { $result = $_ }
  }
  catch {

  }

  if ($null -ne $result) {
    Set-Location $result
  }
}

function which ($command) {
  Get-Command -Name $command -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

function frg ($searchString) {
  Invoke-PsFzfRipgrep -SearchString $searchString
}