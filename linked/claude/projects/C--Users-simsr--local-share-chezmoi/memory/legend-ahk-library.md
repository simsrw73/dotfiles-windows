---
name: legend-ahk-library
description: "Legend (user's public AHK v2 shortcut-overlay library) — repo, where it's used, what's next"
metadata:
  node_type: memory
  type: project
  originSessionId: 77108afa-ba70-4381-a7d0-6f35ba5479bc
  modified: 2026-09-30T21:35:59.954Z
---

Legend is the user's own open-source AutoHotkey v2 library: a contextual shortcut overlay (Alt+/) built from bindings registered via `Legend.Page(...).Category(...)` / `Legend.Bind` plus Markdown page files of doc-only keys.

- Repo: https://github.com/simsrw73/Legend.ahk, local clone `C:\Users\simsr\projects\Legend`. Specs in `docs/specs/`, plans in `docs/plans/`, backlog `TODO.md`. Tests: `pwsh -File tests/Run-Tests.ps1`.
- Consumed by the dotfiles as a git submodule at `linked/AutoHotKey/Lib/Legend` (host pages/themes in `linked/AutoHotKey/legend/`).
- Modes: reference overlay (Alt+/), chords (Win+Space menu in `Chords.ahk`), and since 2026-09-30 pickers + window switcher (`Legend.Picker`, `Legend.WindowSwitcher`, `LegendWindows`). Dotfiles bind Alt+A/S/D switchers in `WindowManager.ahk`; `Lib/WindowFocus.ahk` (Alt+HJKL fallback without komorebi) uses `LegendWindows`.
- Shared key scheme shipped 2026-09-30 (spec `docs/specs/2026-09-30-key-scheme-design.md`): Ctrl+N/P / ↓↑ move a cursor (Alt+/ index and category menus, pickers), Ctrl+F/B page, Ctrl+T picker scope, Enter opens/picks. Flat Alt+/ pages deliberately have no cursor (user confirmed after trying it). Dotfiles bind switchers on Alt+A / Alt+S only (Alt+D dropped).
- 2026-10-01: all overlays share one drawing pipeline (`Frame`/`Finish`, `LegendTableBody`/`LegendListBody`, `LegendSelection`, `Legend.Render`); cursor moves update in place. Never send WM_SETREDRAW to the overlay window: it clears WS_VISIBLE and DWM drops the overlay for a frame (the user saw random whole-window flashes).
- Backlog (TODO.md): key-scheme test gaps, browsable examples, in-place paging/filter updates (only if flicker is still noticed), window commands from the switcher (later).
- WarnHost fixture (`tests/fixtures/warn-host`) declares short host globals (a–z, id, fn, app, pad…): new Legend locals must avoid them.
- The public mirror simsrw73/w11dwm-config also carries Legend as a submodule (`autohotkey/Lib/Legend`); bump it alongside dotfiles. Push Legend before pushing either bump.

**Why:** the user wants one learning aid for all shortcuts and intends Legend to be shared publicly.
**How to apply:** changes to the overlay go in the Legend repo (then bump the submodule), not in dotfiles. See [[ahk-never-from-git-bash]].
