---
name: ahk-never-from-git-bash
description: "Never launch AutoHotkey64.exe from the Bash tool; Git Bash mangles /ErrorStdOut and pops dialogs on the user's desktop"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 77108afa-ba70-4381-a7d0-6f35ba5479bc
  modified: 2026-09-28T16:13:36.498Z
---

Run AutoHotkey (tests, /Validate, smoke scripts) only via the PowerShell tool or `pwsh`, never directly from the Bash tool.

**Why:** Git Bash's MSYS path conversion turns `/ErrorStdOut` into `C:/Program Files/Git/ErrorStdOut`, so AutoHotkey shows a modal "Script file not found" dialog on the user's desktop — repeatedly, if a subagent loops. The user hit this on 2026-09-28 while testing Legend.

**How to apply:** Use PowerShell with `& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut ... 2>&1 | Out-String` (piping makes PowerShell wait and capture stdout). When dispatching subagents that might touch AutoHotkey, state this rule in their prompt. Related: [[legend-ahk-library]].
