---
name: publish-from-nonstandard-folder
description: PSGallery publish from this clone needs a DotForge-named staging folder
metadata: 
  node_type: memory
  type: project
  originSessionId: 704083cb-5119-492b-9153-15bfd4aa4f33
  modified: 2026-07-24T00:03:54.317Z
---

Publishing DotForge to PSGallery from THIS clone fails with the documented
`Publish-PSResource -Path .` (CLAUDE.md step 8).

**Why:** `Publish-PSResource -Path <dir>` derives the expected manifest name from the
folder name and looks for `<foldername>.psd1`. This clone's folder is
`DotForge-Codex-Carapace-Inshellisense-Integration`, so it looks for
`DotForge-Codex-...psd1` and errors ("No file with a .psd1 extension was found").
Passing `-Path ./DotForge.psd1` also fails ("Value cannot be null (path)" — it wants a
directory, not the manifest file).

**How to apply:** Stage the module into a temp folder literally named `DotForge`, then
publish from there:
```
$dest = Join-Path $env:TEMP 'df-publish/DotForge'
Remove-Item (Split-Path $dest) -Recurse -Force -EA Ignore
New-Item -ItemType Directory $dest -Force | Out-Null
robocopy . $dest /E /XD .git .worktrees .claude /XF .env | Out-Null
Publish-PSResource -Path $dest -Repository PSGallery -ApiKey $key
```
Key comes from this repo's gitignored `.env` (`PSGALLERY_API_KEY=...`; the underscore
spelling — matches CLAUDE.md). The publish hook still requires HEAD to sit on the exact
release tag. Related: [[dotforge-module-junction]].
