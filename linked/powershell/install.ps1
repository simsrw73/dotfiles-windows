# Set execution policy
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Confirm
# Install latest PowerShell
winget install --id Microsoft.Powershell --source winget
# Install scoop package manager
Invoke-RestMethod get.scoop.sh | Invoke-Expression
# Add buckets
scoop bucket add extras

scoop install fzf fd ripgrep bat zoxide
# Install bat
scoop install bat
# Install ZLocation
scoop install zlocation
# Install PSFzf
scoop install psfzf
# Install Oh My Posh
scoop install oh-my-posh
# Install git-posh
scoop install posh-git
# Install terminal icons
scoop install terminal-icons
# Install PSReadLine module
Install-Module -Name PSReadLine -AllowPrerelease -Scope CurrentUser -Force -SkipPublisherCheck



# Define all required modules
$modules = 'AzureAD', 'ExchangeOnlineManagement', 'MSOnline'

# Find those that are already installed.
$installed = @((Get-Module $modules -ListAvailable).Name | Select-Object -Unique)

# Infer which ones *aren't* installed.
$notInstalled = Compare-Object $modules $installed -PassThru

if ($notInstalled) { # At least one module is missing.

  # Prompt for installing the missing ones.
  $promptText = @"
  The following modules aren't currently installed:

      $notInstalled

  Would you like to install them now?
"@
  $choice = $host.UI.PromptForChoice('Missing modules', $promptText, ('&Yes', '&No'), 0)

  if ($choice -ne 0) { Write-Warning 'Aborted.'; exit 1 }

  # Install the missing modules now.
  # Install-Module -Scope CurrentUser $notInstalled
}