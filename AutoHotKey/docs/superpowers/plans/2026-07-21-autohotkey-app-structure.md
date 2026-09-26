# AutoHotkey Application Structure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the AutoHotkey v2 script into an extensible application with safe lifecycle, startup, and window-launch behavior.

**Architecture:** `App` owns all entry-point lifecycle and tray-menu state, including opt-in startup registration. `WindowLauncher` provides a narrow reusable interface for restoring an existing window or launching and activating one. Hotkey files define named actions only and delegate to these objects.

**Tech Stack:** AutoHotkey v2.0, Windows Startup-folder shortcuts, PowerShell static tests.

## Global Constraints

- Require AutoHotkey v2.0 and retain the existing global hotkeys.
- Do not create a Startup shortcut merely by starting the script.
- Do not run the entry script during automated verification, because it may modify the user's Startup folder.
- Do not introduce a settings UI, INI/configuration file, or application registry.
- This workspace is not a Git repository; do not attempt commits.

---

### Task 1: Create static verification

**Files:**

- Create: `tests/Verify-AutoHotkeyStructure.ps1`
- Test: `tests/Verify-AutoHotkeyStructure.ps1`

**Interfaces:**

- Consumes: text from `autohotkey.ahk`, `hotkeys.ahk`, `Lib/App.ahk`, and `Lib/WindowLauncher.ahk`.
- Produces: exit code `0` only when required safety and structure invariants are present.

- [ ] **Step 1: Write the failing test**

Create a PowerShell test that asserts these missing features: `#SingleInstance Force`, `#Warn All, StdOut`, `class App`, and `class WindowLauncher`.

```powershell
$ErrorActionPreference = 'Stop'

function Assert-Contains([string]$Path, [string]$Pattern) {
    $content = Get-Content -Raw -LiteralPath $Path
    if ($content -notmatch [regex]::Escape($Pattern)) {
        throw "Expected '$Path' to contain '$Pattern'."
    }
}

$root = Split-Path -Parent $PSScriptRoot
Assert-Contains (Join-Path $root 'autohotkey.ahk') '#SingleInstance Force'
Assert-Contains (Join-Path $root 'autohotkey.ahk') '#Warn All, StdOut'
Assert-Contains (Join-Path $root 'Lib/App.ahk') 'class App'
Assert-Contains (Join-Path $root 'Lib/WindowLauncher.ahk') 'class WindowLauncher'
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Verify-AutoHotkeyStructure.ps1`

Expected: failure stating that `autohotkey.ahk` lacks `#SingleInstance Force`.

- [ ] **Step 3: Expand the test for all agreed behavior**

Add assertions for explicit startup toggling and its tray binding, `EditScript(*)` calling `Edit()`, `ReloadScript(*)` calling `Reload()`, `Exit(*)` calling `ExitApp()`, named handlers, existing-window activation, wait-result checks, and no startup call in the entry point. Verify that `App` inspects a shortcut before deleting it and creates a shortcut with `A_AhkPath` as target.

```powershell
Assert-Contains (Join-Path $root 'Lib/App.ahk') 'ToggleStartup(*)'
Assert-Contains (Join-Path $root 'Lib/App.ahk') 'this.ToggleStartup.Bind(this)'
Assert-Contains (Join-Path $root 'Lib/App.ahk') 'EditScript(*)'
Assert-Contains (Join-Path $root 'Lib/App.ahk') 'ReloadScript(*)'
Assert-Contains (Join-Path $root 'Lib/App.ahk') 'Exit(*)'
Assert-Contains (Join-Path $root 'Lib/App.ahk') 'Edit()'
Assert-Contains (Join-Path $root 'Lib/App.ahk') 'Reload()'
Assert-Contains (Join-Path $root 'Lib/App.ahk') 'ExitApp()'
Assert-Contains (Join-Path $root 'Lib/App.ahk') 'FileGetShortcut'
Assert-Contains (Join-Path $root 'Lib/App.ahk') 'FileCreateShortcut(A_AhkPath'
Assert-Contains (Join-Path $root 'hotkeys.ahk') 'OpenWindowsTerminal(*)'
Assert-Contains (Join-Path $root 'hotkeys.ahk') 'OpenFileExplorer(*)'
Assert-Contains (Join-Path $root 'Lib/WindowLauncher.ahk') 'WinExist(windowCriteria)'
Assert-Contains (Join-Path $root 'Lib/WindowLauncher.ahk') 'if !WinWait(windowCriteria, , timeoutSeconds)'
```

- [ ] **Step 4: Re-run test to verify it still fails for missing implementation**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Verify-AutoHotkeyStructure.ps1`

Expected: failure caused by absent production files or assertions.

### Task 2: Implement reusable application and window-launch classes

**Files:**

- Create: `Lib/App.ahk`
- Create: `Lib/WindowLauncher.ahk`
- Test: `tests/Verify-AutoHotkeyStructure.ps1`

**Interfaces:**

- Produces `App(scriptPath)` with `Start()`, `EditScript(*)`, `ReloadScript(*)`, `Exit(*)`, and `ToggleStartup(*)` methods.
- Produces `WindowLauncher.ActivateOrRun(windowCriteria, command, timeoutSeconds := 5)`.
- `WindowLauncher.ActivateOrRun` returns `true` after activation and `false` after a failed launch or timeout.

- [ ] **Step 1: Implement `WindowLauncher`**

Create `Lib/WindowLauncher.ahk` with the exact public method.

```ahk
#Requires AutoHotkey v2.0

