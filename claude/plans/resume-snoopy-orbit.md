# Package Universe — Phase A: Catalog Acquisition — Implementation Plan

## Context

Branch `feat/package-universe-phase-a` has an **Approved** design spec
(`docs/superpowers/specs/2026-07-13-package-universe-acquisition-design.md`)
for a new author-side build script that snapshots every package in scoop
(local buckets), winget, and choco into a shared SQLite database
(`raw_packages` + `pipeline_log`), as the acquisition prerequisite for a
larger future cross-catalog package-identity/merge/categorization effort.
The spec and its dependency amendment are committed; the script itself does
not exist yet. This plan implements it.

**Correction found during planning, to apply before writing the winget
parser:** the spec's Winget section describes the default-locale manifest as
an unsuffixed `<PackageIdentifier>.locale.yaml`. I verified the real
`microsoft/winget-pkgs` layout via `gh api` against
`manifests/m/Microsoft/VisualStudioCode/1.105.0/`: the files are
`Microsoft.VisualStudioCode.yaml` (the *version* manifest, holding
`DefaultLocale: en-US` and `ManifestType: version`),
`Microsoft.VisualStudioCode.installer.yaml`, and
`Microsoft.VisualStudioCode.locale.en-US.yaml` (`ManifestType: defaultLocale`).
**Every** locale file carries a BCP-47 tag, including the default one — there
is no untagged `.locale.yaml` file. An older singleton format
(`ManifestType: singleton`, one file holding everything) also exists for some
packages. Implementing against the spec's literal description would make the
winget crawl silently fall into the "no default-locale manifest found" review/
skip path for nearly everything. Fix: amend the spec's Winget section to
describe the real layout (following this branch's existing precedent of
amending the spec as new facts surface — see the PSSQLite amendment commit),
and implement the robust algorithm below.

## File List

New files:
- `build/Build-DFPackageUniverseRaw.ps1` — entry point / orchestrator.
- `build/Private/DFPackageUniverse.Db.ps1` — schema setup, truncation, parameterized writers (PSSQLite).
- `build/Private/DFPackageUniverse.Scoop.ps1` — scoop row mapping.
- `build/Private/DFPackageUniverse.Winget.ps1` — manifest-tree walk, version selection, YAML→row mapping.
- `build/Private/DFPackageUniverse.Choco.ps1` — OData entry→row mapping, paginated fetch with retry/backoff.
- `tests/Build-DFPackageUniverseRaw.Tests.ps1` — E2E + catalog-failure-isolation tests.
- `tests/DFPackageUniverse.Scoop.Tests.ps1`, `tests/DFPackageUniverse.Winget.Tests.ps1`, `tests/DFPackageUniverse.Choco.Tests.ps1` — per-catalog unit tests.

**New helpers go under `build/Private/`, not the shipped `Private/`.**
`DotForge.psm1` unconditionally dot-sources every file in `Private/*.ps1` into
every consumer's session on `Import-Module`. The spec's own Non-Goals section
says this whole effort is "author-side admin tooling... never loaded by the
module itself" — that principle should cover the new *code*, not just the two
new module dependencies. Naming mirrors the existing convention
(`DFPackageUniverse.<Catalog>.ps1` next to `DFCatalog.<Catalog>.ps1`), just
under a build-scoped directory, dot-sourced explicitly by the build script and
by tests.

Reused as-is (no changes): `Build-DFCatalogScoopIndexData`
(`Private/DFCatalog.Scoop.ps1`), `ConvertFrom-DFCatalogODataEntry`
(`Private/DFCatalog.Choco.ps1`), `New-DFDirectory`.

New build-time-only dependencies (never added to `DotForge.psd1`'s manifest,
which has no `RequiredModules` key today and must stay that way): `PSSQLite`,
`powershell-yaml`.

## Schema Setup / Truncation (`DFPackageUniverse.Db.ps1`)

