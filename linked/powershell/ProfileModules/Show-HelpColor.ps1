#Requires -Version 7.0

Set-StrictMode -Version 'Latest'
Write-Host 'Loading functions...'

function global:Show-HelpColor {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string] $Name,

    [string] $Pager = $env:PAGER
  )

  Write-Host $Pager

  if (-not $Pager) {
    Write-Warning "PAGER not set; defaulting to 'more'."
    $Pager = 'more'
  }

  # Build colored lines using ANSI via $PSStyle (PS 7+)
  $help = Get-Help -Full $Name | Out-String

  $header = $PSStyle.Foreground.BrightCyan
  $param = $PSStyle.Foreground.BrightYellow
  $reset = $PSStyle.Reset

  $lines =
  $help -split "`r?`n" | ForEach-Object {
    if ($_ -match '^(NAME|SYNOPSIS|DESCRIPTION|SYNTAX|PARAMETERS|INPUTS|OUTPUTS|EXAMPLES|REMARKS|NOTES|RELATED_LINKS|LINKS)') {
      "$header$_$reset"
    } elseif ($_ -match '^\s+-\w+') {
      "$param$_$reset"
    } else {
      $_
    }
  }

  # Join into a single string for stdin
  $text = $lines -join [Environment]::NewLine

  # On Windows, use cmd.exe to get proper stdin piping into the pager
  $pagerExe, $pagerArgs = $Pager -split '\s+', 2
  if (-not $pagerArgs) { $pagerArgs = '' }

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'cmd.exe'
  $psi.Arguments = "/c `"$pagerExe $pagerArgs`""
  $psi.UseShellExecute = $false
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $false
  $psi.RedirectStandardError = $false

  $p = [System.Diagnostics.Process]::Start($psi)
  $sw = $p.StandardInput
  $sw.WriteLine($text)
  $sw.Close()
  $p.WaitForExit()
}

Set-Alias -Name shc -Value Show-HelpColor -Scope Global
