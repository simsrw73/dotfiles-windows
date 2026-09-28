# wpm Explicit-Stop Reproduction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reproduce and document whether `wpmd` keeps a manually stopped unit stopped for all restart policies.

**Architecture:** A PowerShell runner creates unique, non-autostart units in the live wpm configuration directory, executes two workloads across three restart policies, and records wpm state plus process evidence. Its `finally` block stops only test-prefixed units and removes only test-prefixed files. A Markdown report turns the runner's JSON into an upstream-ready conclusion.

**Tech Stack:** PowerShell 7, `wpmd`/`wpmctl` 0.1.0, TOML unit files, Windows Notepad.

## Global Constraints

- Unit names and temporary artifacts must start with `wpm-repro-`.
- Every test unit must use `Autostart = false` and `RestartSec = 1`.
- Observe each explicit stop for at least three seconds.
- Never stop, kill, reload, modify, or remove the `autohotkey-watchdog` or `yasb-watchdog` units.
- Cleanup may affect only test-prefixed unit files and Notepad processes started by a test unit.

---

### Task 1: Add the isolated test runner

**Files:**
- Create: `C:/Users/simsr/.config/wpm/tests/Invoke-WpmStopReproduction.ps1`
- Create: `C:/Users/simsr/.config/wpm/tests/fixtures/wpm-repro-loop.ps1`
- Test: `C:/Users/simsr/.config/wpm/tests/WpmStopReproduction.Tests.ps1`

**Interfaces:**
- Consumes: `wpmctl.exe`, the directory reported by `wpmctl units`, and the fixture path.
- Produces: `C:/Users/simsr/.config/wpm/tests/results/wpm-stop-reproduction.json` with one record per workload/policy pair.

- [ ] **Step 1: Write the failing runner contract test**

```powershell
$result = & "$PSScriptRoot/Invoke-WpmStopReproduction.ps1" -WhatIf
$result.Cases.Count | Should -Be 6
$result.Cases | ForEach-Object { $_.Restarted | Should -BeFalse }
```

- [ ] **Step 2: Run the contract test to verify it fails**

Run: `Invoke-Pester .\tests\WpmStopReproduction.Tests.ps1 -Output Detailed`

Expected: FAIL because `Invoke-WpmStopReproduction.ps1` does not yet exist.

- [ ] **Step 3: Create the infinite-loop fixture and runner**

Fixture body:

```powershell
while ($true) { Start-Sleep -Seconds 1 }
```

The runner generates six TOML files, using `powershell.exe -File <fixture>` for `loop` and `notepad.exe` for `notepad`; calls `wpmctl reload`; starts each unit; captures its PID/state; calls `wpmctl stop`; waits at least three seconds; captures its PID/state again; and sets `Restarted` when post-stop state is running or the PID is nonempty/new. It uses `try`/`finally` to stop only generated units and remove only generated TOML files.

- [ ] **Step 4: Run the contract test to verify it passes**

Run: `Invoke-Pester .\tests\WpmStopReproduction.Tests.ps1 -Output Detailed`

Expected: PASS for dry-run construction assertions.

- [ ] **Step 5: Commit the runner and fixture**

```powershell
git add -- tests/Invoke-WpmStopReproduction.ps1 tests/fixtures/wpm-repro-loop.ps1 tests/WpmStopReproduction.Tests.ps1
git commit -m "test: add wpm explicit-stop reproduction"
```

### Task 2: Execute the matrix and render the report

**Files:**
- Create: `C:/Users/simsr/.config/wpm/wpm-stop-reproduction-report.md`
- Test: `C:/Users/simsr/.config/wpm/tests/WpmStopReproductionReport.Tests.ps1`

**Interfaces:**
- Consumes: JSON result from Task 1.
- Produces: a self-contained report that identifies either a configuration/script cause or a `wpmd` defect.

- [ ] **Step 1: Write the failing report-content test**

```powershell
$report = Get-Content -Raw "$PSScriptRoot/../wpm-stop-reproduction-report.md"
$report | Should -Match 'wpmd 0.1.0'
$report | Should -Match 'PowerShell loop'
$report | Should -Match 'Notepad'
$report | Should -Match 'Restart = "Always"'
```

- [ ] **Step 2: Run the report test to verify it fails**

Run: `Invoke-Pester .\tests\WpmStopReproductionReport.Tests.ps1 -Output Detailed`

Expected: FAIL because the report does not yet exist.

- [ ] **Step 3: Run the live matrix and create the report**

Run:

```powershell
pwsh -NoLogo -NoProfile -File .\tests\Invoke-WpmStopReproduction.ps1
```

Record versions, commands, the six outcomes, observation window, and cleanup result. If any manually stopped unit restarts, include a ready-to-file upstream issue section with expected behavior, actual behavior, minimal reproducer, and version/commit.

- [ ] **Step 4: Run the report test to verify it passes**

Run: `Invoke-Pester .\tests\WpmStopReproductionReport.Tests.ps1 -Output Detailed`

Expected: PASS.

- [ ] **Step 5: Commit the evidence report**

```powershell
git add -- wpm-stop-reproduction-report.md tests/results/wpm-stop-reproduction.json
git commit -m "docs: report wpm explicit-stop behavior"
```

