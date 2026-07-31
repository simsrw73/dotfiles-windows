# Plan — Package Universe Phase B: Full-Fidelity Capture + Identity Clustering

## Context

DotForge is building a cross-catalog package index. **Phase A** (committed) acquired 30,251 raw
packages from scoop (5,286), choco (11,202), and winget (13,763) into `build/.package-universe/universe.db`
(`raw_packages`, `UNIQUE(source, package_id)`, verified 0 empty ids / 30,251 distinct keys). This plan
covers the next step, split into two stages because a decision this session — *capture every field from
every source* — is a prerequisite for good clustering and is really acquisition work.

**Why now / outcome:** the curated `Tools/*.json` layer only links 28 tools. We want that cross-catalog
identity linking generalized to the whole universe, with a **confidence score per link**, a
**human-review loop**, and a **durable curation layer** so verified verdicts harden the clusters over
successive runs. Later phases (metadata merge, categorization) build on this cluster graph.

### Decisions locked this session (do not re-litigate)
- **Scope:** offline clustering of scoop+winget+choco only. External cross-refs (npm/crates/pypi/
  psgallery/gem) **deferred to a later spec** (Phase B-ext).
- **Capture everything:** every source field stored (manual review + unknown future use), not just repo signal.
- **Link model:** pairwise evidence edges → clusters computed by union-find.
- **Version is never part of an identity key** (measured: same tool shows `zoxide` 0.10.0/0.9.2,
  `Servy` 8.6/8.6.0, `WinPaletter` 1.0.9.8/1.0.98 across catalogs).
- **Name-only tier is review-only**, never cluster-forming.
- **Curation store:** version-controlled file (source of truth) **plus** a mirrored DB table.

### Evidence gathered this session (measured against the live DB)
| Signal | Multi-source groups | Notes |
|---|---|---|
| GitHub `owner/repo` agreement (≥2 sources) | 909 | 196 tri-catalog, 679 dual; path-based, safe |
| `publisher`+`name` agree **and** share a repo | 345 | corroborated |
| `publisher`+`name` agree, no repo to check | 756 | recall gain (winget↔choco; **scoop has no publisher**) |
| `publisher`+`name` agree, repos differ | 9 | ~0.1% — mostly repo-moves/forks → review |
| **name-only** new linkage beyond above | 2,817 | **2,778 bridge scoop↔other** (only way to reach scoop by name) |
| ‣ of which repo-corroborated / conflict / unverifiable | 643 / 94 / 2,080 | conflicts = true collisions (`air`,`cemu`,`chatgpt`) + forks |

Union (repo + publisher+name) covers 4,339 rows (14.3%); name-only would add the scoop reach but as
**review candidates only**. Bare-**host** matching is unsafe (`www.nirsoft.net` = 636 distinct tools —
`trifle zed` at scale); full-**path** `owner/repo` and normalized full-URL homepage are safe.

---

## Stage 0 — Acquisition enrichment ("capture everything")

Amend the Phase A build to serialize the **complete source-native field set** of every package into the
`extra` column (currently hard-coded `$null`). Typed columns stay for convenience; `extra` becomes the
full JSON bag. All offline **except the choco re-walk** (user-authorized).

- **choco** (`build/Private/DFPackageUniverse.Choco.ps1`): read the full `<m:properties>` bag from each
  walk entry (verified same element as the detail path — `DFCatalog.Choco.ps1:156` reads `$props` exactly
  as the walk mapper `:38` does) + the Atom-remapped four (`Id`→`<title>`, `Authors`→`<author><name>`,
  `LastUpdated`→`<updated>`, `Summary`). Newly captured: `ProjectSourceUrl` (real repo URL),
  `PackageSourceUrl`, `DocsUrl`, `BugTrackerUrl`, `MailingListUrl`, `IconUrl`, `ReleaseNotes`, `Copyright`,
  `DownloadCount`, `Dependencies`, `Published`. **Free re-walk (~281 req, ~21 min)** — confirm against
  **one live walk page** first (code carries a "verify against live" note).
- **winget** (`build/Private/DFPackageUniverse.Winget.ps1`): read whole default-locale + version manifest.
  Newly captured: `PublisherUrl`, `PublisherSupportUrl`, `ReleaseNotesUrl`, `ReleaseNotes`,
  `Documentations`, `Moniker`, `Author`, `Copyright`/`CopyrightUrl`, `LicenseUrl`, `PrivacyUrl`,
  `PurchaseUrl`. **Fully offline** from snapshot. (No repo-URL field exists in winget manifests.)
- **scoop** (discard point `Private/DFCatalog.Scoop.ps1` `Build-DFCatalogScoopIndexData` +
  `build/Private/DFPackageUniverse.Scoop.ps1`): capture whole manifest. Newly captured, high-value:
  **`checkver` / `autoupdate`** (frequently name the GitHub repo when `homepage` is a vanity domain),
  `bin`, `architecture`/`url`, `depends`, `suggest`, `notes`. **Fully offline** from local buckets.

