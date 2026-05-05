# Install modules
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser

# Register default local vault
#   This will require a password on first use, but we'll remove that requirement in the next step
Register-SecretVault -Name LocalStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault

# Remove authentication and interaction for the vault
Set-SecretStoreConfiguration -Authentication None -Interaction None

# Store & Retrieve secret
# Set-Secret -Name ApiKey -Secret 'abc123'
# Get-Secret -Name ApiKey -AsPlainText