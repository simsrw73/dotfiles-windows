---
name: dotforge-module-junction
description: The shell loads DotForge via a PowerShell module junction; two clones of the repo exist on divergent branches
metadata: 
  node_type: memory
  type: project
  originSessionId: c87dfc90-8ebd-4e72-8270-eea3dcfb2104
  modified: 2026-07-20T16:26:48.310Z
---

The user's PowerShell profile does `Import-Module DotForge` **by name**, which resolves
to the junction `~/OneDrive/Documents/PowerShell/Modules/DotForge`. That junction is the
only thing deciding which working copy the live shell runs.

Two clones of the same repo (identical root commit `a8e3f11`) exist on divergent branches:
- `C:\Users\simsr\projects\DotForge` — package-universe branch, 33 tools, no completion stack.
- `C:\Users\simsr\projects\DotForge-Codex-Carapace-Inshellisense-Integration` — completion-stack
  feature, 35 tools (adds fnm, inshellisense).

On 2026-07-20 the junction was **repointed** from the old clone to the feature clone, which is
why fnm/node/inshellisense and the completion stack "suddenly worked." If the user reports a
DotForge feature missing at the prompt, first verify which clone the junction targets
(`(Get-Item <junction> -Force).Target`) and its tool count — don't assume the shell runs this repo.

The junction carries a ReadOnly + OneDrive-pinned attribute; removing it needs the ReadOnly
bit cleared first (`DirectoryInfo.Attributes`), then `[IO.Directory]::Delete($p,$false)`.

**Publishing from this clone:** `Publish-PSResource -Path .` derives the manifest name from the
*folder* name, so it fails here (looks for `DotForge-Codex-...psd1`). Publish through the junction
instead — `Set-Location <junction>` (folder name `DotForge` → finds `DotForge.psd1`) then
`Publish-PSResource -Path .`. Git still resolves to this clone (so the tag-gate hook passes) and
the manifest version is this clone's. The API key lives in the sibling clone's `.env` under the
key name **`PSGALLERY_APIKey`** (not `PSGALLERY_API_KEY`). Verify releases via the gallery API
(`FindPackagesById`), not local `Find-PSResource`, which strips the `-preview` suffix.

Related: [[dotforge-fnm-xdg-globals]]
