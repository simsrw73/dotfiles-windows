#Requires -Version 7
# Helpers used by chezmoi run_ scripts and cutover. Kept here so they can be
# tested with Pester; run_ scripts import this file from the source working tree.

function Get-Missing {
    [OutputType([string])]
    param([string[]] $Wanted = @(), [string[]] $Installed = @())
    $have = [Collections.Generic.HashSet[string]]::new([string[]] @($Installed | Where-Object { $_ }), [StringComparer]::OrdinalIgnoreCase)
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    @($Wanted | Where-Object { $_ -and -not $have.Contains($_) -and $seen.Add($_) })
}

function Get-BackupPath {
    param([Parameter(Mandatory)][string] $Path, [datetime] $Now = (Get-Date))
    $base = '{0}.pre-chezmoi-{1:yyyyMMdd}' -f $Path, $Now
    $candidate = $base
    $n = 1
    while (Test-Path -LiteralPath $candidate) { $candidate = "$base-$n"; $n++ }
    $candidate
}

function Set-DirectoryLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Target,
        [ValidateSet('Junction', 'SymbolicLink')][string] $Kind = 'Junction',
        [datetime] $Now = (Get-Date)
    )
    $Target = [IO.Path]::GetFullPath($Target).TrimEnd('\')
    if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
        throw "Link target does not exist: $Target"
    }
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType) {
        $current = [IO.Path]::GetFullPath(@($item.Target)[0]).TrimEnd('\')
        if ($current -ieq $Target) { return 'unchanged' }
        $item.Delete()   # removes only the link, never the old target's contents
        $result = 'relinked'
    }
    elseif ($item) {
        Move-Item -LiteralPath $Path -Destination (Get-BackupPath -Path $Path -Now $Now) -ErrorAction Stop
        $result = 'backed-up'
    }
    else {
        $parent = Split-Path -Parent $Path
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        $result = 'created'
    }
    New-Item -ItemType $Kind -Path $Path -Target $Target -ErrorAction Stop | Out-Null
    $result
}

