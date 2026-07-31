# trifle — Fast Multi-Catalog Tool Info for DotForge

## Context

DotForge configures CLI tools from a JSON registry, but answering "what is this tool, is it installed, where from, what versions exist?" today means manually running `scoop search`, `winget search`, `choco search`, etc. — each slow (winget.exe alone costs seconds of startup) and none unified. This feature adds one fast command that, given a name or keywords, searches every installer catalog and returns a summary: description, installed status + source catalog, per-catalog availability, versions (installed vs latest), homepage/license, last-updated, cache age.

Speed is the key requirement. Design is **cache-first**: answer instantly from local caches, then background-refresh so the *next* query is current.

## Decisions (locked with user)

- **Catalogs v1**: scoop, winget, choco, npm, pypi (pipx), crates (cargo), psgallery.
- **Freshness**: cache-first + background refresh; `-Fresh` blocks on live; dedicated refresh-only command for Task Scheduler.
- **Surface** (ice-cream naming theme — choco, scoop… trifle = layered dessert = layered catalogs):
  - `Find-DFPackage` — alias **`trifle`** — info card / table cmdlet
  - `Update-DFPackageCache` — scheduler entry point (`pwsh -NoProfile -Command "Import-Module DotForge; Update-DFPackageCache"`)
  - `Select-DFPackage` — alias **`ftrifle`** — fzf browser via `Invoke-DFPicker`
- **Architecture**: provider contract + hybrid cache (snapshot indexes for scoop/winget; per-query TTL caches for web APIs).
- **Alternatives / related commands**: deferred — TODO.md entry only.

## New files

### Private

- **`Private/DFCatalog.ps1`** — core plumbing: `$script:DFCatalogProviders` table (guarded init), `$script:DFCatalogOrder = @('scoop','winget','choco','npm','pypi','crates','psgallery')`, `Get-DFCatalogProvider` (filters by `-Source` + memoized availability `Test`), `Get-DFCatalogCacheRoot` (`$XDG_CACHE_HOME/dotforge/catalogs`; warn + `$null` when unset, callers degrade to live-only), `ConvertTo-DFCatalogQueryKey`, `Write-DFCatalogCacheFile` (atomic: write `.tmp.$PID` then `Move-Item -Force`), `Read-DFCatalogCacheFile` (returns `@{Data; AgeMinutes; Stale}`; envelope `{timestamp, query, results[]}`), `New-DFToolInfo`/`New-DFToolSourceInfo` constructors (PSTypeName-stamped), `Add-DFCatalogSeenQuery` (LRU-50 `seen-queries.json`), `$script:DFCatalogTtl` hashtable (test-overridable).
- **`Private/DFCatalog.Scoop.ps1`** (snapshot) — parse `buckets\<b>\bucket\*.json` directly → `catalogs/scoop/index.json`; fingerprint = per-bucket git HEAD read from `.git\HEAD` (no process spawn), fallback dir LastWriteTime. Installed: `apps\<name>\current\manifest.json`. Root resolution: `$Env:SCOOP` → `~/.config/scoop/config.json` `root_path` → `~\scoop`; `-ScoopRoot` override for tests. Never shells to scoop.
- **`Private/DFCatalog.Winget.ps1`** (snapshot) — see winget spike below.
- **`Private/DFCatalog.Choco.ps1`** — community OData `Search()?searchTerm='<q>'&$filter=IsLatestVersion&$top=15`. Installed: scan `$Env:ChocolateyInstall\lib\*\*.nuspec`.
- **`Private/DFCatalog.Npm.ps1`** — exact: `registry.npmjs.org/<name>`; keyword: `/-/v1/search?text=<q>&size=15`. Installed: enumerate `<npm-prefix>\node_modules\*/package.json` (avoids slow `npm ls -g`).
- **`Private/DFCatalog.Pypi.ps1`** — exact-name only (`pypi.org/pypi/<name>/json`, try `-`/`_` twin); PyPI has no search API — documented limitation. Installed: `pipx list --json`.
- **`Private/DFCatalog.Crates.ps1`** — `crates.io/api/v1/crates?q=<q>&per_page=15`; **must send User-Agent**. Installed: parse `~\.cargo\.crates2.json`.
- **`Private/DFCatalog.PSGallery.ps1`** — PSGallery v2 OData Search(); OData `Version` is source of truth (prerelease normalization caveat per CLAUDE.md). Installed: `Get-InstalledPSResource`, else `Get-Module -ListAvailable`.
- **`Private/Invoke-DFSqliteQuery.ps1`** — `Add-Type` P/Invoke over **`winsqlite3.dll`** (System32, Win10+, zero new deps; verified present on this machine); `SQLITE_OPEN_READONLY`; rows as PSCustomObject; `$null` + Write-Verbose on native failure.
- **`Private/Get-DFCatalogInstalled.ps1`** — unified installed snapshot (`catalogs/installed.json`, TTL 15 min) across providers + `Get-Command` on-PATH detection; builds cross-catalog identity map from `(Import-DFToolDb).Values.packages`.
- **`Private/Start-DFCatalogRefreshJob.ps1`** — single ThreadJob entry point (own function so Pester can mock it).
- **`Private/Format-DFToolInfo.ps1`** — pure renderers `Format-DFToolInfoCard` / `Format-DFToolInfoTable` with `[bool]$Color`, mirroring `Format-DFCliHelpText`.

