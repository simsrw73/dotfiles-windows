#Requires -Version 7
<#
Creates the Bitwarden items chezmoi templates read. Run while `bw` is logged in:
    $env:BW_SESSION = bw unlock --raw
    ./scripts/seed-bitwarden.ps1
Secret values go straight from local files into bw; nothing is printed.
#>
$ErrorActionPreference = 'Stop'
if (-not $env:BW_SESSION) { throw 'Set $env:BW_SESSION = (bw unlock --raw) first.' }
bw sync | Out-Null

function Get-FolderId([string] $name) {
    $f = bw list folders --search $name | ConvertFrom-Json | Where-Object name -eq $name
    if ($f) { return $f.id }
    ((@{ name = $name } | ConvertTo-Json -Compress) | bw encode | bw create folder | ConvertFrom-Json).id
}
function Get-Item-ByName([string] $name) {
    bw list items --search $name | ConvertFrom-Json | Where-Object name -eq $name | Select-Object -First 1
}
function New-SecureNote([string] $name, [string] $folderId, $fields = @()) {
    # Built by hand: `bw get template item` has no folderId in newer CLI versions.
    $item = [ordered]@{
        organizationId = $null
        collectionIds  = $null
        folderId       = $folderId
        type           = 2
        name           = $name
        notes          = 'Managed for chezmoi (dotfiles-windows).'
        favorite       = $false
        fields         = @($fields)
        secureNote     = @{ type = 0 }
        reprompt       = 0
    }
    ($item | ConvertTo-Json -Depth 5 -Compress) | bw encode | bw create item | ConvertFrom-Json
}
function Set-Attachment($item, [string] $file) {
    $leaf = Split-Path -Leaf $file
    $old = $item.attachments | Where-Object fileName -eq $leaf
    foreach ($a in $old) { bw delete attachment $a.id --itemid $item.id | Out-Null }
    bw create attachment --file $file --itemid $item.id | Out-Null
    Write-Host "  attached $leaf"
}

$folder = Get-FolderId 'dotfiles'

# ssh-keys
$ssh = Get-Item-ByName 'ssh-keys'
if (-not $ssh) { $ssh = New-SecureNote 'ssh-keys' $folder }
Write-Host 'ssh-keys'
foreach ($k in 'id_ed25519', 'id_a24', 'private_key', 'routeros_rsa') { Set-Attachment $ssh (Join-Path $HOME ".ssh\$k") }

# gpg-signing-key
$gpgExe = git config --get gpg.program; if (-not $gpgExe) { $gpgExe = 'gpg' }
$tmp = New-Item -ItemType Directory (Join-Path $env:TEMP "bwseed-$(New-Guid)")
try {
    & $gpgExe --export-secret-keys --armor 8FDC1EB03BECE139 | Set-Content -NoNewline "$tmp\signing-key.asc"
    & $gpgExe --export-ownertrust | Set-Content "$tmp\ownertrust.txt"
    if ((Get-Item "$tmp\signing-key.asc").Length -lt 1000) { throw 'gpg export looks empty; check the passphrase prompt.' }
    $gpg = Get-Item-ByName 'gpg-signing-key'
    if (-not $gpg) { $gpg = New-SecureNote 'gpg-signing-key' $folder }
    Write-Host 'gpg-signing-key'
    Set-Attachment $gpg "$tmp\signing-key.asc"
    Set-Attachment $gpg "$tmp\ownertrust.txt"
}
finally { Remove-Item -Recurse -Force $tmp }

# env (hidden fields, one per ~/.env variable)
$fields = Get-Content (Join-Path $HOME '.env') | Where-Object { $_ -match '^\s*[A-Za-z_][A-Za-z0-9_]*=' } | ForEach-Object {
    $n, $v = $_ -split '=', 2
    @{ name = $n.Trim(); value = $v.Trim().Trim('"'); type = 1 }
}
if (-not (Get-Item-ByName 'env')) { New-SecureNote 'env' $folder $fields | Out-Null; Write-Host "env ($($fields.Count) fields)" }
else { Write-Host 'env exists; edit fields in Bitwarden if they changed' }

# flow-github
$flowFile = Join-Path $HOME '.config\FlowLauncher\Settings\Plugins\Github Quick Launcher\Settings.json'
if (-not (Get-Item-ByName 'flow-github')) {
    $f = New-SecureNote 'flow-github' $folder
    Set-Attachment $f $flowFile
    Write-Host 'flow-github'
}
bw sync | Out-Null
Write-Host 'done'
