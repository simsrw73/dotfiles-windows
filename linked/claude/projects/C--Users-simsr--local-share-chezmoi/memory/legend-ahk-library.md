---
name: legend-ahk-library
description: "Legend (user's public AHK v2 shortcut-overlay library) — repo, where it's used, what's next"
metadata:
  node_type: memory
  type: project
  originSessionId: 77108afa-ba70-4381-a7d0-6f35ba5479bc
  modified: 2026-09-28T19:20:50.549Z
---

Legend is the user's own open-source AutoHotkey v2 library: a contextual shortcut overlay (Alt+/) built from bindings registered via `Legend.Page(...).Category(...)` / `Legend.Bind` plus Markdown page files of doc-only keys.

- Repo: https://github.com/simsrw73/Legend.ahk, local clone `C:\Users\simsr\projects\Legend`. Spec `docs/specs/2026-09-28-legend-design.md`, backlog `TODO.md`. Tests: `pwsh -File tests/Run-Tests.ps1`.
- Consumed by the dotfiles as a git submodule at `linked/AutoHotKey/Lib/Legend` (integrated 2026-09-28; komorebi, Zen and script keys registered through it; host pages/themes in `linked/AutoHotKey/legend/`).
- Shipped 2026-09-28: display toggles (Tab notation, `=` density) and chord mode; the dotfiles' Win+Space menu (`Chords.ahk`) runs on `Legend.Chord` and the KeyChord submodule was removed.
- Remaining ideas and deferred review minors live in Legend's TODO.md. Legend commits must be pushed before a dotfiles commit that bumps the submodule is pushed.

**Why:** the user wants one learning aid for all shortcuts and intends Legend to be shared publicly.
**How to apply:** changes to the overlay go in the Legend repo (then bump the submodule), not in dotfiles. See [[ahk-never-from-git-bash]].