**Provider self-registration** (load-order-proof — psm1 dot-sources alphabetically and `DFCatalog.Choco.ps1` sorts *before* `DFCatalog.ps1`):

```powershell
# tail of every Private/DFCatalog.<Provider>.ps1
if (-not $script:DFCatalogProviders) { $script:DFCatalogProviders = @{} }
$script:DFCatalogProviders['scoop'] = @{
    Name = 'scoop'; Kind = 'snapshot'
    Test         = { [bool](Get-Command scoop -ErrorAction Ignore) }
    Search       = { param($Query, $Fresh) Search-DFCatalogScoop -Query $Query -Fresh:$Fresh }
    GetInstalled = { Get-DFCatalogScoopInstalled }
    Refresh      = { param($Query) Update-DFCatalogScoopIndex }
}
```

Web registry providers default `Test = { $true }` (asking "what carries ripgrep" is useful without cargo installed); their `GetInstalled` independently no-ops when the toolchain is absent.

### Public

- **`Public/Find-DFPackage.ps1`**
  ```powershell
  function Find-DFPackage {
      [CmdletBinding()] [OutputType([PSCustomObject])]
      param(
          [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
          [string[]]$Query,                       # 'trifle static site generator' unquoted
          [ValidateSet('scoop','winget','choco','npm','pypi','crates','psgallery')]
          [string[]]$Source,
          [switch]$Fresh, [switch]$AsObject
      )
  }
  Set-Alias -Name trifle -Value Find-DFPackage -Scope Global -Force
  ```
  Flow: normalize query → read caches instantly → stale/missing query caches kick `Start-DFCatalogRefreshJob` (`-Fresh` fetches inline, `-TimeoutSec` ~10/provider) → merge via identity map → record seen-query → render. Confident single match (exactly one merged result whose canonical name or a PackageId equals query case-insensitively) → card; else table.
