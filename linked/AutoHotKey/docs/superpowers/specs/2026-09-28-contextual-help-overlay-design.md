# Contextual help overlay (Legend integration)

## Goal

Replace the hand-maintained komorebi `CheatSheet` with
[Legend](https://github.com/simsrw73/Legend.ahk), a contextual shortcut
overlay library built for this. The library's design lives in its own repo:
`docs/specs/2026-09-28-legend-design.md`. This spec covers only how this
script adopts it.

## Getting Legend

- Git submodule at `linked/AutoHotKey/Lib/Legend`, the same pattern as
  `Lib/KeyChord`. Fresh installs get it through the existing
  `--recurse-submodules` clone in `scripts/cutover.ps1`.
- `autohotkey.ahk` adds `#Include "Lib/Legend/Legend.ahk"` with the other
  library includes, before `WindowManager.ahk`.

## Configuration

- Host folders: `legend/pages/*.md` and `legend/themes/*.ini` in this script's
  folder.
- `Legend.Start({Pages: [A_ScriptDir "\legend\pages"], Themes: [A_ScriptDir "\legend\themes"], Theme: "auto"})`
  in `autohotkey.ahk`, after the includes.
- A theme `legend/themes/mocha-yasb.ini` that sets fonts to Inter and
  JetBrainsMono Nerd Font to match yasb and the chord menu (colors stay
  Legend's Catppuccin defaults), selected instead of `auto` if preferred.

## Migration

- `WindowManager.ahk`: the komorebi hotkeys become `Legend` tables on a
  global `komorebi` page, with categories following today's comment groups
  (Workspaces, Focus / move / stack, Resize, Window state, Monitors and
  manager). h/j/k/l families use merged rows. `BindWorkspaceHotkeys` uses the
  one-line `Legend.Bind`. `CheatSheet` and its `!/`/`Esc` hotkeys are removed.
  `SecurityPrompts` is unchanged.
- `hotkeys.ahk`: the Zen `#+o` binding moves to a `Zen` page
  (`ahk_exe zen.exe`). Reload and exit go on a global `AutoHotkey` page.
- `legend/pages/zen.md`: a few native Zen shortcuts as doc-only entries.
- The Win+Space chord menu (`Chords.ahk`) and hotstrings are unchanged.

## Testing

- `tests/Verify-AutoHotkeyStructure.ps1`: assert the Legend include and
  `Legend.Start`, update komorebi assertions to the new API, remove the
  `CheatSheet` assertion; `/Validate` on `autohotkey.ahk`.
- Manual: Alt+/ on the desktop shows the index; in Zen shows the Zen page
  with the doc-only entries muted; every komorebi key still works, including
  while the overlay is open.
