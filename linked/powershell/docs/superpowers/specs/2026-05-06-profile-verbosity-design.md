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

## Style Guide (applies everywhere in the profile)

All Write-Host output — startup or runtime — follows these conventions:

### Messaging language
- Short, lowercase-first phrases: `✓ eza`, `⚙ Dev Shell ready`, not `Dev Shell Has Been Initialized`
- No trailing periods on status lines
- Failures use Write-Warning (full sentence, capitalized): `WARNING: Module 'X' failed to load: …`
- Paths shown with `→`: `→ Transcript: PowerShell.Transcripts/2026-05-06/…`
- Progress shown with `…` suffix when work is ongoing, then replaced by result

### Write-ProfileMsg vs Write-Host

| Context | Mechanism | Reason |
|---|---|---|
| Startup / load-time output | `Write-ProfileMsg` | Level-gated; user may silence |
| Runtime function output (fzf pickers, Update-AllModules) | `Write-Host` directly | User explicitly invoked; always visible |
| Genuine errors / warnings | `Write-Error` / `Write-Warning` | Correct PS streams; always visible |

Both use the same colors and glyphs — the only difference is whether output is level-gated.

---

## Files Changed

| File | Change |
|---|---|
| `profile.ps1` | Add enum, `$Global:ProfileLogLevel`, `Write-ProfileMsg`; remove terminal size output and shell info; replace Dev Shell messages; gate admin output |
| `ProfileModules/Env.ps1` | Remove 9 terminal detection Write-Host calls |
| `ProfileModules/Functions.ps1` | Replace `Write-Output 'Running as Administrator'` with `Write-ProfileMsg`; restyle `Update-AllModules` output to use established colors and glyphs |
| `ProfileModules/Show-HelpColor.ps1` | Remove `Write-Host 'Loading functions...'` |
| `ProfileModules/cli_tools_config.ps1` | Add Debug-level tool availability summary; restyle fzf picker output (Write-Host stays, colors/glyphs aligned) |

### Update-AllModules restyling (before → after)

| Before | After |
|---|---|
| `=== Phase 1: Pruning stale module entries ===` (Yellow) | `⚙  Phase 1 — Pruning stale entries` (Cyan) |
| `No stale entries found.` (Green) | `  ✓ No stale entries` (Green) |
| `  Stale: $name v$ver → $path` (Red) | `  · Stale: $name v$ver` (DarkYellow) + `Write-Warning` |
| `=== Phase 2: Updating installed modules ===` (Yellow) | `⚙  Phase 2 — Updating modules` (Cyan) |
| `  [$i/$total] SKIP (needs admin): $name` (DarkYellow) | `  · [$i/$total] $name — needs admin` (DarkYellow) |
| `  [$i/$total] $name [$scope]...` + ` Done.` (Green) | `  ✓ [$i/$total] $name` (Green) |
| `=== Phase 3: Updating help files ===` (Yellow) | `⚙  Phase 3 — Updating help files` (Cyan) |
| `Help update complete.` (Green) | `  ✓ Help updated` (Green) |
| `Help update encountered errors: …` (DarkYellow) | `Write-Warning "Help update failed: …"` |
| `All done.` (Cyan) | `✓ Done` (Green) |

### Fzf picker restyling (representative examples)

| Before | After |
|---|---|
| `"Installing $name..."` (Cyan) | `⚙  Installing $name…` (Cyan) |
| `"Uninstalling $name..."` (Yellow) | `⚙  Uninstalling $name…` (DarkYellow) |
| `'Password copied to clipboard.'` (Green) | `✓ Password copied to clipboard` (Green) |
| `'Applied theme: $theme (add to …)'` (Cyan) | `✓ Theme applied: $theme` (Green) + `→ To persist, update cli_tools_config.ps1` (DarkGray) |
| `'No package.json in current directory'` (Write-Warning) | unchanged — already correct |
| `'No items found. Are you logged in? Run: bw login'` (Write-Warning) | unchanged — already correct |

---

## What Is Not Changed

- `Write-Warning` and `Write-Error` calls for genuine failures (module imports, transcript
  errors) — already use correct PS streams, no restyling needed
- Logic and behavior of all functions — this spec covers output only

---

## Non-Goals

- No file logging (output to screen only)
- No timestamps
- No per-module or per-tool log levels (one global level)
- No automatic level changes based on terminal type (user sets one value)
