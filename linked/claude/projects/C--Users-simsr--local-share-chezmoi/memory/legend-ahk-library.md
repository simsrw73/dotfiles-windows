---
name: legend-ahk-library
description: "Legend (user's public AHK v2 shortcut-overlay library) — repo, where it's used, what's next"
metadata:
  node_type: memory
  type: project
  originSessionId: 77108afa-ba70-4381-a7d0-6f35ba5479bc
  modified: 2026-10-01T23:51:21.149Z
---

Legend is the user's own open-source AutoHotkey v2 library: a contextual shortcut overlay (Alt+/) built from bindings registered via `Legend.Page(...).Category(...)` / `Legend.Bind` plus Markdown page files of doc-only keys.

- Repo: https://github.com/simsrw73/Legend.ahk, local clone `C:\Users\simsr\projects\Legend`. Specs in `docs/specs/`, plans in `docs/plans/`, backlog `TODO.md`. Tests: `pwsh -File tests/Run-Tests.ps1`.
- Consumed by the dotfiles as a git submodule at `linked/AutoHotKey/Lib/Legend` (host pages/themes in `linked/AutoHotKey/legend/`).
- Modes: reference overlay (Alt+/), chords (Win+Space menu in `Chords.ahk`), and since 2026-09-30 pickers + window switcher (`Legend.Picker`, `Legend.WindowSwitcher`, `LegendWindows`). Dotfiles bind switchers in `WindowManager.ahk`; the Alt+HJKL fallback without komorebi calls `LegendWindows.Focus` (moved into Legend 2026-10-01; `WindowFocus.ahk` deleted).
- Shared key scheme shipped 2026-09-30 (spec `docs/specs/2026-09-30-key-scheme-design.md`): Ctrl+N/P / ↓↑ move a cursor (Alt+/ index and category menus, pickers), Ctrl+F/B page, Ctrl+T picker scope, Enter opens/picks. Flat Alt+/ pages deliberately have no cursor (user confirmed after trying it). Dotfiles bind switchers on Alt+A / Alt+S only (Alt+D dropped).
- 2026-10-01: all overlays share one drawing pipeline (`Frame`/`Finish`, `LegendTableBody`/`LegendListBody`, `LegendSelection`, `Legend.Render`); cursor moves update in place. Never send WM_SETREDRAW to the overlay window: it clears WS_VISIBLE and DWM drops the overlay for a frame (the user saw random whole-window flashes).
- Examples: `examples/01…06-*.ahk`, one per feature, Ctrl+Alt+Shift keys, validated by the test runner.
- Tray picker (systray icons in a picker) was built then shelved 2026-10-01 at the user's call: reading the Win11 tray via UI Automation works, but acting from a background script was flaky (first press flashed and closed; right-click left menus hanging). Parked on local branch `shelved/tray-picker` (also holds the generic Shift+Enter `OnAltPick`); spec marked shelved. Don't re-propose without a new approach (e.g. yasb-style callback messages).
- Backlog (TODO.md): in-place paging/filter updates (only if flicker is still noticed), window commands from the switcher (later).
- WarnHost fixture (`tests/fixtures/warn-host`) declares short host globals (a–z, id, fn, app, pad…): new Legend locals must avoid them.
- The public mirror simsrw73/w11dwm-config (clone `C:\Users\simsr\projects\w11dwm.config`) carries Legend as a submodule (`autohotkey/Lib/Legend`) and copies of the dotfiles' AutoHotkey files; copy changed AHK files and bump it alongside dotfiles. Push Legend before pushing either bump.

**Why:** the user wants one learning aid for all shortcuts and intends Legend to be shared publicly.
**How to apply:** changes to the overlay go in the Legend repo (then bump the submodule), not in dotfiles. See [[ahk-never-from-git-bash]].
