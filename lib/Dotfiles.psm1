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
        Move-Item -LiteralPath $Path -Destination (Get-BackupPath -Path $Path -Now $Now)
        $result = 'backed-up'
    }
    else {
        $parent = Split-Path -Parent $Path
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        $result = 'created'
    }
    New-Item -ItemType $Kind -Path $Path -Target $Target | Out-Null
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
    $items = Get-ChildItem -LiteralPath $Live -Recurse -Force
    $conflicts = foreach ($i in $items) {
        if ($i.PSIsContainer -or $i.LinkType) { continue }
        $dest = Join-Path $Linked ([IO.Path]::GetRelativePath($Live, $i.FullName))
        if ((Test-Path -LiteralPath $dest) -and
            (Get-FileHash -LiteralPath $dest).Hash -ne (Get-FileHash -LiteralPath $i.FullName).Hash) {
            [IO.Path]::GetRelativePath($Live, $i.FullName)
        }
    }
    if ($conflicts) { throw "Live and linked differ; commit or reconcile first: $($conflicts -join ', ')" }

    foreach ($i in $items) {
        $dest = Join-Path $Linked ([IO.Path]::GetRelativePath($Live, $i.FullName))
        if (Test-Path -LiteralPath $dest) { continue }
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

Export-ModuleMember -Function Get-Missing, Get-BackupPath, Set-DirectoryLink, Move-IntoLinked
