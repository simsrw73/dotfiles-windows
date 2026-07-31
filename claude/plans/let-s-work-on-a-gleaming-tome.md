# Plan: Rich package-manager pickers (winget first, scoop/choco-ready)

## Context

DotForge already ships a *basic* winget picker (`Tools/winget.ps1`): `wins`
(search → install) and `wrm` (list → uninstall). Both hide the preview and
execute winget immediately, and column parsing is a fragile
`($_ -split '\s{2,}')[1]`.

We want a richer, reusable picker set:

- **Search/install** picker (optional query) with a live `winget show <id>`
  **preview**, that **returns the install command by default** and runs it on a
  keypress.
- **Uninstall** picker over installed apps (with preview).
- **Update** picker over upgradable apps, **multi-select**, plus an
  "upgrade everything" key.
- Support **acting on items two ways**: multi-key (`--expect` — pick a key,
  fzf exits, PowerShell runs the action cleanly with proper UAC/output) **and**
  act-in-place (`--bind …:execute(...)` — hit a key, it runs while you stay in
  the list and keep browsing).

`Invoke-DFPicker` supports preview/multi today but has **no `--expect`/`--bind`
passthrough**, so it must be extended. The whole thing is built as a reusable
pattern so **scoop and choco** pickers become quick mirrors afterward (the
user's stated follow-up).

### Data source: the `Microsoft.WinGet.Client` module (not CLI parsing)

`Microsoft.WinGet.Client` is **installed and current** (v1.29.280, matches the
winget CLI and the PSGallery latest). It returns real objects, so we skip the
fragile table parsing entirely:

- `Find-WinGetPackage [query]` → `{Name, Id, Version, Source, IsUpdateAvailable}`
  — the search/install list.
- `Get-WinGetPackage` → `{Name, Id, InstalledVersion, IsUpdateAvailable,
  AvailableVersions, Source}` — the uninstall list; filter `IsUpdateAvailable`
  for the update list.
- `Install-WinGetPackage` / `Uninstall-WinGetPackage` / `Update-WinGetPackage`
  (`-Id … -MatchOption Equals`) — the programmatic actions.

Split by execution context:
- **List + `--expect` key actions** run back in PowerShell → **module cmdlets**.
- **Preview** and the **in-place `--bind execute` action** run in fzf's **cmd
  subshell**, which can't call cmdlets → **`winget` CLI**, display/subshell only:
  `winget show --id {2}`, `winget install --id {2} --exact`. No parsing either way.
- The **returned "install command"** is the CLI string
  `winget install --id <id> --exact` (portable/copy-pasteable; swap to the
  `Install-WinGetPackage -Id` cmdlet form if preferred).

Consequence: **no `ConvertFrom-DFTable` is built in this pass.** scoop/choco have
no equivalent object module, so they'll add their own parsing when built — not
speculatively now.

## Design decisions (confirmed with user)

- Action model: **Both** `--expect` and `--bind execute`.
- Install picker: **Enter returns the command string**, a key runs it.
- Scope this pass: **winget only**, structured so scoop/choco follow-ups mirror it.
- Uninstall/update Enter = act now (their whole purpose), with a key to return
  the command instead — mirror of the install picker's default, inverted.

## Keymaps (keys chosen to avoid fzf defaults; use `alt-*`, which fzf leaves free)

| Picker | Enter | Other keys |
|---|---|---|
| `wins` search/install | **return** `winget install --id <id> --exact` | `alt-r` run install (exit) · `alt-i` install highlighted **in place**, keep browsing (`--bind execute`) |
| `wrm` uninstall | **uninstall** selected (exit) | `alt-x` uninstall **in place** (`--bind execute`) · `alt-c` return the uninstall command |
| `wup` update | **upgrade** marked selection(s) | `Tab` mark (multi) · `alt-a` `winget upgrade --all` |

All previews: `winget show --id <id>` in a `right:60%` window.

## Changes

### 1. Extend `Invoke-DFPicker` — `Public/Invoke-DFPicker.ps1`

Add three **backward-compatible** parameters (existing callers and the
declarative generator pass none of them, so behavior is unchanged):

- `[string[]]$Expect` → emits `--expect <comma-joined>`.
- `[string[]]$Bind` → emits one `--bind <spec>` per entry.
- `[string[]]$FzfArgs` → verbatim passthrough (appended last; general escape
  hatch — `Invoke-DFFzf` already forwards an arbitrary `string[]`).

Return-shape rule:
- **Without `-Expect`**: unchanged (parsed string(s), or `-Action` side-effect).
- **With `-Expect`**: fzf prints the pressed key as the first output line, then
  the selection(s). Return a single object
  `[pscustomobject]@{ Key = <key or ''>; Selected = @(<parsed items>) }` and do
  **not** invoke `-Action` (the caller branches on `.Key`). Cancel (Esc → empty
  output) still returns nothing. Guard: in expect mode the first line is the key
  even when empty (Enter), so distinguish "cancelled" (empty array) from
  "Enter pressed" (array length ≥ 1 with a key line).

Update comment-based help: document `-Expect`/`-Bind`/`-FzfArgs`, the new return
object, and add an `.EXAMPLE` using `-Expect`.

### 2. Rewrite `Tools/winget.ps1` (keep `winget.json` `"picker": "custom"`)

Three `global:` functions + aliases (runtime-registered, **no `.psd1` entry** —
matches existing `wins`/`wrm`):

- `Select-WingetPackage` / `wins [query]` — search/install.
- `Remove-WingetPackage` / `wrm` — uninstall.
- `Update-WingetPackage` / `wup` — update (multi-select). `Update` is an
  approved verb.

Module guard: each function checks `Get-Module -ListAvailable
Microsoft.WinGet.Client`; if absent, `Write-Warning` with install guidance
(`Install-Module Microsoft.WinGet.Client`) and return. Documented dependency, so
a clear warning (not silent) is right. Import lazily inside the functions.

Shared shape per picker:
- `-List`: call the module cmdlet (`Find-WinGetPackage $Query` /
  `Get-WinGetPackage` / `Get-WinGetPackage | Where IsUpdateAvailable`), then emit
  a **tab-delimited** display line from object properties:
  `"{0,-40} {1,-30} {2}`t{Id}"` — a padded `Name  Id  Version` display column,
  a tab, then the bare `$_.Id`.
- `-Delimiter "`t"`, `-WithNth '1'` (show only the display column), preview
  `winget show --id {2}` (field 2 = bare id; CLI, display-only),
  `-Parse { ($_ -split "`t")[1] }` to recover the id.
- `-Expect` for the exit-and-run keys → branch on the returned `.Key` and run the
  **module cmdlet** (`Install-WinGetPackage -Id $id -MatchOption Equals`, etc.);
  `-Bind` for the in-place `execute(...)` keys using the **CLI** (e.g.
  `alt-i:execute(winget install --id {2} --exact)`).
- Default (Enter) on `wins` returns the CLI string; `wrm`/`wup` Enter act now.

Keep `wins`'s `Read-Host` fallback when no query is given.

### 3. Tests

- `tests/Invoke-DFPicker.Tests.ps1` (extend): mock `Invoke-DFFzf` to assert
  `--expect`/`--bind`/`FzfArgs` reach the arg list; assert the `{Key, Selected}`
  object shape in expect mode and unchanged behavior without it.
- `tests/winget.Tests.ps1` (new): model on `tests/scoop.Tests.ps1` — set
  `$script:CompanionPath` to `../Tools/winget.ps1`, dot-source it, assert
  `wins`/`wrm`/`wup` + `Select-/Remove-/Update-WingetPackage` resolve as **global**
  functions *after* an inner-function scope (reproducing `Register-DFTool`), mock
  the module cmdlets (`function global:Find-WinGetPackage { … }` returning fake
  objects) to verify list formatting/`Id` extraction, and cover the
  module-absent warning path. Clean up globals in `AfterEach`.

### 4. Docs

- `README.md`: document `wins`/`wrm`/`wup`, the keymaps, the
  `Microsoft.WinGet.Client` requirement, and `Invoke-DFPicker`'s new
  `-Expect`/`-Bind`/`-FzfArgs`.
- `examples/`: add a winget-picker usage snippet.
- `CHANGELOG.md`: add the change under `[Unreleased]`.
- Comment-based help on `Invoke-DFPicker` (the only changed **public** function),
  verified with `Get-Help -Full`. (winget sidecar functions are global runtime
  functions, not exported module cmdlets — no `.psd1` change.)

## Reusability note (scoop/choco follow-up, not built now)

The reusable seam is the **extended `Invoke-DFPicker`** + the **picker structure**
(list → tab-format → `winget show` preview → expect/bind → action), not a parser.
Later `Tools/scoop.ps1` picker set and new `Tools/choco.json`/`choco.ps1` mirror
the structure; because scoop/choco have no object module, they'll add their own
lightweight output parsing at that point (a `ConvertFrom-DFTable`-style helper can
be introduced then if the parsing repeats).

## Verification (end-to-end)

1. `Import-Module ./DotForge.psd1 -Force` then `Register-DFTool winget`.
2. Unit tests (from `pwsh -NoProfile`):
   `Invoke-Pester tests/Invoke-DFPicker.Tests.ps1, tests/winget.Tests.ps1 -Output Detailed`.
3. Manual smoke:
   - `wins ripgrep` → preview shows `winget show`; **Enter prints**
     `winget install --id BurntSushi.ripgrep.MSVC --exact`; `alt-r` runs it;
     `alt-i` installs the highlighted app and **returns to the list**.
   - `wrm` → preview + Enter uninstalls (or `alt-c` returns the command).
   - `wup` → `Tab` marks several, Enter upgrades them; `alt-a` runs
     `winget upgrade --all`.
4. `Get-Help Invoke-DFPicker -Full` renders all sections.
5. Full suite: `Invoke-Pester tests/ -Output Detailed` — green.