```powershell
function Initialize-DFPackageUniverseDb {
    param([Parameter(Mandatory)][string]$DatabasePath)
    New-DFDirectory (Split-Path $DatabasePath -Parent)
    Invoke-SqliteQuery -DataSource $DatabasePath -Query @'
CREATE TABLE IF NOT EXISTS raw_packages ( ... UNIQUE(source, package_id) );
CREATE TABLE IF NOT EXISTS pipeline_log ( ... );
'@
    Invoke-SqliteQuery -DataSource $DatabasePath -Query 'DELETE FROM raw_packages;'
    # Only THIS stage's rows — pipeline_log is shared with future phases
    # (link/merge/categorize), whose rows must survive an acquire rerun.
    Invoke-SqliteQuery -DataSource $DatabasePath -Query "DELETE FROM pipeline_log WHERE stage = 'acquire';"
}
```

Create-if-missing must run before either `DELETE` (first-ever run has no
tables). Use one `New-SQLiteConnection` for the whole run, `-SQLiteConnection
$conn` on every call, `BEGIN TRANSACTION;`/`COMMIT;` around each catalog's
insert loop — writing tens/hundreds of thousands of winget rows one
connection-per-call otherwise will be slow. Verify PSSQLite's exact cmdlet/
parameter names against the installed version as the very first implementation
step (new dependency, nothing in-repo to confirm shape against).

## Script Params (`Build-DFPackageUniverseRaw.ps1`)

```powershell
param(
    [string]$DatabasePath = (Join-Path $PSScriptRoot '.package-universe/universe.db'),
    [string]$ScoopRoot = (Get-DFCatalogScoopRoot),
    [string]$WingetPkgsSnapshot,        # path to already-extracted tree; omit => fresh download
    [int]$ChocoPageSize = 100,
    [int]$ChocoDelayMs = 500,

    # Injectable seams — production defaults wrap the real calls, tests supply
    # canned scriptblocks (mirrors -ResolveLinkage in Build-DFToolIdentities.ps1).
    [scriptblock]$ScoopFetchItems,
    [scriptblock]$ChocoFetchPage,
    [scriptblock]$ChocoSleep
)
```