class WindowLauncher {
    static ActivateOrRun(windowCriteria, command, timeoutSeconds := 5) {
        if hwnd := WinExist(windowCriteria) {
            if WinGetMinMax("ahk_id " hwnd) = -1
                WinRestore("ahk_id " hwnd)
            WinActivate("ahk_id " hwnd)
            return true
        }

        try Run(command)
        catch Error as err {
            MsgBox("Could not start " command ".`n`n" err.Message, "AutoHotkey", "Iconx")
            return false
        }

        if !WinWait(windowCriteria, , timeoutSeconds) {
            MsgBox("Started " command ", but its window did not appear in " timeoutSeconds " seconds.", "AutoHotkey", "Icon!")
            return false
        }

        WinActivate(windowCriteria)
        return true
    }
}
```

- [ ] **Step 2: Implement `App`**

Create `Lib/App.ahk`. The class stores an absolute script path and its owned Startup shortcut. `Start()` builds a tray menu with Edit script, Run at startup, Reload, and Exit. It checks the toggle when the owned shortcut exists. `ToggleStartup` creates or deletes only that exact shortcut. `CreateStartupShortcut` uses `A_AhkPath` as the target and quotes the script path as its argument.

```ahk
#Requires AutoHotkey v2.0

class App {
    __New(scriptPath) {
        this.scriptPath := scriptPath
        this.startupLink := A_Startup "\\" RegExReplace(A_ScriptName, "\\.ahk$", "") ".lnk"
    }

    Start() {
        A_IconTip := "Autorun script for Windows"
        A_TrayMenu.Delete()
        A_TrayMenu.Add("Edit script", this.EditScript.Bind(this))
        A_TrayMenu.Add("Run at startup", this.ToggleStartup.Bind(this))
        if this.HasOwnedStartupShortcut()
            A_TrayMenu.Check("Run at startup")
        A_TrayMenu.Add()
        A_TrayMenu.Add("Reload", this.ReloadScript.Bind(this))
        A_TrayMenu.Add("Exit", this.Exit.Bind(this))
    }
}
```

- [ ] **Step 3: Run static test to verify it reaches the entry-point failures**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Verify-AutoHotkeyStructure.ps1`

Expected: failure only for entry-point and hotkey wiring that has not yet been changed.

### Task 3: Wire lifecycle and named hotkey handlers

**Files:**

- Modify: `autohotkey.ahk`
- Modify: `hotkeys.ahk`
- Test: `tests/Verify-AutoHotkeyStructure.ps1`

**Interfaces:**

- `autohotkey.ahk` includes `Lib/App.ahk`, `Lib/WindowLauncher.ahk`, `hotkeys.ahk`, and `hotstrings.ahk`, then starts exactly one `App` instance.
- `hotkeys.ahk` calls `WindowLauncher.ActivateOrRun` from `OpenWindowsTerminal(*)` and `OpenFileExplorer(*)`.

- [ ] **Step 1: Replace entry-point lifecycle code**

Place these directives before all includes and replace the inline tray/startup functions with application startup.

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, StdOut

#Include "Lib/App.ahk"
#Include "Lib/WindowLauncher.ahk"
#Include "Hotkeys.ahk"
#Include "Hotstrings.ahk"

app := App(A_ScriptFullPath)
app.Start()
```

- [ ] **Step 2: Replace inline hotkey blocks with named handlers**

Use explicit function calls and keep the existing key combinations.

```ahk
#Requires AutoHotkey v2.0

^!#r::Reload()
^!#q::ExitApp()
^!#t::OpenWindowsTerminal()
^!#e::OpenFileExplorer()

OpenWindowsTerminal(*) {
    WindowLauncher.ActivateOrRun("ahk_exe WindowsTerminal.exe", "wt.exe")
}

OpenFileExplorer(*) {
    WindowLauncher.ActivateOrRun("ahk_class CabinetWClass", "explorer.exe")
}
```

- [ ] **Step 3: Run static test to verify it passes**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Verify-AutoHotkeyStructure.ps1`

Expected: exit code `0` and no output.

### Task 4: Review and verify source safety

**Files:**

- Modify: `docs/superpowers/specs/2026-07-21-autohotkey-app-design.md` only if implementation diverges from the approved design.
- Test: `tests/Verify-AutoHotkeyStructure.ps1`

**Interfaces:**

- Consumes the completed scripts and static test.
- Produces a review result confirming no automatic startup mutation and no unsupported scope expansion.

- [ ] **Step 1: Run the full static check**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Verify-AutoHotkeyStructure.ps1`

Expected: exit code `0` and no output.

- [ ] **Step 2: Inspect startup call sites**

Run: `rg -n "CreateStartupShortcut|ToggleStartup|FileCreateShortcut|FileDelete" autohotkey.ahk Lib\App.ahk`

Expected: startup mutation occurs only inside explicit `App` toggle/create/remove methods, never at entry-point startup.

- [ ] **Step 3: Inspect final working tree**

Run: `Get-ChildItem -Recurse -File -Include '*.ahk','*.ps1','*.md' | Select-Object FullName`

Expected: only the approved classes, test, specification, and plan are added or changed.

## Plan self-review

- Spec coverage: Tasks 2 and 3 cover class boundaries, lifecycle, startup behavior, menu actions, hotkeys, and launch errors. Task 1 provides static verification; Task 4 verifies no automatic startup mutation.
- Placeholder scan: no TODO/TBD markers or unspecified error cases remain.
- Type consistency: `App(A_ScriptFullPath)` and `WindowLauncher.ActivateOrRun(criteria, command, timeoutSeconds)` have one consistent spelling throughout.
