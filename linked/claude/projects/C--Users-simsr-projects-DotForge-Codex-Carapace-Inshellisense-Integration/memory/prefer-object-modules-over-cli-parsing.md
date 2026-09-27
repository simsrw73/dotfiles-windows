---
name: prefer-object-modules-over-cli-parsing
description: "For package-manager pickers, prefer a PowerShell object module over parsing CLI table output"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 704083cb-5119-492b-9153-15bfd4aa4f33
  modified: 2026-07-23T18:51:24.606Z
---

When building tool wrappers/pickers, prefer a native PowerShell module that returns
objects over parsing a CLI's human-readable table output. For winget, use the
`Microsoft.WinGet.Client` module (`Find-WinGetPackage`, `Get-WinGetPackage`,
`Install-/Uninstall-/Update-WinGetPackage`) instead of scraping `winget search`/`list`.

**Why:** Table output is fragile — column widths shift, names contain double spaces,
and winget emits ANSI codes + an interactive-spinner `\r`. The module gives stable
`{Name, Id, Version, IsUpdateAvailable, …}` objects. The user proposed this directly
over a CLI-parsing plan.

**How to apply:** Reach for the object module first. Fall back to CLI only where the
module can't reach — e.g. fzf `--preview` / `--bind execute(...)` run in a **cmd
subshell** that can't call cmdlets, so display/subshell steps use `winget show`/
`winget install` CLI. scoop/choco have no such module, so they still need parsing.
Related: [[dotforge-module-junction]].