- `$ScoopFetchItems` defaults to `{ param($ScoopRoot) Build-DFCatalogScoopIndexData -ScoopRoot $ScoopRoot }`.
- `-WingetPkgsSnapshot` **is** the winget test seam — passing a fixture directory skips the download entirely; no separate scriptblock param needed for it. When omitted, the script downloads the GitHub zipball (`microsoft/winget-pkgs`, default branch) via `Invoke-WebRequest`, extracts in-process (`System.IO.Compression.ZipFile`, mirroring `Update-DFCatalogWingetIndex`'s atomic tmp-then-`Move-Item -Force` idiom), and normalizes past the zip's wrapping `winget-pkgs-<sha>/` top-level folder so callers always see `<root>/manifests/...`.
- `$ChocoFetchPage` defaults to `{ param($Skip,$Top) Invoke-RestMethod -Uri "https://community.chocolatey.org/api/v2/Packages()?`$filter=IsLatestVersion&`$top=$Top&`$skip=$Skip" -TimeoutSec 15 }`.
- `$ChocoSleep` defaults to `{ param($Milliseconds) Start-Sleep -Milliseconds $Milliseconds }` — injectable so retry/backoff tests run instantly.

Comment-based help follows the `build/Build-DFToolIdentities.ps1` convention:
`.SYNOPSIS` (states artifact + "never loaded by the DotForge module"),
`.PARAMETER` per param, one `.EXAMPLE`. No `.DESCRIPTION`/`.OUTPUTS` — that's
the exported-cmdlet convention, not the build-script one.

Availability guard, first thing the script does:
```powershell
foreach ($mod in 'PSSQLite', 'powershell-yaml') {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        throw "Build-DFPackageUniverseRaw: required build-time module '$mod' is not installed. Install it with: Install-Module $mod -Scope CurrentUser"
    }
}
Import-Module PSSQLite -ErrorAction Stop
Import-Module powershell-yaml -ErrorAction Stop
```

## Per-Catalog Logic

**Scoop** — `ConvertTo-DFPackageUniverseScoopRow` maps one
`Build-DFCatalogScoopIndexData` entry (`name, bucket, version, description,
homepage, license`) to a `raw_packages` row (`package_id = "$bucket/$name"`,
`publisher`/`tags`/`extra` null — scoop manifests don't carry these).
`Get-DFPackageUniverseScoopRows` wraps the `-ScoopFetchItems` call; per-item
`try/catch` logs `warning` and skips on a bad entry; **zero items returned
logs an `error` row itself** (the spec explicitly lists "no scoop buckets
found" as a catalog-level failure example, but `Build-DFCatalogScoopIndexData`
just returns `@()` for that case rather than throwing — the orchestrator must
detect and log it).

**Winget** — walk `<snapshot>/manifests/<letter>/...` to find package
directories (children are version folders with no further subdirectories,
handling both 2-segment and deeper dotted identifiers), pick the latest
version folder (`[version]`-parse where it parses cleanly, else ordinal
string compare), then per the corrected algorithm:
1. Find the "root" file in that version folder — matches `*.yaml`, not
   `*.installer.yaml`, not `*.locale.*.yaml`.
2. If its `ManifestType` is `singleton`, that file already has all the
   fields.
3. Otherwise, read `DefaultLocale` from it and load
   `<PackageIdentifier>.locale.<DefaultLocale>.yaml` (`ManifestType:
   defaultLocale`).
4. If neither resolves, log a `review` row and skip — per spec point 5,
   verbatim.

Parse via `powershell-yaml`'s `ConvertFrom-Yaml`, extracting `PackageName`,
`Publisher`, `ShortDescription`/`Description`, `PackageUrl`/`Homepage`,
`License`, `Tags`. A YAML parse failure on a file that does exist logs
`warning` and skips (item-level isolation) rather than `review`.

**Choco** — paginate `Packages()` with `$skip`/`$top=ChocoPageSize` until an
empty page; a page is retried up to 3x with 1s/2s/4s backoff (via the
injectable `$ChocoSleep`) before being given up on (log `error`, advance
`$skip` by `ChocoPageSize` anyway, continue — never abort the crawl); a
`$ChocoDelayMs` pause between **successful** page fetches (literal reading of
the spec's wording — not applied after a page that already spent 7s in
backoff and failed).

`ConvertTo-DFPackageUniverseChocoRow` delegates to the existing
`ConvertFrom-DFCatalogODataEntry` for id/name/description/version/homepage,
then additionally reads `Authors` → `publisher`, `Tags` → `tags` (space-split,
matching the convention in the existing `ConvertFrom-DFCatalogODataDetailEntry`),
and `LicenseUrl` → `license` directly off `entry.properties` — these fields
exist on the same NuGet v2 feed entity type already confirmed in
`tests/DFCatalogDetailProviders.OData.Tests.ps1`'s fixture, so they're free to
read off the bulk `Packages()` response without an extra request. Mapping a
URL into `license` (vs. scoop/winget's SPDX-ish strings) is an accepted
inconsistency — cheap and still useful signal, per the spec's own "whatever
metadata... each catalog can supply cheaply" framing.

## Orchestration (main script body)

```powershell
Initialize-DFPackageUniverseDb -DatabasePath $DatabasePath
$conn = New-SQLiteConnection -DataSource $DatabasePath
$logger = { param($Level,$Source,$PackageId,$Message) <INSERT INTO pipeline_log ...> }.GetNewClosure()

foreach ($catalog in 'scoop','winget','choco') {
    try {
        $rows = <call the matching Get-/Invoke-...Rows/Acquire function>
        <BEGIN TRANSACTION; write each row via a parameterized INSERT; COMMIT;>
    } catch {
        & $logger 'error' $catalog $null "catalog acquisition failed: $_"
    }
}
$conn.Close()
Write-Host "Wrote $DatabasePath"
```

A `throw` anywhere inside one catalog's fetch/convert pipeline is caught at
this top level, logged as `error`, and the loop proceeds — this is the
catalog-level isolation the spec requires and what the failure-isolation test
exercises.

## Testing (Pester 5, per spec's Testing section)

1. **Scoop unit tests** — `ConvertTo-DFPackageUniverseScoopRow` field mapping;
   `Get-DFPackageUniverseScoopRows` with a zero-item `-FetchItems` asserts the
   `error` log fires.
2. **Winget unit tests** — YAML→row mapping for both the defaultLocale and
   singleton shapes (use the real fixture content pulled above as a basis,
   not hand-authored guesses); latest-version selection across mixed
   parseable/non-parseable folder names; package-directory walk against a
   `$TestDrive` tree with both 2-segment and deeper identifiers.
3. **Choco unit tests** — row mapping (`Authors`/`Tags`/`LicenseUrl`
   enrichment) against an OData fixture entry; retry/backoff logic with a
   `-FetchPage` mock that throws N times, asserting exactly 3 retries, the
   `1000,2000,4000` delay sequence via the injected `-Sleep`, and the
   `error` log on final failure.
4. **End-to-end test** (`tests/Build-DFPackageUniverseRaw.Tests.ps1`) —
   invoke the script by path (never dot-source, per repo convention) with
   `-ScoopRoot` → a `$TestDrive` fixture bucket, `-WingetPkgsSnapshot` → a
   `$TestDrive` fixture manifest tree, `-ChocoFetchPage` → two canned pages
   then empty. Assert `raw_packages` row counts/shape per source.
5. **Catalog-failure-isolation test** (same file) — `-ScoopFetchItems { throw
   'boom' }` with valid winget/choco fixtures; assert winget+choco rows still
   land in `raw_packages` and a `stage='acquire', source='scoop',
   level='error'` row appears in `pipeline_log`.

No test hits real network, a real scoop install, or a real winget-pkgs
download.

## `.gitignore`

Add, following the existing short-header + one-path-per-line style:
```gitignore
# Package-universe build working data (regenerable, not committed)
build/.package-universe/
```

## Build Order

1. Amend the design spec's Winget section for the real manifest-naming
   convention (see Context above).
2. `build/Private/DFPackageUniverse.Db.ps1` — confirm PSSQLite's actual
   `New-SQLiteConnection`/`-SqlParameters`/`-SQLiteConnection` API against the
   installed module version before trusting this plan's exact call shapes.
3. `build/Private/DFPackageUniverse.Scoop.ps1` + unit tests (simplest catalog,
   validates the harness pattern first).
4. `build/Private/DFPackageUniverse.Choco.ps1` + unit tests (retry/backoff is
   self-contained).
5. `build/Private/DFPackageUniverse.Winget.ps1` + unit tests (uses the
   corrected manifest algorithm; build fixtures from the real samples
   fetched via `gh api` during planning).
6. `build/Build-DFPackageUniverseRaw.ps1` — orchestration, availability guard,
   comment-based help.
7. `tests/Build-DFPackageUniverseRaw.Tests.ps1` — E2E + failure isolation.
8. `.gitignore` addition.
9. Manual smoke run: `-WingetPkgsSnapshot` pointed at a small local fixture
   first (avoid an hours-long full download during iteration), then against
   a real local scoop install, before attempting a full winget-pkgs run.

## Verification

- `Invoke-Pester tests/DFPackageUniverse.Scoop.Tests.ps1,tests/DFPackageUniverse.Winget.Tests.ps1,tests/DFPackageUniverse.Choco.Tests.ps1,tests/Build-DFPackageUniverseRaw.Tests.ps1 -Output Detailed` (run from `pwsh -NoProfile`).
- Full suite: `Invoke-Pester tests/ -Output Detailed` to confirm no regressions.
- Manual run: `./build/Build-DFPackageUniverseRaw.ps1 -WingetPkgsSnapshot <small-fixture-dir>` against a real local scoop install; inspect `build/.package-universe/universe.db` via `Invoke-SqliteQuery`/PSSQLite directly (row counts per source, spot-check a few rows, check `pipeline_log` for expected `review`/`warning` rows).
- Confirm `git status` shows `build/.package-universe/` is ignored (not staged) after a run.
