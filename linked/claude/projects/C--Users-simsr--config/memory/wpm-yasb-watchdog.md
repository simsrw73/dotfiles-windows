---
name: wpm-yasb-watchdog
description: "wpm supervises a yasb watchdog script; wpmd starts via non-elevated \"wpmd\" scheduled task (set up 2026-09-27)"
metadata:
  node_type: memory
  type: project
  originSessionId: 46b00a22-73eb-420d-a68b-ba0c28933106
  modified: 2026-09-27T12:51:40.472Z
---

wpm units live in `~/.config/wpm` (default `wpmctl units`). Unit `yasb-watchdog` runs `yasb-watchdog.ps1`, which finds yasb by process name (yasb reloads change its PID, so wpm can't supervise yasb directly). Logs: `%LOCALAPPDATA%\wpm\logs\yasb-watchdog.log`; pause file `%LOCALAPPDATA%\wpm\yasb-watchdog.pause`.

wpmd starts at logon from scheduled task `wpmd` (conhost --headless, RunLevel Limited), recreated by `wpm/install-wpmd-task.ps1`.

**Why:** must stay non-elevated, since yasb relaunched by the watchdog would inherit admin rights.
**How to apply:** don't run wpmd as admin; the files were first pushed by an iPad cloud session to the wrong repo (boilerplate-userstyle-theme), so check the repo a cloud session targets. Related: [[yasb-bar-design]], [[dotfiles-repo-layout]].
