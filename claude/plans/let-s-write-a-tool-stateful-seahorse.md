# Plan: Write the Tool Acquisition & Integration Standard

## Context

`ToolAcquisitionSpec.md` at the repo root is currently a **goals brief** — a raw dump of what tool
integration into DotForge should accomplish. The user wants it turned into a **normative,
unambiguously-followable standard**: a document that, for any new CLI tool, tells us exactly how to
make it XDG-compliant with minimum pollution, prove the config is actually honored, add required
config/theme/completion/pickers/aliases, and decide defaults among equivalent tools.

Exploration (three parallel Explore agents) established that **most of the machinery already exists**
and the spec must codify it rather than reinvent it:

- **XDG ladder already built**: `Public/Register-DFTool.ps1` dispatches on `xdg.method`
  (`default|env|config|wrapper|manual`); tools record `xdg.compliance` (`full|partial|none`).
- **Theme resolver already built**: `Private/Get-DFConfiguredTheme.ps1` (chain: per-tool key →
  shared `DFConfig.Theme` → default). Family→dialect mapping is currently **decentralized** in each
  sidecar — a deliberate, documented choice this spec will override.
- **Completion stack**: `Private/Initialize-DFCompletionStack.ps1`; carapace Native path works;
  bundled carapace specs live in `Tools/carapace/specs/` (only `mdv`, `scoop` so far);
  inshellisense is a stub; Codex is unbuilt.
- **Aliases & pickers**: declarative in `Tools/*.json` (`aliases`, `picker`), built by
  `Register-DFTool`.
- **Metadata/trifle**: large existing pipeline (`build/Build-DFToolIdentities.ps1`,
  `build/Build-DFCategoryDb.ps1`, `data/tool-categories.json`, package-universe SQLite pipeline)
  with its own specs under `docs/superpowers/specs/`.
- **Two genuine gaps**: (1) NO automated conformance verification — today it's hand-written prose in
  `docs/external-dependencies.md`; (2) NO automatic default-tool "winner" selection — only manual
  `$DFConfig.SkipTools`.

## Resolved decisions (from user)

1. **Conformance**: author-time / build-time only, never shipped or run in the live shell.
   Automate probes where possible; record manual verdicts where not. Failures feed an issue-report
   artifact; adapters link back to failure IDs so fixes upstream make dead adapter code detectable.
2. **Theme translation**: **central data-file table** (`data/theme-aliases.json`) — canonical name ↔
   per-tool name + accepted aliases; accept either; sidecars shrink to validating against the tool's
   built-in list. Overrides the current decentralized approach.
3. **Default tool**: **`$DFConfig` declaration** (e.g. `Defaults = @{ listing='eza'; pager='bat' }`);
   equivalence groups drawn from the category taxonomy's `function` field; winner gets standard
   aliases; losing group members auto-skipped. No startup prompt.
4. **Deliverable**: a **standalone standard at repo-root `ToolAcquisitionSpec.md`** (outside the
   dated `docs/superpowers/specs/` convention). Package-manager *metadata consolidation* is deferred
   to the existing trifle/universe specs (referenced, not re-specified).

## Deliverable

Rewrite `ToolAcquisitionSpec.md` (repo root) from goals-brief into a normative standard with these
sections:

1. **Purpose & Scope** — governs onboarding a tool into DotForge; links out to trifle/universe
   specs for package-metadata work.
2. **Principles** — minimum pollution; don't trust docs, verify; degrade silently / never fail
   (existing house rule); idempotent; XDG-first.
3. **The XDG Integration Ladder** (normative priority order), formalizing the existing five methods:
   `default` (XDG-native, record `compliance:full`) → `env` → `config` (prefer writing state/data/
   cache *paths into the config file* over env vars when the tool supports it) → `wrapper` (flag
   passed via wrapper function + user args) → `manual` (warn; nothing automatable). Cite
   `Register-DFTool.ps1` dispatch and `Expand-DFXdgPath` templating.
4. **Conformance Protocol** (the new core) — per tool, per *claim* (honors env var X / reads config /
   honors specific content / honors XDG / honors flag): probe. Automatable probes → harness
   (`build/Test-DFToolConformance.ps1`, injectable seams per test conventions); non-automatable →
   manual verdict + re-test instructions. Results in a machine-readable ledger keyed by
   **tool + version tested** (a superset of `docs/external-dependencies.md`). Failures →
   auto-generated issue-report artifact. **Adapters link to a conformance-failure ID** so a later
   passing re-probe flags removable adapter code.
5. **Required Configuration** — pagers/viewers/editors should honor `PAGER`/`EDITOR`/`VISUAL`;
   verify; else configure per ladder. DotForge sets sensible defaults **only when unset**, never
   clobbering user values. (Note the existing `$Env:Pager` vs docs `$Env:PAGER` casing inconsistency.)
6. **Theme** — central `data/theme-aliases.json`; shared `DFConfig.Theme` + per-tool overrides via
   `Get-DFConfiguredTheme`; accept canonical or tool-native names; acquire/create catppuccin-mocha
   per tool via the ladder; sidecars validate against built-in list only.
7. **Completion** — if carapace + inshellisense already cover it, nothing to do; else tool-provided
   if it doesn't conflict; else bundle a carapace spec in `Tools/carapace/specs/`. Cite
   `Initialize-DFCompletionStack`.
8. **Pickers** — case-by-case; declarative `picker` object vs `"custom"` sidecar; note where a
   previewer is genuinely useful.
9. **Aliases** — paging alias for verbose tools; short aliases for pickers; well-known conventional
   aliases; standard aliases (`ls`/`ll`/`tree`) route to the default-tool winner.
10. **Default Tool Selection** — `$DFConfig.Defaults` declaration; equivalence via category
    `function`; winner takes standard aliases; losers auto-skipped; interaction with the
    coreutils-shadow conflict detector (`Get-DFCommandConflict`).
11. **Package Managers** — special tools configured per ladder; object-module data sources
    (`Microsoft.WinGet.Client`, `Scoop` module, choco `-r`); metadata consolidation deferred to
    existing trifle/universe specs (linked).
12. **Onboarding Checklist** — the ordered, followable procedure to add one tool end-to-end
    (install arm → probe conformance → pick ladder rung → write JSON → sidecar if needed → theme →
    completion → pickers/aliases → default-group membership → Pester tests → ledger/docs entry).
    This is what makes the standard "unambiguously followable."

**Proposed additions** (the brief's "look for patterns" ask), folded into the relevant sections:
adapter↔conformance-failure linkage (§4); conformance ledger as machine-readable superset of
`external-dependencies.md` (§4); reaffirm strict-mode + degrade-silently invariants; document the
alias-collision / coreutils-shadow interaction with default-tool winners (§10).

## Files

- **Modify**: `ToolAcquisitionSpec.md` (repo root) — the whole deliverable.
- No code changes in this task. The spec *describes* future artifacts
  (`build/Test-DFToolConformance.ps1`, `data/theme-aliases.json`, `data/tool-conformance.json`,
  `$DFConfig.Defaults`) but does not create them — those are separate implementation efforts.

## Verification

- Self-review: no TBD/placeholder; sections internally consistent; every normative rule cites the
  concrete existing file it formalizes or the new artifact it introduces; each brief goal maps to a
  section.
- Confirm the document is followable: pick one not-yet-integrated tool as a dry-run and check the
  Onboarding Checklist (§12) produces an unambiguous sequence with no gaps.
- User reviews the rewritten `ToolAcquisitionSpec.md` before any implementation of the artifacts it
  describes.
