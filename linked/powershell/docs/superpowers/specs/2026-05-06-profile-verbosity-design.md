# Profile Output Verbosity — Design Spec

**Date:** 2026-05-06  
**Status:** Approved

## Problem

The PowerShell profile currently has 12 unconditional load-time output calls scattered across
four files. Most are noise (terminal detection, shell info, terminal size, a leftover debug
line). Nothing is gated — there is no way to silence startup output or get more detail when
troubleshooting.

## Solution

Add a `LogLevel` enum, a `$Global:ProfileLogLevel` variable, and a `Write-ProfileMsg` helper
to `profile.ps1`. All load-time output goes through this helper or is removed. The user
controls verbosity by changing one line at the top of `profile.ps1`.

---

## Core Infrastructure

### Enum and global variable

Defined at the top of `profile.ps1`, before the VS Code fast-path check:

```powershell
enum LogLevel { Error = 0; Warn = 1; Info = 2; Debug = 3 }
$Global:ProfileLogLevel = [LogLevel]::Info
```

`$Global:ProfileLogLevel` is the single control point. Users change this line to tune output.
`global:` scope makes it readable from dot-sourced ProfileModules files.

### Write-ProfileMsg function

Also defined in `profile.ps1` header, before any dot-sources:

```powershell
function global:Write-ProfileMsg {
    param(
        [Parameter(Mandatory)][string]$Message,
        [LogLevel]$Level = [LogLevel]::Info,
        [string]$Color = ''
    )
    if ([int]$Level -gt [int]$Global:ProfileLogLevel) { return }
    switch ($Level) {
        ([LogLevel]::Error) { Write-Error   $Message; return }
        ([LogLevel]::Warn)  { Write-Warning $Message; return }
    }
    $c = if ($Color) { $Color } else {
        switch ($Level) {
            ([LogLevel]::Info)  { 'Cyan' }
            ([LogLevel]::Debug) { 'DarkGray' }
        }
    }
    Write-Host $Message -ForegroundColor $c
}
```

- `Error` and `Warn` use `Write-Error`/`Write-Warning` (correct PS streams, respect preferences)
- `Info` and `Debug` use `Write-Host` — `$Global:ProfileLogLevel` is the only gate
- Optional `-Color` parameter overrides the default for that level (e.g. Green for `✓` lines)
- `global:` scope so `cli_tools_config.ps1` and other dot-sourced files can call it

---

## Outputs Removed Entirely

These are removed from all levels — they add no value at any verbosity:

| File | Current output | Reason for removal |
|---|---|---|
| `Env.ps1` | 9 terminal detection messages | Noise; terminal type already in `$isVSCodeTerm` |
| `profile.ps1` | `"Current shell: $PSInfo"` | Not useful daily |
| `profile.ps1` | Terminal size messages | Not useful daily |
| `Show-HelpColor.ps1` | `'Loading functions...'` | Leftover debug artifact |

---

## Output at Each Level

### `[LogLevel]::Warn` — warnings only (for scripting/CI)

Only `Write-Warning` and `Write-Error` calls fire. Examples:
- Module import failure: `WARNING: Module 'PSFzf' failed to load: ...`
- Transcript start failure: `WARNING: Failed to start transcript: ...`

These already use `Write-Warning` and require no change — they always fire regardless of
`$Global:ProfileLogLevel` since they route through the error/warning streams.

### `[LogLevel]::Info` — default (daily use)

```
⚡ Administrator
⚙  Dev Shell ready
```

- `⚡ Administrator` — replaces `Write-Output 'Running as Administrator'` in `Functions.ps1`;
  gated at Info so it's visible daily but suppressible
- `⚙  Dev Shell ready` — replaces the two-line `'Setting up MS Dev Environment...'` /
  `'Done.'` in `profile.ps1`; collapsed to one line, shown after VS Dev Shell initializes

### `[LogLevel]::Debug` — troubleshooting

```
  Terminal: vscode
  Modules: ✓ PSReadLine  ✓ PSFzf  · powershell-yaml
  Env.ps1  Aliases.ps1  Functions.ps1  Completers.ps1  PSReadline.ps1
  cli_tools_config.ps1:
    ✓ eza  ✓ bat  ✓ fzf  ✓ zoxide  ✓ ripgrep  · glazewm  · mosquitto  …
  → Transcript: PowerShell.Transcripts/2026-05-06/Transcript_….txt
```

- Terminal type (`$Env:TERM_PROGRAM`) — one line in DarkGray
- Module import results — `✓` for each success, `·` for each skipped/failed
- Each ProfileModule filename as it dot-sources (Env.ps1, Aliases.ps1, etc.)
- Tool availability summary from `cli_tools_config.ps1` — two script-scoped arrays
  (`$script:_toolsFound`, `$script:_toolsMissing`) are initialized at the top of the file;
  each `#region` guard appends the tool name to the appropriate array; a single
  `Write-ProfileMsg` call at the bottom of the file emits the compacted summary:
  `✓ eza  ✓ bat  ✓ fzf  …  · glazewm  · mosquitto`
- Transcript path — shown after transcript starts

---

## Glyph and Color Reference

| Glyph | Meaning | Color |
|---|---|---|
| `⚡` | Running as Administrator | Cyan (Info) |
| `⚙` | Setup step completed | Cyan (Info) |
| `✓` | Tool found / module loaded | Green (via `-Color`) |
| `·` | Tool not installed / skipped | DarkYellow (via `-Color`) |
| `→` | Path or detail value | DarkGray (Debug default) |

| Level | Default color | Stream |
|---|---|---|
| Error | (Write-Error) | Error stream |
| Warn  | (Write-Warning) | Warning stream |
| Info  | Cyan | stdout via Write-Host |
| Debug | DarkGray | stdout via Write-Host |

Glyphs are restricted to this set. No decorative use.

---

## Files Changed

| File | Change |
|---|---|
| `profile.ps1` | Add enum, `$Global:ProfileLogLevel`, `Write-ProfileMsg`; remove terminal size output and shell info; replace Dev Shell messages; gate admin output |
| `ProfileModules/Env.ps1` | Remove 9 terminal detection Write-Host calls |
| `ProfileModules/Functions.ps1` | Replace `Write-Output 'Running as Administrator'` with `Write-ProfileMsg` call |
| `ProfileModules/Show-HelpColor.ps1` | Remove `Write-Host 'Loading functions...'` |
| `ProfileModules/cli_tools_config.ps1` | Add Debug-level tool availability summary after all sections load |

---

## What Is Not Changed

- `Write-Warning` and `Write-Error` calls for genuine failures (module imports, transcript
  errors) are left as-is — they already use the correct PS streams
- Output inside fzf picker functions (`Write-Host "Installing $name..."` etc.) is runtime
  user-facing output, not startup output — left unchanged
- `Update-AllModules` Write-Host calls are runtime output — left unchanged

---

## Non-Goals

- No file logging (output to screen only)
- No timestamps
- No per-module or per-tool log levels (one global level)
- No automatic level changes based on terminal type (user sets one value)