- **`Public/Update-DFPackageCache.ps1`** — `param([string[]]$Source, [switch]$Quiet)`. Synchronous (it IS the background): rebuild scoop index + winget extraction, refresh installed snapshot, re-fetch all `seen-queries.json` queries + exact names of installed tools. Sequential (log-friendly, gentle on choco API). Safe concurrent with interactive session via atomic writes.
- **`Public/Select-DFPackage.ps1`** — merged lines from local caches only (never live), `name<TAB>sources<TAB>description`:
  ```powershell
  Invoke-DFPicker -List { $lines }.GetNewClosure() `
      -Header 'Select package' -Delimiter "`t" -WithNth '1,3' -Ansi `
      -Parse { ($_ -split "`t")[0] } `
      -Action { param($name) Find-DFPackage -Query $name }
  Set-Alias -Name ftrifle -Value Select-DFPackage -Scope Global -Force
  ```
  No fzf preview in v1 (pwsh spawn per keystroke too slow).

### Manifest / module / docs

- `DotForge.psd1`: add 3 functions to `FunctionsToExport`, `trifle`+`ftrifle` to `AliasesToExport`.
- `DotForge.psm1`: `Update-TypeData -TypeName 'DotForge.ToolInfo' -DefaultDisplayPropertySet Name, Installed, InstalledVia, Sources, Description -Force`.
- `TODO.md`: deferred entry — "trifle: alternatives/related commands".
- README.md, examples/ (incl. Task Scheduler registration example), CHANGELOG.md `[Unreleased]`, complete comment-based help on all three public functions (verify `Get-Help -Full`).

## Object shapes

**`DotForge.ToolSourceInfo`** (per provider hit): Source, PackageId, Name, Description, LatestVersion, InstalledVersion, Installed, Homepage, License, PublishedAt, MatchKind (`exact-id|exact-name|keyword`), CacheTimestamp, CacheAgeMinutes.

**`DotForge.ToolInfo`** (merged, emitted by Find-DFPackage): Name (canonical — DF tool name when identity-mapped), Description (first non-empty in canonical source order), Installed, InstalledVia[], InstalledVersion, Sources (ToolSourceInfo[]), Latest (ordered source→version), Homepage, License, DFTool, MatchKind, CacheAge (worst across sources).

**Merging rule**: bucket by DF identity map first (any `source:packageId` found in a Tools/*.json `packages` block collapses to that tool); rest group by case-insensitive Name; remainder stay separate rows. Known false-positive risk (npm `bat` vs scoop `bat`) accepted for v1 — Sources rows keep per-catalog identity visible.

## Cache layout & TTLs

```
$XDG_CACHE_HOME/dotforge/catalogs/
├── seen-queries.json                  # LRU-50 normalized queries
├── installed.json                     # TTL 15 min
├── scoop/index.json + index.key       # fingerprint (bucket git HEADs), no TTL
├── winget/index.db + index.meta.json  # keyed on source.msix mtime+size; warn-stale 7d
└── {choco,npm,pypi,crates,psgallery}/queries/<key>.json   # TTL 24h (72h choco)
```

Stale-but-present cache is always served immediately (age shown) while a refresh re-warms — staleness never blocks. Query key: trim → lowercase → collapse whitespace; filename = sanitized 40 chars + `-` + 8-hex SHA1 of normalized query.

## Winget spike (phase 6, first task = schema dump scratch script)

- Index: `%LOCALAPPDATA%\Microsoft\WinGet\State\defaultState\Microsoft.PreIndexed.Package\Microsoft.Winget.Source_8wekyb3d8bbwe\source.msix` (verified on this machine) — MSIX is a zip containing `Public/index.db`; check for pre-extracted copy under `%LOCALAPPDATA%\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\...\Public\index.db` first, else extract via `[System.IO.Compression.ZipFile]`. Installed-via-winget: sibling `installed.db`.
- Schema branch on `SELECT majorVersion FROM metadata`: v2 = flat `packages` table (confirm columns via `PRAGMA table_info`); v1 = normalized `ids/names/monikers/versions/manifest` joins.
- Fallback chain (each rung try-wrapped, Write-Verbose): ① direct SQLite on extracted index.db (~ms) → ② `Microsoft.WinGet.Client` module (`Find-WinGetPackage`) → ③ `winget.exe search --disable-interactivity` parsed by header-column offsets, results still cached (degrades to query-cache provider).
- index.db has no description/homepage/license — leave empty; merged card fills from other catalogs. (Stretch, not required: `winget show` enrichment on `-Fresh` single match.)

## Background refresh

**`Start-ThreadJob`, not `ForEach-Object -Parallel`** (fire-and-forget needed; ThreadJob ships in pwsh 7, dies with process). Thread-safety sidestepped: workers are self-contained (receive provider/query/cacheRoot/ttl via `-ArgumentList`, pure `Invoke-RestMethod` + envelope write), communicate **only via atomic cache files**; `$script:` state never crosses threads. Job names `DotForge.Catalog.<provider>.<key>`; sweep completed/failed jobs on entry (name-prefix-filtered so user jobs untouched); dedupe in-flight by name; `-ThrottleLimit 4`. `-Fresh`: start same jobs, `Wait-Job -Timeout 15`, re-read caches; timeouts render `(timed out)` non-fatally.

## Rendering

Reuse existing **`Private/Test-DFOutputPiped.ps1`** pattern (as in `Get-DFEnv`): piped/redirected → raw objects, zero ANSI; interactive terminal → card/table strings, `$Color` gated on `NO_COLOR` + `$Host.UI.SupportsVirtualTerminal`. `-AsObject` for capture (`$x = trifle rg -AsObject`) — document in `.NOTES`. No format.ps1xml (can't express card-vs-table conditional; module has no FormatsToProcess). Card layout:

```
ripgrep — Recursively search directories for a regex pattern
────────────────────────────────────────────────────────────
Installed  ✓ scoop (14.1.1)
Sources    scoop  main/ripgrep              14.1.1
           winget BurntSushi.ripgrep.MSVC   14.1.1
           choco  ripgrep                   14.1.0
