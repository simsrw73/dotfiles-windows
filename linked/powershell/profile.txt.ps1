function Import-ProfileScript {
    param(
        [Parameter(Mandatory)]
        [string] $RelativePath
    )

    $profileRoot = Split-Path -Parent $PROFILE
    $moduleRoot = Join-Path $profileRoot 'ProfileModules'
    $path = Join-Path $moduleRoot $RelativePath

    if (-not (Test-Path -LiteralPath $path)) {
        Write-Warning "Profile script not found: $path"
        return
    }

    # This *must* be a dot; it runs in the caller's scope
    . $path
    Write-Host "Inported profile script: $path"
    Get-Command Show-HelpColor -ErrorAction SilentlyContinue | Format-List Name, CommandType, Source
}

# In your profile *top level* (not inside another function/scriptblock):
. Import-ProfileScript 'Show-HelpColor.ps1'
Write-Host 'Finished importing.'
Get-Command Show-HelpColor -ErrorAction SilentlyContinue | Format-List Name, CommandType, Source
