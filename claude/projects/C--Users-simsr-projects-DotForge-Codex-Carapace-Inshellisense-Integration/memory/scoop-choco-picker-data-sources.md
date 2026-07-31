---
name: scoop-choco-picker-data-sources
description: Data sources behind the scoop/choco fuzzy pickers (built, mirrors winget)
metadata: 
  node_type: memory
  type: reference
  originSessionId: 704083cb-5119-492b-9153-15bfd4aa4f33
  modified: 2026-07-23T20:28:07.155Z
---

BUILT: `Tools/scoop.ps1` (sins/srm/sup) and `Tools/choco.json`+`Tools/choco.ps1`
(cins/crm/cup) mirror the winget pickers on the same extended `Invoke-DFPicker` seam
([[prefer-object-modules-over-cli-parsing]]). This note records their data sources.

**scoop → the `Scoop` module** (Thomas Nieto, v0.3.1 Mar 2025, PSGallery; installed
CurrentUser on this machine). Clean objects, richer than winget:
- `Find-ScoopApp -Name <q>` → `{Name, Version, Source, Description, Homepage, Binaries}`
- `Get-ScoopApp` (installed) → `{Name, Version, Source, Updated, Info}`
- `Install-/Uninstall-/Update-ScoopApp -Name` (+ `-Global`, `-WhatIf/-Confirm`)
- Gap: NO outdated/status cmdlet → update picker lists all installed (Get-ScoopApp,
  multi-select) or falls back to `scoop status` (a table). Prefer list-all-installed.
- New documented dependency, like Microsoft.WinGet.Client. No name collision:
  Select-/Remove-/Invoke-* picker names vs Find-/Get-/*-ScoopApp cmdlets.

**choco → no usable module** (PoshChoco is v0.1.0/2020, only Get-ChocoPackage; other
Chocolatey-* gallery modules are unrelated deploy tooling). Use choco CLI's
machine-readable `-r`/`--limit-output` (pipe-delimited, NOT table-scraped):
- `choco search <q> -r` → `name|version`
- `choco list -r` (installed) → `name|version`
- `choco outdated -r` → `name|current|available|pinned`
- Parse = `-split '\|'`; no ConvertFrom-DFTable needed.
- Actions: `choco install/uninstall/upgrade <id> -y` (and `choco upgrade all -y`).
  Note: choco install/uninstall/upgrade need ELEVATION (unlike scoop/winget user scope).

Existing: `Tools/scoop.ps1` already holds the scoop-search init hook — extend it, don't
replace. No `Tools/choco.json`/`choco.ps1` yet — create them.

Nuance (user): native scoop now emits PS objects (`scoop list` returns objects), but
`scoop search` is intercepted by the scoop-search hook and returns plain TEXT — that
hook, not scoop, is why search isn't object-based. Possible future simplification: read
installed apps from native `scoop list` objects and drop the Scoop-module dependency for
srm/sup, keeping scoop-search only for the fast search picker.

Gotcha when adding any new `Tools/<name>.json`: `tests/Build-DFCategoryDb.Tests.ps1`
requires a matching entry under `.tools` in `data/tool-categories.json`. Add the tool
to `build/categories/dotforge-curated.jsonc`, then regenerate with
`./build/Build-DFCategoryDb.ps1` (don't hand-edit the generated data file).