Homepage   https://github.com/BurntSushi/ripgrep
License    MIT
Updated    choco 2026-06-01 · crates 2026-05-12
Cache      scoop 3h · winget 26h · choco 12h (refreshing…)
```

Table (ambiguous): `Name  Installed  Sources  Latest  Description`, width-truncated (`$Host.UI.RawUI.WindowSize.Width`, fallback 120).

## Testing (Pester 5, tests/)

New: `DFCatalog.Core.Tests.ps1`, `DFCatalog.Scoop.Tests.ps1`, `DFCatalog.Winget.Tests.ps1`, `DFCatalog.WebProviders.Tests.ps1`, `Invoke-DFSqliteQuery.Tests.ps1`, `Get-DFCatalogInstalled.Tests.ps1`, `Find-DFPackage.Tests.ps1`, `Update-DFPackageCache.Tests.ps1`, `Select-DFPackage.Tests.ps1`, `Format-DFToolInfo.Tests.ps1`.

- Cache isolation: `$Env:XDG_CACHE_HOME = $TestDrive` per test.
- Web providers: HTTP isolated in `Invoke-DFCatalog<Provider>Fetch`; `Mock Invoke-RestMethod` with fixtures; assert normalization, envelope, crates User-Agent via `-ParameterFilter`.
- Scoop: fake root in TestDrive (bucket JSONs, `.git\HEAD`, `apps\...\manifest.json`), `-ScoopRoot` param.
- Winget: `Mock Invoke-DFSqliteQuery` to drive each fallback rung; one integration test vs fixture DB, `-Skip` when winsqlite3.dll absent.
- Refresh: `Mock Start-DFCatalogRefreshJob` — asserted called for stale, not called under `-Fresh`. No real ThreadJobs in tests.
- Rendering: `Mock Test-DFOutputPiped` both ways; formatters tested pure with `$Color` true/false.
- Picker: `Mock Invoke-DFFzf` (established pattern from Invoke-DFPicker.Tests.ps1).

## Phase order (vertical slice first)

1. Core plumbing (`DFCatalog.ps1`) + tests
2. Scoop provider (pure disk, deterministic)
3. Minimal `Find-DFPackage` scoop-only + rendering + exports — **`trifle rg` works end-to-end here**
4. Web providers: crates, npm → psgallery, choco, pypi; background refresh + `-Fresh` land with first web provider
5. Installed unification + identity map + merge upgrade
6. Winget spike → provider (schema dump script, `Invoke-DFSqliteQuery`, msix extraction, fallbacks)
7. `Update-DFPackageCache` + Task Scheduler example
8. `Select-DFPackage` (`ftrifle`)
9. Docs & release hygiene (README, examples/, CHANGELOG, TODO.md, `Get-Help -Full` checks)

## Risks

- Winget schema drift (undocumented/versioned) — mitigated by metadata-version branch + 3-rung fallback; worst case degrades to cached CLI-parse.
- `source.msix` ages if winget never runs — 7-day stale warning; decide in phase 7 whether `Update-DFPackageCache` runs `winget source update` (~5 s, scheduled context — probably yes).
- Choco API slow/rate-limited — 72 h TTL, sequential scheduled refresh, `-Fresh` may show `(timed out)`.
- Name-equality merge false positives — accepted v1; revisit with deferred alternatives feature.

## Verification

1. `Import-Module ./DotForge.psd1 -Force` then `trifle rg` → info card with scoop data; `trifle json` → table; `trifle rg | Select-Object Name, Sources` → clean objects.
2. `trifle rg -Fresh` → live versions; second plain `trifle rg` → instant, cache ages shown.
3. `Update-DFPackageCache -Quiet` from `pwsh -NoProfile` → rebuilds indexes, exit cleanly; re-run `trifle` → fresher ages.
4. `ftrifle` → fzf list, Enter → card.
5. `Invoke-Pester tests/ -Output Detailed` from `pwsh -NoProfile` — all green.
6. `Get-Help Find-DFPackage -Full` (and the other two) render all help sections.
7. `Test-ModuleManifest ./DotForge.psd1` passes with new exports.