function Move-IntoLinked {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Live,
        [Parameter(Mandatory)][string] $Linked,
        [datetime] $Now = (Get-Date)
    )
    $liveItem = Get-Item -LiteralPath $Live -Force -ErrorAction Stop
    if ($liveItem.LinkType) { return 'already-linked' }
    $Live = $liveItem.FullName.TrimEnd('\')
    $Linked = [IO.Path]::GetFullPath($Linked).TrimEnd('\')

    # Get-ChildItem does not descend into directory links, so nested links are
    # reported as single items and recreated rather than copied through.
    # The live folder is what apps use, so its bytes win. A file that differs from
    # the checkout (often only in line endings) is overwritten and named in a
    # warning; the committed version stays in git and the live dir is backed up.
    $items = Get-ChildItem -LiteralPath $Live -Recurse -Force
    foreach ($i in $items) {
        $rel = [IO.Path]::GetRelativePath($Live, $i.FullName)
        # Git metadata comes from the clone (and its submodules), never the live dir.
        if ($rel -split '\\' -contains '.git') { continue }
        $dest = Join-Path $Linked $rel
        if (Test-Path -LiteralPath $dest) {
            if ($i.PSIsContainer -or $i.LinkType) { continue }
            if ((Get-FileHash -LiteralPath $dest).Hash -ne (Get-FileHash -LiteralPath $i.FullName).Hash) {
                Copy-Item -LiteralPath $i.FullName -Destination $dest -Force
                Write-Warning "kept live version of $rel"
            }
            continue
        }
        if ($i.LinkType) {
            New-Item -ItemType $i.LinkType -Path $dest -Target @($i.Target)[0] | Out-Null
        }
        elseif ($i.PSIsContainer) {
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
        }
        else {
            New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
            Copy-Item -LiteralPath $i.FullName -Destination $dest
        }
    }
    Set-DirectoryLink -Path $Live -Target $Linked -Kind Junction -Now $Now
}

function Update-HomePath {
    # Points paths under another profile folder (C:\Users\<old>\...) at HomeDir, for
    # files apps write with absolute paths. Handles plain, JSON-escaped (\\), forward
    # slash and POSIX (/c/Users/...) forms. Returns how many paths it changed; the file
    # is rewritten, in its own encoding, only when that is more than zero.
    [CmdletBinding()]
    [OutputType([int])]
    param([Parameter(Mandatory)][string] $Path, [string] $HomeDir = $HOME)
    if ($HomeDir.TrimEnd('\', '/') -notmatch '^([A-Za-z]):[\\/]Users[\\/]([^\\/]+)$') {
        throw "Home is not C:\Users\<name>: $HomeDir"
    }
    $drive = $Matches[1].ToUpper()
    $user = $Matches[2]
    $keep = @($user, 'Public', 'Default')
    $count = [ref] 0

    $reader = [IO.StreamReader]::new($Path, [Text.UTF8Encoding]::new($false), $true)
    try { $text = $reader.ReadToEnd(); $encoding = $reader.CurrentEncoding }
    finally { $reader.Dispose() }

    $windows = {
        param($m)
        if ($keep -contains $m.Groups['name'].Value) { return $m.Value }
        $count.Value++
        $s = $m.Groups['sep'].Value
        "${drive}:${s}Users$s$user$s"
    }
    $posix = {
        param($m)
        if ($keep -contains $m.Groups['name'].Value) { return $m.Value }
        $count.Value++
        "/$($drive.ToLower())/Users/$user/"
    }
    $text = [regex]::Replace($text, '(?i)\b[A-Z]:(?<sep>\\\\|\\|/)Users\k<sep>(?<name>[^\\/"\s]+)\k<sep>', $windows)
    $text = [regex]::Replace($text, '(?i)(?<![\w:])/[a-z]/Users/(?<name>[^/"\s]+)/', $posix)
    if ($count.Value) { [IO.File]::WriteAllText($Path, $text, $encoding) }
    $count.Value
}

function ConvertFrom-CargoInstallList {
    # Crate names from `cargo install --list`: unindented "name vX.Y.Z[ (source)]:" lines.
    param([string[]] $Lines = @())
    foreach ($l in $Lines) { if ($l -match '^(\S+) v\S+.*:$') { $Matches[1] } }
}

function ConvertFrom-NameVersionList {
    # Tool names from `pipx list --short` / `uv tool list`: "name [v]1.2.3" lines.
    param([string[]] $Lines = @())
    foreach ($l in $Lines) { if ($l -match '^([^\s-]\S*) v?\d') { $Matches[1] } }
}

function Get-ScoopNote {
    # The "Notes" scoop prints after install (reg imports, setup scripts), read from
    # the installed manifest with scoop's variables expanded. Nothing if no notes.
    param([Parameter(Mandatory)][string] $App, [string] $ScoopRoot = $env:SCOOP)
    $current = Join-Path $ScoopRoot "apps\$App\current"
    $manifest = Join-Path $current 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifest)) { return }
    $m = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
    if (-not $m.notes) { return }
    $text = @($m.notes) -join "`n"
    # `current` rather than the versioned dir, so the paths survive updates.
    $vars = [ordered]@{
        '$original_dir' = $current
        '$persist_dir'  = Join-Path $ScoopRoot "persist\$App"
        '$scoopdir'     = $ScoopRoot
        '$version'      = [string] $m.version
        '$dir'          = $current
        '$app'          = $App
    }
    foreach ($k in $vars.Keys) { $text = $text.Replace($k, $vars[$k]) }
    [pscustomobject]@{ App = $App; Notes = $text }
}

Export-ModuleMember -Function ConvertFrom-CargoInstallList, ConvertFrom-NameVersionList, Get-Missing, Get-ScoopNote, Get-BackupPath, Set-DirectoryLink, Move-IntoLinked, Update-HomePath
