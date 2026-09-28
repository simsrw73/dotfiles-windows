# Legend Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hand-maintained komorebi `CheatSheet` with Legend: every komorebi, Zen and script hotkey registers through Legend, and Alt+/ shows them with native Zen shortcuts alongside.

**Architecture:** Legend (https://github.com/simsrw73/Legend.ahk) becomes a git submodule at `linked/AutoHotKey/Lib/Legend`, like KeyChord. `autohotkey.ahk` includes it and calls `Legend.Start`; `WindowManager.ahk` and `hotkeys.ahk` register their hotkeys with `Legend.Page(...).Category(...)` tables instead of `::` labels. Host data lives in `legend/pages` and `legend/themes`.

**Tech Stack:** AutoHotkey v2.0, git submodules, PowerShell 7 structure test.

**Spec:** `docs/superpowers/specs/2026-09-28-contextual-help-overlay-design.md` (this folder); Legend's own spec is `Lib/Legend/docs/specs/2026-09-28-legend-design.md`.

## Global Constraints

- All paths below are relative to `linked/AutoHotKey/` unless they start with the chezmoi repo root (`~/.local/share/chezmoi`).
- The chezmoi repo has unrelated uncommitted changes (FlowLauncher, claude, wpm). Stage only the exact paths each task names; never `git add -A` or `git add .`.
- Commit subjects use this repo's area prefix: `AutoHotKey: …`. Messages end with these two trailer lines (same paragraph):
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_01USck9RpHpDzGupiFEosHqF`
- The entry point runs with `#Warn All, StdOut`; the structure test treats any validation output (errors or warnings) as a failure.
- Win+Space (`Chords.ahk`) and `Hotstrings.ahk` are not changed beyond Task 1.
- Help key stays Alt+/. Theme `mocha-yasb` (Catppuccin Mocha colors, Inter + JetBrainsMono Nerd Font).
- Test command: `pwsh -NoProfile -File tests/Verify-AutoHotkeyStructure.ps1` (throws on the first failed assertion; silent exit 0 on success).

## Review Focus

1. Legend's local variable names colliding with this script's globals under `#Warn All` (warnings at load). Test: Task 2's validation step fails on any output.
2. A fresh clone without `--recurse-submodules` must fail the structure test with a clear message, not an AHK include error. Test: Task 2, submodule presence check.
3. The Zen binding must stay Zen-only: its `match` must be given in code (a page file's `match:` never conditions hotkeys). Test: Task 4 asserts `Legend.Page("Zen", "ahk_exe zen.exe")`.
4. All nine workspace numbers must still bind focus and move. Test: Task 3 asserts both `Legend.Bind` calls inside `BindWorkspaceHotkeys`.
5. No leftover `::` label for Alt+/ competing with Legend's help key. Test: Task 3 asserts `CheatSheet` and `!/::` are gone.

---

### Task 1: Commit the pending chord-menu change

The Win+Space timeout removal (and the `ChordOverlay.ShowCentered` extraction) from earlier this session is uncommitted. Commit it on its own so later diffs only show the Legend work. The uncommitted `CheatSheet` in `WindowManager.ahk` and its test line are replaced in Task 3 and are not committed here.

**Files:**
- Commit: `Chords.ahk`

**Interfaces:**
- Produces: `Chords.Timeout := 0` (no auto-close); `ChordOverlay.ShowCentered(g)` (still used by the chord menu).

- [ ] **Step 1: Run the structure test as a baseline**

Run: `pwsh -NoProfile -File tests/Verify-AutoHotkeyStructure.ps1; "exit=$LASTEXITCODE"`
Expected: `exit=0`, no output.

- [ ] **Step 2: Commit only `Chords.ahk`**

```bash
git add linked/AutoHotKey/Chords.ahk   # from the chezmoi repo root
git commit -m "AutoHotKey: chord menu waits for a key; share overlay centering"
```

---

### Task 2: Add Legend as a submodule and start it

**Files:**
- Create (submodule): `Lib/Legend` → https://github.com/simsrw73/Legend.ahk.git
- Modify (repo root): `~/.local/share/chezmoi/.gitmodules`
- Modify: `autohotkey.ahk`, `tests/Verify-AutoHotkeyStructure.ps1`
- Create: `legend/themes/mocha-yasb.ini`, `legend/pages/zen.md`

**Interfaces:**
- Consumes (Legend): `#Include "Lib/Legend/Legend.ahk"`, `Legend.Start({Pages, Themes, Theme})`.
- Produces: Legend loaded before `WindowManager.ahk`, so later tasks can call `Legend.Page` / `Legend.Bind`.

- [ ] **Step 1: Add the failing assertions**

In `tests/Verify-AutoHotkeyStructure.ps1`, after `$chords = Join-Path $root 'Chords.ahk'` add:
```powershell
$legend = Join-Path $root 'Lib/Legend/Legend.ahk'
if (-not (Test-Path $legend)) {
    throw "Legend submodule missing at Lib/Legend. Run: git submodule update --init --recursive"
}
```
After `Assert-Contains $entryPoint '#Include "Lib/KeyChord/KeyChord.ahk"'` add:
```powershell
Assert-Contains $entryPoint '#Include "Lib/Legend/Legend.ahk"'
Assert-Contains $entryPoint 'Legend.Start({Pages: [A_ScriptDir "\legend\pages"], Themes: [A_ScriptDir "\legend\themes"], Theme: "mocha-yasb"})'
```
At the end of the file add:
```powershell
# Load-time check of the whole script, including Legend, under the entry point's #Warn All.
$ahk = @(
    (Get-Command AutoHotkey64.exe -ErrorAction SilentlyContinue).Source
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $ahk) { throw 'AutoHotkey v2 not found' }
$validation = & $ahk /ErrorStdOut /Validate $entryPoint 2>&1 | Out-String
if ($LASTEXITCODE -or $validation.Trim()) {
    throw "autohotkey.ahk failed validation:`n$validation"
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `pwsh -NoProfile -File tests/Verify-AutoHotkeyStructure.ps1; "exit=$LASTEXITCODE"`
Expected: throws `Legend submodule missing at Lib/Legend. Run: git submodule update --init --recursive`.

- [ ] **Step 3: Add the submodule**

From the chezmoi repo root:
```bash
git submodule add https://github.com/simsrw73/Legend.ahk.git linked/AutoHotKey/Lib/Legend
git -C linked/AutoHotKey/Lib/Legend log --oneline -1
```
Expected: the last line shows `de6a0de Fix review findings: key watcher, letter pass-through, host HotIf` (or a later Legend commit).

- [ ] **Step 4: Run the test to verify the next failure**

Run: `pwsh -NoProfile -File tests/Verify-AutoHotkeyStructure.ps1; "exit=$LASTEXITCODE"`
Expected: throws `Expected '...autohotkey.ahk' to contain '#Include "Lib/Legend/Legend.ahk"'.`

- [ ] **Step 5: Include and start Legend**

`autohotkey.ahk` becomes:
```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, StdOut

#Include "Lib/App.ahk"
#Include "Lib/WindowLauncher.ahk"
#Include "Lib/Komorebi.ahk"
#Include "Lib/KeyChord/KeyChord.ahk"
#Include "Lib/Legend/Legend.ahk"
#Include "Apps.ahk"
#Include "WindowManager.ahk"
#Include "Chords.ahk"
#Include "Hotkeys.ahk"
#Include "Hotstrings.ahk"

; Alt+/ shows the shortcuts registered through Legend plus legend/pages/*.md.
Legend.Start({Pages: [A_ScriptDir "\legend\pages"], Themes: [A_ScriptDir "\legend\themes"], Theme: "mocha-yasb"})

application := App(A_ScriptFullPath)
application.Start()
```

`legend/themes/mocha-yasb.ini` (ASCII):
```ini
; Catppuccin Mocha (Legend defaults) with the fonts yasb and the chord menu use.
[fonts]
uiFont=Inter
keyFont=JetBrainsMono Nerd Font
```

`legend/pages/zen.md`:
```markdown
---
match: ahk_exe zen.exe
---
# Zen

Zen's own shortcuts (Firefox defaults unless noted). Win+Shift+O comes from
hotkeys.ahk and shows as bound.

## Tabs
- `Ctrl+T` New tab
- `Ctrl+W` Close tab
- `Ctrl+Shift+T` Reopen closed tab
- `Ctrl+Tab` Next tab
- `Ctrl+Shift+Tab` Previous tab
- `Ctrl+1–8` Go to tab 1–8
- `Ctrl+9` Go to last tab

## Page
- `Ctrl+L` Focus the address bar
- `Ctrl+Alt+C` Copy current URL (remapped from Ctrl+Shift+C)
- `Ctrl+F` Find in page
- `Ctrl+R` Reload
- `Alt+←` Back
- `Alt+→` Forward
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `pwsh -NoProfile -File tests/Verify-AutoHotkeyStructure.ps1; "exit=$LASTEXITCODE"`
Expected: `exit=0`, no output. If validation prints a `#Warn` line naming a Legend local (e.g. "This local variable has the same name as a global variable … in function Legend.…"), fix it upstream in the Legend repo (rename the local, add nothing else), push, `git -C linked/AutoHotKey/Lib/Legend pull`, and ledger the ruling. Do not weaken the validation check.

The old `CheatSheet` still defines `!/::` until Task 3; Legend's `Hotkey("!/")` replaces it at runtime, so the two do not conflict.

- [ ] **Step 7: Commit**

From the chezmoi repo root:
```bash
git add .gitmodules linked/AutoHotKey/Lib/Legend linked/AutoHotKey/autohotkey.ahk \
    linked/AutoHotKey/legend linked/AutoHotKey/tests/Verify-AutoHotkeyStructure.ps1
git commit -m "AutoHotKey: add Legend submodule and start it"
```
(The test file also carries Task 1's uncommitted `CheatSheet` assertion; it is removed in Task 3.)

---

### Task 3: Move the komorebi keys to Legend and delete CheatSheet

**Files:**
- Modify: `WindowManager.ahk`, `tests/Verify-AutoHotkeyStructure.ps1`

**Interfaces:**
- Consumes: `Legend.Page(title) → page`, `page.Category(name, rows, group?)`, `Legend.Bind(path, hotkey, description, fn, options?)`, row options `{Row, Text}`; `Komorebi.Run`, `Komorebi.FocusWorkspace`, `Komorebi.MoveToWorkspace`, `Komorebi.SwapWorkspaceWithOtherMonitor` (unchanged, `Lib/Komorebi.ahk`).
- Produces: a global `komorebi` page with categories Workspaces, Focus / move / stack, Resize, Window state, Monitors & manager.

- [ ] **Step 1: Update the assertions**

In `tests/Verify-AutoHotkeyStructure.ps1`, replace
```powershell
Assert-Contains $windowManager '!/::CheatSheet.Toggle()'
```
with
```powershell
Assert-Contains $windowManager 'komorebiKeys := Legend.Page("komorebi")'
Assert-NotContains $windowManager 'komorebi := '
Assert-HandlerContains $windowManager 'BindWorkspaceHotkeys(workspaces)' 'Legend.Bind(["komorebi", "Workspaces", "Focus"], "!" i'
Assert-HandlerContains $windowManager 'BindWorkspaceHotkeys(workspaces)' 'Legend.Bind(["komorebi", "Workspaces", "Move window"], "!+" i'
Assert-NotContains $windowManager 'CheatSheet'
Assert-NotContains $windowManager '!/::'
Assert-NotContains $windowManager '::Komorebi.'
Assert-Contains $windowManager 'SecurityPrompts.Watch()'
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `pwsh -NoProfile -File tests/Verify-AutoHotkeyStructure.ps1; "exit=$LASTEXITCODE"`
Expected: throws `Expected '...WindowManager.ahk' to contain 'komorebiKeys := Legend.Page("komorebi")'.`

- [ ] **Step 3: Rewrite `WindowManager.ahk`**

Replace the whole file with:
```ahk
#Requires AutoHotkey v2.0

; komorebi keys, following komorebi's sample whkdrc. Alt is the window-manager modifier.
; Workspaces are numbered across both monitors in komorebi.json order:
;   4K: 1 dev · 2 notes · 3 ai-lab · 4 admin      LG: 5 research · 6 comms · 7 files · 8 games · 9 scratch
; Every key registers through Legend, so Alt+/ lists it on the komorebi page.

komorebiKeys := Legend.Page("komorebi")  ; not "komorebi": names are case-insensitive and Komorebi is a class

BindWorkspaceHotkeys(["dev", "notes", "ai-lab", "admin", "research", "comms", "files", "games", "scratch"])

BindWorkspaceHotkeys(workspaces) {
    for i, workspace in workspaces {
        Legend.Bind(["komorebi", "Workspaces", "Focus"], "!" i, i " " workspace, FocusWorkspaceHotkey(workspace))
        Legend.Bind(["komorebi", "Workspaces", "Move window"], "!+" i, "to " i " " workspace, MoveToWorkspaceHotkey(workspace))
    }
}
FocusWorkspaceHotkey(workspace) => (*) => Komorebi.FocusWorkspace(workspace)
MoveToWorkspaceHotkey(workspace) => (*) => Komorebi.MoveToWorkspace(workspace)

komorebiKeys.Category("Workspaces", [
    ["!+0", "to scratch", (*) => Komorebi.MoveToWorkspace("scratch")]
], "Move window")

komorebiKeys.Category("Focus / move / stack", [
    ["!h", "focus left", (*) => Komorebi.Run("focus", "left"), {Row: "Alt+H/J/K/L", Text: "focus ← ↓ ↑ →"}],
    ["!j", "focus down", (*) => Komorebi.Run("focus", "down"), {Row: "Alt+H/J/K/L"}],
    ["!k", "focus up", (*) => Komorebi.Run("focus", "up"), {Row: "Alt+H/J/K/L"}],
    ["!l", "focus right", (*) => Komorebi.Run("focus", "right"), {Row: "Alt+H/J/K/L"}],
    ["!+h", "move left", (*) => Komorebi.Run("move", "left"), {Row: "Alt+Shift+H/J/K/L", Text: "move window ← ↓ ↑ →"}],
    ["!+j", "move down", (*) => Komorebi.Run("move", "down"), {Row: "Alt+Shift+H/J/K/L"}],
    ["!+k", "move up", (*) => Komorebi.Run("move", "up"), {Row: "Alt+Shift+H/J/K/L"}],
    ["!+l", "move right", (*) => Komorebi.Run("move", "right"), {Row: "Alt+Shift+H/J/K/L"}],
    ["!+Enter", "promote to main", (*) => Komorebi.Run("promote")],
    ["!^h", "stack left", (*) => Komorebi.Run("stack", "left"), {Row: "Ctrl+Alt+H/J/K/L", Text: "stack onto ← ↓ ↑ →"}],
    ["!^j", "stack down", (*) => Komorebi.Run("stack", "down"), {Row: "Ctrl+Alt+H/J/K/L"}],
    ["!^k", "stack up", (*) => Komorebi.Run("stack", "up"), {Row: "Ctrl+Alt+H/J/K/L"}],
    ["!^l", "stack right", (*) => Komorebi.Run("stack", "right"), {Row: "Ctrl+Alt+H/J/K/L"}],
    ["!;", "unstack", (*) => Komorebi.Run("unstack")],
    ["![", "previous in stack", (*) => Komorebi.Run("cycle-stack", "previous"), {Row: "Alt+[ / ]", Text: "previous / next in stack"}],
    ["!]", "next in stack", (*) => Komorebi.Run("cycle-stack", "next"), {Row: "Alt+[ / ]"}]
])

komorebiKeys.Category("Resize", [
    ["!=", "wider", (*) => Komorebi.Run("resize-axis", "horizontal", "increase"), {Row: "Alt+= / -", Text: "wider / narrower"}],
    ["!-", "narrower", (*) => Komorebi.Run("resize-axis", "horizontal", "decrease"), {Row: "Alt+= / -"}],
    ["!+=", "taller", (*) => Komorebi.Run("resize-axis", "vertical", "increase"), {Row: "Alt+Shift+= / -", Text: "taller / shorter"}],
    ["!+-", "shorter", (*) => Komorebi.Run("resize-axis", "vertical", "decrease"), {Row: "Alt+Shift+= / -"}]
])

komorebiKeys.Category("Window state", [
    ["!q", "close window", (*) => Komorebi.Run("close")],
    ["!t", "toggle float", (*) => Komorebi.Run("toggle-float")],
    ["!+f", "toggle monocle", (*) => Komorebi.Run("toggle-monocle")],
    ["!+Space", "next layout", (*) => Komorebi.Run("cycle-layout", "next")],
    ["!x", "flip horizontal", (*) => Komorebi.Run("flip-layout", "horizontal"), {Row: "Alt+X / Y", Text: "flip horizontal / vertical"}],
    ["!y", "flip vertical", (*) => Komorebi.Run("flip-layout", "vertical"), {Row: "Alt+X / Y"}]
])

komorebiKeys.Category("Monitors & manager", [
    ["!+s", "swap workspace with other monitor", (*) => Komorebi.SwapWorkspaceWithOtherMonitor()],
    ["!+w", "move window to next monitor", (*) => Komorebi.Run("cycle-move-to-monitor", "next")],
    ["!+r", "retile", (*) => Komorebi.Run("retile")],
    ["!+o", "reload komorebi config", (*) => Komorebi.Run("reload-configuration")],
    ["!p", "pause komorebi", (*) => Komorebi.Run("toggle-pause")]
])

; Windows Hello / credential prompts (CredentialUIBroker) often open behind the active
; window because the app that asked for them isn't in the foreground. komorebi ignores
; them (applications.json), so raise them here like the other popups. The app that asked
; for the prompt (Bitwarden, always-on-top) keeps pulling focus back while it waits, so a
; one-shot raise loses: hold the prompt on top and focused for as long as it is open.
class SecurityPrompts {
    ; Match on class only: the "Windows Security" title isn't set yet when the window is created.
    static Criteria := "ahk_class Credential Dialog Xaml Host"
    static Last := 0

    static Watch() {
        SetTimer(ObjBindMethod(this, "Hold"), 250)
    }

    static Hold() {
        static WS_EX_TOPMOST := 0x8
        if !(hwnd := WinExist(this.Criteria)) {
            this.Last := 0
            return
        }
        target := "ahk_id " hwnd
        try {
            if hwnd != this.Last {           ; new prompt: center it on the monitor in use
                this.Last := hwnd
                WindowLauncher.Activate(hwnd, WindowLauncher.ActiveMonitorWorkArea())
                return
            }
            if !(WinGetExStyle(target) & WS_EX_TOPMOST)
                WinSetAlwaysOnTop(1, target)
            if !WinActive(target)
                WinActivate(target)
        } catch TargetError                  ; the prompt closed under us
            return
    }
}
SecurityPrompts.Watch()
```

`Chords.ahk` keeps `ChordOverlay.ShowCentered` and `RoundCorners` for the chord menu; nothing there changes.

- [ ] **Step 4: Run the test to verify it passes**

Run: `pwsh -NoProfile -File tests/Verify-AutoHotkeyStructure.ps1; "exit=$LASTEXITCODE"`
Expected: `exit=0`, no output (validation included).

- [ ] **Step 5: Commit**

```bash
git add linked/AutoHotKey/WindowManager.ahk linked/AutoHotKey/tests/Verify-AutoHotkeyStructure.ps1
git commit -m "AutoHotKey: register komorebi keys through Legend; drop CheatSheet"
```

---

### Task 4: Move the script and Zen hotkeys to Legend

**Files:**
- Modify: `hotkeys.ahk`, `tests/Verify-AutoHotkeyStructure.ps1`

**Interfaces:**
- Consumes: `Legend.Page(title, match?)`, `page.Category(name, rows)`.
- Produces: global page `AutoHotkey` (Script: reload, exit) and page `Zen` (`ahk_exe zen.exe`, Tabs: Win+Shift+O), merging with `legend/pages/zen.md`.

- [ ] **Step 1: Update the assertions**

In `tests/Verify-AutoHotkeyStructure.ps1`, replace
```powershell
Assert-Contains $hotkeys '^!#r::Reload()'
```
with
```powershell
Assert-Contains $hotkeys '["^!#r", "reload AutoHotkey", (*) => Reload()]'
Assert-Contains $hotkeys '["^!#q", "exit AutoHotkey", (*) => ExitApp()]'
Assert-Contains $hotkeys 'Legend.Page("Zen", "ahk_exe zen.exe")'
Assert-Contains $hotkeys '["#+o", "open current tab in Chrome", (*) => OpenCurrentZenTabInChrome()]'
Assert-NotContains $hotkeys '#HotIf'
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `pwsh -NoProfile -File tests/Verify-AutoHotkeyStructure.ps1; "exit=$LASTEXITCODE"`
Expected: throws `Expected '...hotkeys.ahk' to contain '["^!#r", "reload AutoHotkey", (*) => Reload()]'.`

- [ ] **Step 3: Rewrite the top of `hotkeys.ahk`**

Replace everything from the first line through the closing `#HotIf` (the lines `^!#r::Reload()` … `#+o::OpenCurrentZenTabInChrome()` / `#HotIf`, including the `zenWin := "ahk_exe zen.exe"` line and its comment) with:
```ahk
#Requires AutoHotkey v2.0

Legend.Page("AutoHotkey").Category("Script", [
    ["^!#r", "reload AutoHotkey", (*) => Reload()],
    ["^!#q", "exit AutoHotkey", (*) => ExitApp()]
])

; App launching lives in Chords.ahk (Win+Space).


localAppDataDir := EnvGet("LocalAppData")
chromePath := "C:\Program Files\Google\Chrome\Application\chrome.exe"
cleanProfileDir := localAppDataDir "\Google\Chrome\AHK-CleanProfile"

; The match here (not only in legend/pages/zen.md) keeps Win+Shift+O Zen-only.
Legend.Page("Zen", "ahk_exe zen.exe").Category("Tabs", [
    ["#+o", "open current tab in Chrome", (*) => OpenCurrentZenTabInChrome()]
])
```
Leave `OpenCurrentZenTabInChrome()` and everything after it unchanged.

- [ ] **Step 4: Run the test to verify it passes**

Run: `pwsh -NoProfile -File tests/Verify-AutoHotkeyStructure.ps1; "exit=$LASTEXITCODE"`
Expected: `exit=0`, no output.

- [ ] **Step 5: Commit**

```bash
git add linked/AutoHotKey/hotkeys.ahk linked/AutoHotKey/tests/Verify-AutoHotkeyStructure.ps1
git commit -m "AutoHotKey: register script and Zen hotkeys through Legend"
```

---

### Task 5: Reload and check by hand

**Files:** none (manual verification; fix anything that fails in the task that owns it, with a ledgered ruling).

- [ ] **Step 1: Reload the running script**

Press Ctrl+Alt+Win+R (still bound, now through Legend). Expected: no error dialog, no warning output.

- [ ] **Step 2: Check the overlay**

- Desktop focused, Alt+/ → index lists AutoHotkey, komorebi, Zen.
- `k` → komorebi page. On the 4K monitor it should fit one screen (shown flat); if it does not, a category list appears (Workspaces, Focus / move / stack, Resize, Window state, Monitors & manager).
- Focus Zen, Alt+/ → Zen page: Win+Shift+O in the bound color, the native keys in the muted color.
- With the overlay open, Alt+H → komorebi focus moves and the overlay closes.
- `` ` `` pins; Alt+H/J/K/L then move focus while the overlay stays; `` ` `` unpins.
- Every komorebi key, Win+Space and the Zen Win+Shift+O still work with the overlay closed.

- [ ] **Step 3: Record the result**

Report which checks passed; anything that failed goes back to its task as a fix with a test where the structure test can express it.
