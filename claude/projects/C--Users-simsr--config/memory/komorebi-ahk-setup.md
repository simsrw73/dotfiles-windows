---
name: komorebi-ahk-setup
description: "User's komorebi + AHK v2 window-manager setup (built 2026-09-26) — workspace map, key scheme, and gotchas found while building it"
metadata:
  node_type: memory
  type: project
  originSessionId: 242fa7a9-8960-4acd-9ebb-af7e6a2a0696
  modified: 2026-09-26T21:00:04.307Z
---

Built 2026-09-26. The user is new to tiling WMs and relies on Claude's recommendations for what's typical.

Layout (komorebi/komorebi.json, monitors pinned by serial): 4K Dell `H6TNT84` = dev (Zed, WT "Claude Code" + "Shell"), notes (Obsidian), ai-lab (Perplexity, Claude desktop, ChatGPT, GitHub Copilot `github.exe`, Gemini Chrome PWA), admin (sysinternals, mmc snap-ins, regedit, UniGetUI, Windhawk, Settings/Control Panel, HWiNFO, WizTree…, MikroTik WinBox; added same day). LG `209NTCZBE803` = research (zen/brave/chrome/edge/Typora stacked via `window_container_behaviour: Append`), comms (Spark, TickTick, Fantastical), files (Explorer, Everything), games (all game launchers + mod managers — Steam, GOG, Epic, EA, Ubisoft, Vortex, MO2… — in one stack via `Append`), scratch. Koffee, Bitwarden and TMOG `Task Manager.exe` are komorebi `ignore_rules` + AHK always-on-top popups.

Keys: AHK replaces whkd. Alt = WM (sample-whkdrc scheme, Alt+1..9 named workspaces in screen order: dev notes ai-lab admin | research comms files games scratch; stack is Alt+Ctrl+hjkl because Alt+Left is browser Back). Win+Space = themed which-key chord menu (AutoHotKey/Chords.ahk, app registry in Apps.ahk).

**Why:** the user's spec; future changes should keep this map and the Catppuccin look ([[yasb-bar-design]]).
**How to apply / gotchas:**
- Komorebi does NOT follow WinActivate to a cloaked window's workspace. Lib/Komorebi.ahk `WorkspaceOf(hwnd)` parses `komorebic state` and focuses the workspace first.
- AHK v2 treats komorebi-cloaked windows as hidden: search with DetectHiddenWindows(true) and filter on WS_VISIBLE (`WindowLauncher.Find`).
- komorebi restores `%TEMP%\komorebi.state.json` on start, which overrides new workspace config. Use `komorebic start --clean-state` after structural changes.
- Git Bash mangles `/ErrorStdOut` into a path (AHK shows "Script file not found" dialogs). Run AutoHotkey64.exe from PowerShell.
- An AHK global named `app` collides with `class App`. Top-level helper names like `Action`/`index`/`number` trigger #Warn clashes with KeyChord locals.
- Always launch AHK via ~/.config/AutoHotKey/autohotkey.ahk, never the OneDrive junction path. #SingleInstance compares paths, so the two paths ran as separate copies. The startup link was repointed to .config on 2026-09-26.
- Elevated windows (mmc snap-ins, regedit, HWiNFO…) need elevated komorebi and UI-Access AHK, set up 2026-09-26. Komorebi starts from the scheduled task `komorebi` (RunLevel Highest, at logon); the komorebi.lnk autostart was removed. AHK runs as `C:\Program Files\AutoHotkey\v2\AutoHotkey64_UIA.exe`, which the startup link targets. The winget AHK package is user-scope only, so the machine install used `setup.exe /silent /installto "C:\Program Files\AutoHotkey"`. The old per-user install in AppData may still be around.
- Auto mode blocks creating logon persistence (scheduled tasks). Hand the user a script to run with `! gsudo …`.
