# Resume: Alias Ownership — Task 3 + Task 4

## Context

Branch `feat/alias-ownership` is executing
`docs/superpowers/plans/2026-07-26-alias-ownership.md` (backed by the design doc
`docs/superpowers/specs/2026-07-26-alias-ownership-design.md`). The goal of the
workstream: make DotForge's 27 general-helper aliases genuinely module-owned
(so `(Get-Module DotForge).ExportedAliases` and `Remove-Module` actually work),
rename the one builtin-colliding alias (`copy`→`yank`), and formally document
the two-category alias model (general-helper = manifest-owned,
tool/picker = registry-owned).

Verified against the actual repo state:
- **Task 1** (rename `copy`→`yank`) — done, commit `1e85cfa`.
- **Task 2** (module-own the remaining 26 aliases + `tests/AliasOwnership.Tests.ps1`
  real-import test) — done, commit `203369a`. The file's current 3 `It` blocks
  match the plan's Task 2 content exactly.
- **Task 3** (consistency guard test — general-helper vs. tool/picker alias
  names never collide) — **not started**. `tests/AliasOwnership.Tests.ps1` has
  no `Describe 'General-helper and tool/picker alias names never collide'`
  block.
- **Task 4** (documentation) — **not started**:
  - `ToolAcquisitionSpec.md` §9 has no "9.1 Two categories" subsection.
  - `docs/external-dependencies.md:148` still has the stale "`AliasesToExport`
    is decorative" note (now only true for the dynamic tool/picker category).
  - `CHANGELOG.md` `[Unreleased]` has no `### Changed` section and no mention
    of `yank` or the ownership fix.
  - `TODO.md:19` and `TODO.md:29` still show the two original items as open
    (`[ ]`), not resolved.

This plan resumes exactly at Task 3, then does Task 4, following the existing
plan doc's task breakdown (which remains accurate — no redesign needed).

**Aside (worth fixing while touching §9):** `ToolAcquisitionSpec.md:292`
currently reads "Every new alias MUST also be added to `AliasesToExport`" in
the tool-JSON-alias section — which contradicts the two-category model about
to be documented (tool/picker aliases are intentionally *not* in
`AliasesToExport`). The original design plan's Task 4 doesn't call this line
out explicitly, but since the new 9.1 subsection is being added right after
it, this line should be corrected in the same edit to avoid shipping a
self-contradicting spec.

**Unrelated note:** `TODO.md` currently has two uncommitted, unrelated
additions (a "time command" item and a "PS Convention Compliance" item) from
outside this workstream. Task 4's `TODO.md` edit targets only the two
alias-related bullets by exact text match — the unrelated additions are left
untouched and uncommitted, as they are the user's own in-progress edit.

## Task 3: Consistency guard test

**File:** `tests/AliasOwnership.Tests.ps1` (append)

1. Append the `Describe 'General-helper and tool/picker alias names never
   collide'` block (exact content specified in the plan doc, Task 3 Step 1) —
   it builds a case-insensitive `HashSet[string]` of every `Tools/*.json`
   `aliases` key and `picker.alias` value, then asserts no
   `$script:GeneralHelperAliases` name appears in it.
2. Run `pwsh -NoProfile -Command 'Invoke-Pester tests/AliasOwnership.Tests.ps1 -Output Detailed'`
   — expect immediate PASS (locks in an invariant that already holds; not
   fixing a break).
3. Run full suite: `pwsh -NoProfile -Command 'Invoke-Pester tests/ -Output Detailed'`
   — expect PASS under Pester 5.8.0/6.0.1.
4. Commit: `git add tests/AliasOwnership.Tests.ps1` and commit message
   `test(aliases): guard against general-helper/tool-alias name collisions`.

## Task 4: Documentation

**Files:** `ToolAcquisitionSpec.md`, `docs/external-dependencies.md`,
`CHANGELOG.md`, `TODO.md`.

1. **`ToolAcquisitionSpec.md`** — insert the "9.1 Two categories, two
   ownership models" subsection after §9's existing content (before the `---`
   / `## 10.` boundary at line 294), per the plan doc's exact text. Also fix
   line 292 ("Every new alias MUST also be added to `AliasesToExport`") to
   scope that rule to general-helper aliases only, consistent with 9.1.
2. **`docs/external-dependencies.md`** — replace the `AliasesToExport is
   decorative` bullet (lines 148–152) with the corrected two-category note
   from the plan doc (Task 4 Step 2).
3. **`CHANGELOG.md`** — add a `### Changed` section to `[Unreleased]`
   (ordered after `### Added`, before `### Fixed`, per Keep-a-Changelog
   convention already used in this file) containing the `yank` rename and
   ownership-fix bullets from the plan doc (Task 4 Step 3).
4. **`TODO.md`** — replace the two open bullets (line 19 `AliasesToExport is
   decorative`, line 29 `Stop force-creating global aliases at import time`)
   with their `[x]` resolved versions per the plan doc (Task 4 Step 4). Leave
   the rest of the file (including the two unrelated uncommitted additions)
   untouched.
5. Run full suite: `pwsh -NoProfile -Command 'Invoke-Pester tests/ -Output Detailed'`
   — expect PASS (docs-only change, but confirms nothing else regressed).
6. Commit: `git add ToolAcquisitionSpec.md docs/external-dependencies.md
   CHANGELOG.md TODO.md` and commit message `docs: alias ownership
   two-category model; resolve TODO items`.

## Verification

- `pwsh -NoProfile -Command 'Invoke-Pester tests/ -Output Detailed'` passes
  with 0 failures after each task's commit.
- `git log --oneline -4` shows, top to bottom: docs commit, consistency-guard
  commit, then the two already-landed commits (`203369a`, `1e85cfa`).
- Manual spot check: `Import-Module ./DotForge.psd1 -Force; (Get-Module
  DotForge).ExportedAliases.Keys` still lists all 27 names including `yank`
  (regression check only — Task 2 already covers this in Pester).
