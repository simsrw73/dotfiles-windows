---
name: strict-safe-code
description: "User strongly prefers strict-safe code in every project and language — enable strict checking, never disable it to paper over sloppy access patterns"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4d189987-049a-467e-8f9e-9eb89e9de129
---

Randy **strongly** prefers strict-safe code — globally, across every project and
every language. Always enable the language's strict checking and follow that
language's conventions for it. Stated 2026-07-15.

Concretely, by language: PowerShell `Set-StrictMode -Version Latest`; TypeScript
`strict: true` (and no `any`/`@ts-ignore` escape hatches); Python type hints with
a type checker; C `-Wall -Werror`; Rust no `unsafe` without cause; etc. Match
whatever the ecosystem's idiom for "strict" is rather than inventing one.

**Why:** strict mode turns silent wrong-answer bugs into loud failures at the
point of the defect. Non-strict code that reads a missing property and gets
`$null` produces plausible-looking empty output instead of an error — the failure
surfaces far from its cause, if at all.

**How to apply:** enable strict checking by default in new code. When existing
code *needs* non-strict to work, that is a signal the code accesses data
unsafely — fix the access pattern (explicit existence checks) rather than
disabling the checking. Treat `Set-StrictMode -Off`, `strict: false`, blanket
`# type: ignore`, and equivalents as defects to be removed, not as tools. If
disabling strictness genuinely seems like the only option, raise it rather than
doing it silently.

Worked example (DotForge, 2026-07-15): `build/Build-DFPackageUniverseRaw.ps1`
carried `Set-StrictMode -Off` because the OData mappers threw on absent
properties. That was strict mode correctly reporting real defects — and the
suppression had already cost a live bug (`publisher` silently empty because the
mapper read a property the feed never sends). Fixing the access patterns
(`Get-DFXmlMember`/`Get-DFXmlText` in `Private/DFCatalog.ps1`) and flipping to
`Set-StrictMode -Version Latest` then immediately caught three further latent
bugs during the rewrite.