`New-DFToolSourceDetail` (`DFCatalog.ps1:337`) already models `RepositoryUrl`/`DocsUrl`/`ReleaseNotes`/
`Downloads`/`Dependencies`/`Extra` — align the `extra` JSON key vocabulary to it.

**Re-run:** `./build/Build-DFPackageUniverseRaw.ps1 -WingetPkgsSnapshot ./build/.package-universe/winget-pkgs`
(user triggers — outward-facing choco crawl).

---

## Stage 1 — Identity clustering (`Build-DFPackageUniverseLinks.ps1`)

New build script; opens the same `universe.db`, adds tables, `stage='link'` in `pipeline_log`.
Independently runnable/testable, mirroring the Phase A script.

### Schema
```sql
CREATE TABLE identity_links (           -- evidence graph (pairwise); rebuilt each run
  id INTEGER PRIMARY KEY,
  source_a TEXT NOT NULL, package_id_a TEXT NOT NULL,
  source_b TEXT NOT NULL, package_id_b TEXT NOT NULL,
  method TEXT NOT NULL,      -- 'curated' | 'repo' | 'homepage' | 'publisher-name' | 'name-only' | 'conflict'
  confidence REAL NOT NULL,  -- 0.0..1.0
  evidence TEXT,             -- JSON: matched key (repo string / normalized homepage / pub|name / name)
  linked_at TEXT NOT NULL,
  UNIQUE(source_a, package_id_a, source_b, package_id_b, method)
);
CREATE TABLE identity_clusters (        -- union-find components over cluster-forming edges
  cluster_id INTEGER PRIMARY KEY,
  size INTEGER NOT NULL,
  methods TEXT NOT NULL,        -- JSON array of methods present
  min_confidence REAL NOT NULL, -- weakest edge holding the cluster together
  has_curated INTEGER NOT NULL, -- 1 if a curated merge seeded it
  needs_review INTEGER NOT NULL,-- 1 if a conflict/skipped edge touches it
  created_at TEXT NOT NULL
);
CREATE TABLE cluster_members (
  cluster_id INTEGER NOT NULL,
  source TEXT NOT NULL, package_id TEXT NOT NULL,
  join_method TEXT NOT NULL, join_confidence REAL NOT NULL,
  PRIMARY KEY(source, package_id)   -- each package in at most one cluster
);
CREATE TABLE curated_links (            -- runtime MIRROR of the curation file (source of truth is the file)
  kind TEXT NOT NULL,          -- 'same' | 'different'
  group_id TEXT,               -- for 'same': the curated cluster label
  source TEXT NOT NULL, package_id TEXT NOT NULL,
  note TEXT
);
```
Truncation follows Phase A discipline: each run clears its own rows (all four tables + `pipeline_log
WHERE stage='link'`) then rebuilds. Clusters are a **reproducible view** over edges — never hand-edited.

### Signal derivation (reuse existing helpers verbatim; read `homepage` **and** enriched `extra`)
- **repo** — GitHub `owner/repo` via `Resolve-DFGitHubRepoUrl`'s regex
  `github\.com[/:]([^/]+)/([^/#?\s]+)` + strip `.git` + lowercase (`Private/Get-DFGitHubRepoInfo.ps1:61`).
  Priority: choco `ProjectSourceUrl` → scoop `checkver`/`autoupdate` github ref → any `homepage` that is github.
- **homepage** — normalized non-github homepage via `ConvertTo-DFNormalizedHomepage`
  (`Private/Resolve-DFToolIdentityCandidateRepo.ps1:3`). Path preserved; **bare-domain-only matches → review**, not an edge.
- **publisher-name** — `(NormPub(publisher), Norm(name))`; `Norm`=lowercase+strip non-alnum,
  `NormPub` also strips corporate suffixes. (Cannot reach scoop — scoop publisher is always NULL.)
- **name-only** — `Norm(name)`, **gated to length ≥ 4** to drop `ado`/`air`-class collisions.

### Edge construction & confidence
Group by each key; emit a cross-source pairwise edge per pair in a group:
| method | when | confidence | cluster-forming? |
|---|---|---|---|
| `curated` (same) | in the curation file's confirmed-same group | 1.0 | **yes (seeded first)** |
| `repo` | share github owner/repo | 1.0 | yes |
| `homepage` | share normalized homepage **with a path** | 0.75 | yes |
| `publisher-name` | share pub+name, no repo conflict | 0.60 | yes (≥ threshold) |
| `conflict` | share pub+name **or** name-only but repos differ | 0.30 | no → review |
| `name-only` | share name (len≥4), not otherwise linked | 0.20 | **no → review** |

### Clustering (constrained union-find)
1. **Seed** with curated confirmed-same groups (force-union, method='curated').
2. Apply automatic edges in **descending confidence**, unioning components — but **skip any union that
   would violate a curation `different` (cannot-link) pair** (the permanent `air`/`cemu`/`chatgpt` splits);
   a skipped edge logs a `review` row.
