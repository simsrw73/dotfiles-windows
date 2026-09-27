---
name: typora-doc-review
description: User reviews markdown specs/design docs/plans in Typora; a global hook auto-opens them
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a38a9853-4a31-4285-8540-d1e8f3dcb393
---

The user reviews markdown documents (specs, design docs, plans) in **Typora**
(`C:\Users\simsr\AppData\Local\Programs\Typora\Typora.exe`), with a web browser as an
acceptable fallback.

A global `PostToolUse` hook auto-opens any markdown that Claude writes/edits under a `specs/`/`plans/`
folder or named `*-design.md` (this also catches plan-mode plan files, written via Write/Edit).

**Location matters:** `CLAUDE_CONFIG_DIR` is set to `C:\Users\simsr\.config\claude`, so Claude Code
reads user settings from `…\.config\claude\settings.json` — NOT the default `~/.claude/settings.json`.
The hook must live in the active file (fixed 2026-07-16; it was orphaned in the dormant `~/.claude`
copy and never fired). The dormant `~/.claude/settings.json` still holds a copy for reference.
Settings load at session start, so hook edits take effect on the next session, not mid-session.

**Why:** the "review before proceeding" moment in the superpowers flow is when Claude produces a
plan/spec; the user wanted that surfaced automatically rather than hunting for the file.

**How to apply:** if you ever need to show the user a markdown doc directly, prefer opening it in
Typora over pasting long content. Don't duplicate the hook's job by manually launching Typora on
docs the hook already covers.
