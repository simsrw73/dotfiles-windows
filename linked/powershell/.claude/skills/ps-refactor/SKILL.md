---
name: ps-refactor
description: Migrate content from profile.ps1 into the appropriate ProfileModules/*.ps1 file. Use when moving env vars, aliases, functions, completers, or PSReadLine config out of the monolithic profile.
---

# PS Profile Refactor

Moves content from `profile.ps1` into the appropriate `ProfileModules/` file, keeping the profile modular and maintainable.

## What Goes Where

| Content Type | Target File |
|---|---|
| `$Env:*` / `$env:*` assignments | `Env.ps1` |
| `Set-Alias` calls | `Aliases.ps1` |
| Utility functions (Show-*, Get-*, New-*, etc.) | `Functions.ps1` |
| Completion setup (PSFzf opts, scoop-search, rustup completions, etc.) | `Completers.ps1` |
| `Set-PSReadLineOption` / `Set-PSReadLineKeyHandler` | `PSReadline.ps1` |

## Process

1. Read the current state of `profile.ps1` and the target ProfileModule file
2. Identify the block(s) to move — confirm they are self-contained (no dependencies on variables defined after the block in profile.ps1)
3. Append the block to the target ProfileModule file
4. Remove the block from profile.ps1 (the dot-source for that module is already present)
5. Verify the dot-source order in profile.ps1 is correct: Env → Aliases → Functions → Completers → PSReadline

## Guards to Add

When moving tool-dependent code (eza, bat, fzf, etc.) into a module, wrap with:

```powershell
if (Get-Command toolname.exe -ErrorAction SilentlyContinue) {
    # tool-specific config here
}
```

## Dot-Source Order in profile.ps1

The current load order (must be preserved):
```powershell
. Join-Path $moduleRoot 'Env.ps1'
. Join-Path $moduleRoot 'Aliases.ps1'
. Join-Path $moduleRoot 'Functions.ps1'
. Join-Path $moduleRoot 'Completers.ps1'
. Join-Path $moduleRoot 'PSReadline.ps1'
. Join-Path $moduleRoot 'Show-HelpColor.ps1'
```

## Example Invocation

User: `/ps-refactor — move the eza block and ls/ll/la/tree aliases to their modules`

1. Read `profile.ps1`, find the eza function definitions and Set-Alias calls
2. Move the functions to `Functions.ps1`
3. Move the `Set-Alias` calls to `Aliases.ps1`
4. Remove both blocks from `profile.ps1`