3. Only edges with `confidence ≥ THRESHOLD` (default **0.60**, parameterized) union. `name-only` (0.20)
   and `conflict` (0.30) never union — they remain in `identity_links` as review candidates.
4. Materialize `identity_clusters` + `cluster_members`; set `needs_review`/`has_curated` accordingly.

### Curation & review loop (the durable human layer)
- **Source of truth: `data/package-universe-curation.jsonc`** (version-controlled, survives DB rebuilds,
  code-reviewable — mirrors the existing `data/tool-identities.json` / `build/identities/*.jsonc` prior art).
  Holds `same` groups (verified identical → force-merge) and `different` pairs (verified distinct →
  cannot-link). Keyed by durable `(source, package_id)`.
- Each run loads it, applies it (above), and **mirrors** it into the `curated_links` table for querying.
- **Review candidates** (`name-only` + `conflict` + skipped edges) are written to `pipeline_log`
  (`stage='link'`, `level='review'`), conflict-flagged first, so a human can work the queue and record
  verdicts back into the curation file. Next run applies them → queue shrinks to only-new. This is the
  review→verify→re-run loop.

### Officialness (noted; not built here)
The "official vs third-party / preferred installer" signal is **derivable offline** by comparing a
member's publisher/id-owner to its cluster's canonical repo owner (e.g. winget `ajeetdsouza.zoxide` =
official; a community-maintained choco `zoxide` = third-party). Stage 0's full-capture **already
preserves every input** (choco `Authors`, winget `Publisher`/`PackageIdentifier`, repo owner), so this is
a cheap **Phase C** computation — inputs captured now, derivation deferred. README/repo mining for
install commands is **rejected**: chicken-and-egg (needs the repo you'd already have) + unstructured.

---

## Strict-mode & testing (hard-won; apply directly)
- Both scripts call `Set-StrictMode -Version Latest`; **never `-Off`**. Enrichment reads many
  optional/absent fields → `Get-DFXmlMember`/`Get-DFXmlText` for XML, `$hash['Key']` for dicts, wrap whole
  pipelines `@(x | Where-Object {...})`, avoid `.GetNewClosure()` where script-scope funcs are needed,
  filter empty feeds `@(... | Where-Object { $_ })`.
- **Tests must call `Set-StrictMode -Version Latest` themselves** (Pester doesn't; this gap cost 4,734 rows).
- **Fixtures must include the sparse/minimal shape**, not just the rich one. Pester 5: no `<angle brackets>` in test names.
- **Ground-truth eval:** assert precision/recall against the 28 curated `Tools/*.json` `packages` blocks
  (e.g. `bat` = scoop `bat` + winget `sharkdp.bat` + choco `bat` → one cluster). Regression guard vs `trifle zed`.
- **Curation tests:** a confirmed-same forces a merge; a confirmed-different blocks an otherwise-valid
  auto-edge (`air`); the file round-trips into `curated_links`.
- Injectable seams for choco fetch (`-ChocoFetchPage`/`$Sleep`) and offline scoop/winget inputs — no network in tests.
- **Reconciliation:** log population-vs-emitted counts (rows in / edges by method / clusters / members /
  review count); a systematic pattern of item-level failures is a run-level failure.

## Verification (end-to-end, evidence before assertions)
1. Full Pester suite from `pwsh -NoProfile` (baseline 622 passing; Clipboard test flaky — re-run once).
2. Stage 0: after the re-walk, `SELECT source, COUNT(*), SUM(extra IS NOT NULL) FROM raw_packages GROUP BY
   source`; spot-check `extra` holds `ProjectSourceUrl`/`checkver`/etc.; reconcile ≈30,251 (a drop = strict regression).
3. Stage 1: 28 curated tools each land in one correct cluster; conflicts (`air`,`cemu`) are `needs_review`,
   not merged; a seeded curation `different` pair stays split; sanity-check cluster/member counts and the review-queue size.

## Files
- **Modify:** `build/Private/DFPackageUniverse.{Choco,Winget,Scoop}.ps1`, `Private/DFCatalog.Scoop.ps1`,
  `build/Build-DFPackageUniverseRaw.ps1` (wire enriched `extra`).
- **Create:** `build/Build-DFPackageUniverseLinks.ps1`, `build/Private/DFPackageUniverse.Links.ps1`
  (derivation/edges/constrained union-find/curation loader), `data/package-universe-curation.jsonc`
  (seed empty/with the known collisions), and `tests/` counterparts.
- **Spec:** first execution step — write this design as
  `docs/superpowers/specs/2026-07-16-package-universe-identity-clustering-design.md` (Phase-A spec's
  record-the-*why* style) and commit before coding.
- **Docs:** update `CHANGELOG.md` `[Unreleased]`; build-only, no public module surface change.

## Sequencing
Stage 0 (enrichment) → re-run acquisition → Stage 1 (clustering + curation loop). Each stage is TDD,
independently testable and verifiable. Do not push/PR without asking (branch 3 commits ahead of `main`,
no PR). Leave the unrelated uncommitted `TODO.md` change alone.
