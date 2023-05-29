

$pwshPath = (Get-Command -Name pwsh).Path
$pwshPath

$pwsh = Get-Command -Name pwsh
$Newitemsplay = @{
  Path         = 'HKLM:\SOFTWARE\OpenSSH'
  Name         = 'DefaultShell'
  Value        = $pwsh.path
  PropertyType = 'String'
  # Force        = $true
}


Start-Process -FilePath powershell.exe -ArgumentList {
  SFC /scannow
} -Verb RunAs


# gsudo New-ItemProperty @Newitemsplay -Force

# gsudo New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value $pwshPath -PropertyType String -Force




# https://github.com/ocalvo/PwrSudo/blob/master/PwrSudo.psm1
function global:Enable-SSH {
  param($shell = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe')

  Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
  Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
  Set-Service -Name sshd -StartupType 'Automatic'
  Set-Service -Name ssh-agent -StartupType 'Automatic'
  New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
  if (!(Test-Path 'HKLM:\SOFTWARE\OpenSSH')) {
    mkdir 'HKLM:\SOFTWARE\OpenSSH'
  }

  New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value $shell -PropertyType String -Force
  Get-Service ssh-agent | Restart-Service
  Get-Service sshd | Restart-Service
}


# TODO: add keyfile as a paramater with a default instead of hardcoding
# TODO: this works for linux. Add Windows support: (https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement#standard-user)
#     # Get the public key file generated previously on your client
#     $authorizedKey = Get-Content -Path $env:USERPROFILE\.ssh\id_ed25519.pub

#     # Generate the PowerShell to be run remote that will copy the public key file generated previously on your client to the authorized_keys file on your server
#     $remotePowershell_standard-user = "powershell New-Item -Force -ItemType Directory -Path $env:USERPROFILE\.ssh; Add-Content -Force -Path $env:USERPROFILE\.ssh\authorized_keys -Value '$authorizedKey'"
#                 --- OR ---
#     # Generate the PowerShell to be run remote that will copy the public key file generated previously on your client to the authorized_keys file on your server
#     $remotePowershell_admin-user = "powershell Add-Content -Force -Path $env:ProgramData\ssh\administrators_authorized_keys -Value '$authorizedKey';icacls.exe ""$env:ProgramData\ssh\administrators_authorized_keys"" /inheritance:r /grant ""Administrators:F"" /grant ""SYSTEM:F"""


# Get the public key file generated previously on your client
# $authorizedKey = Get-Content -Path $env:USERPROFILE\.ssh\id_ed25519.pub

# Generate the PowerShell to be run remote that will copy the public key file generated previously on your client to the authorized_keys file on your server
# $remotePowershell = "powershell Add-Content -Force -Path $env:ProgramData\ssh\administrators_authorized_keys -Value '$authorizedKey';icacls.exe ""$env:ProgramData\ssh\administrators_authorized_keys"" /inheritance:r /grant ""Administrators:F"" /grant ""SYSTEM:F"""

# Connect to your server and run the PowerShell using the $remotePowerShell variable
# ssh username@domain1@contoso.com $remotePowershell