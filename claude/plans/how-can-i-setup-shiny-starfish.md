# Auto-open specs/plans in Typora for review

## Context

**The need:** When Claude produces a spec or design document that the user must review
before proceeding (the superpowers `writing-plans` / `brainstorming` flow, and plan-mode
plan files), the user wants that document to open automatically — preferably in Typora.
Today the user has to manually locate and open each doc.

**Why a hook, not a skill:** A skill is *instructions to Claude*; relying on it means
Claude must *remember* to open the file every time — not reliably automatic. Anything that
must happen automatically in response to an event ("a doc was written") requires a **hook**
in `settings.json`, which the Claude Code harness executes deterministically. The
`update-config` skill confirms this: automatic event-driven behavior = hook, never memory.

**Decisions (confirmed with user):**
- **Scope:** Global — `~/.claude/settings.json` (applies to every project). This file does
  not exist yet and will be created.
- **Trigger:** Documents Claude *writes or edits* (not reads). Fires on markdown under a
  `specs/` or `plans/` folder, or any `*-design.md`. Plan-mode plan files are written via
  the `Write`/`Edit` tool, so this same hook catches them too.
- **App:** Typora at `C:\Users\simsr\AppData\Local\Programs\Typora\Typora.exe` (found on this
  machine). Typora is single-instance, so a re-edit re-focuses the existing window instead of
  spawning duplicates.

## The change

Create `C:\Users\simsr\.claude\settings.json` (the standard Windows user-settings path;
currently absent) with a single `PostToolUse` hook on the `Write|Edit` matcher.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "shell": "powershell",
            "async": true,
            "statusMessage": "Opening doc in Typora...",
            "command": "$j=[Console]::In.ReadToEnd()|ConvertFrom-Json; $f=$j.tool_response.filePath; if(-not $f){$f=$j.tool_input.file_path}; if($f -and $f -match '\\.md$' -and $f -match '([\\\\/](specs|plans)[\\\\/]|-design\\.md$)'){Start-Process 'C:\\Users\\simsr\\AppData\\Local\\Programs\\Typora\\Typora.exe' -ArgumentList $f}"
          }
        ]
      }
    ]
  }
}
```

**Command walkthrough:**
- Reads the hook's stdin JSON, prefers `tool_response.filePath` (the resolved absolute path),
  falls back to `tool_input.file_path`.
- Two-part path filter: must end in `.md` **and** either sit under a `specs/`/`plans/`
  directory or be named `*-design.md`. This matches every current doc
  (`docs/superpowers/specs/*-design.md`, `docs/superpowers/plans/*.md`) plus plan-mode files
  in `...\plans\*.md`, while ignoring ordinary source/README edits.
- `Start-Process` launches Typora non-blocking; `"async": true` guarantees the hook never
  stalls Claude's turn.

**Design notes:**
- This is a *personal* global hook — it must NOT go in the committed project
  `.claude/settings.json` (which already has two team-wide `PreToolUse` hooks and would leak a
  hardcoded Windows Typora path to teammates). Global user settings is the correct home.
- Merge, don't replace: the target file will be created fresh, so the whole object above is
  the file. If it later gains other keys, preserve them.
- Browser fallback (if ever wanted instead of Typora): swap the `Start-Process` for
  `Start-Process $f` (opens the `.md` in the OS default handler). Typora is the better markdown
  experience, so it stays the default.

## Files
- **Create:** `C:\Users\simsr\.claude\settings.json` (new global user settings)

## Verification

1. **Pipe-test the raw command** against a real repo doc before trusting the hook — synthesize
   the stdin payload the hook receives:
   ```powershell
   echo '{"tool_name":"Write","tool_input":{"file_path":"C:/Users/simsr/projects/DotForge/docs/superpowers/specs/2026-07-16-package-universe-identity-clustering-design.md"}}' | powershell -c "$j=[Console]::In.ReadToEnd()|ConvertFrom-Json; $f=$j.tool_response.filePath; if(-not $f){$f=$j.tool_input.file_path}; if($f -and $f -match '\.md$' -and $f -match '([\\/](specs|plans)[\\/]|-design\.md$)'){Start-Process 'C:\Users\simsr\AppData\Local\Programs\Typora\Typora.exe' -ArgumentList $f}"
   ```
   Expect: Typora opens that design doc. Also pipe a non-doc path (e.g. a `.ps1`) and confirm
   Typora does NOT open (filter correctly rejects it).
2. **Validate JSON + schema** so a malformed file doesn't silently disable all user settings:
   ```powershell
   Get-Content C:\Users\simsr\.claude\settings.json -Raw | ConvertFrom-Json | Out-Null; "OK"
   ```
3. **Prove the hook fires end-to-end:** the settings watcher only tracks directories that had a
   settings file at session start. Since `~/.claude/settings.json` is new, the running session
   won't pick it up automatically — open `/hooks` once (reloads config) or restart Claude Code.
   Then have Claude write a throwaway `docs/**/scratch-design.md` (or trigger plan mode) and
   confirm Typora opens it. Delete the scratch file afterward.
