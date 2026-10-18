---
name: real-tools-write-known-folders
description: "Running a real tool (glow, etc.) — probes, tests, doc examples — can write into the user's real AppData even with XDG redirected; check and clean up"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 5c5133da-025f-49b0-aef8-6b0b176a97f9
  modified: 2026-10-17T18:33:06.073Z
---

Running a real CLI tool on this machine can write into the user's own `%APPDATA%` / `%LOCALAPPDATA%`
even when every `XDG_*_HOME` points at a scratch folder: glow 3 finds `%LOCALAPPDATA%\glow` through a
Windows known-folder API (immune to env vars) and creates `Config\glow.yml` (unless `GLOW_CONFIG_HOME`
is set) and `Cache\glow.log` on every run. On 2026-10-11 my probes, a doc example and the conformance
harness recreated a folder the user had deleted, which re-triggered a DotForge config conflict for them.

**Why:** the user deletes stray config deliberately; DotForge's T-61 conflict check then fires on what
my runs left behind, and it looks like their machine is broken.

**How to apply:** before running a real tool for a probe, note whether its known folders exist; remove
only what the run created (and say so). `build/Test-DFFull.ps1` now fails on new tool-named folders and
`build/Test-DFToolConformance.ps1` removes them (`build/DFToolFolders.ps1`); keep tests and runnable doc
blocks from running real tools that do this (mark the block `<!-- system -->`, or use a stand-in exe).
Also: run ad-hoc `pwsh -c` with `-NoProfile`, or it runs the user's real profile.

Worse: some tools edit shell profiles. broot 1.61, run with a fresh `BROOT_CONFIG_DIR` (no
`launcher\installed-v5`), installed its own `br`: it appended a `source`/`.` line to the user's OneDrive
`Microsoft.PowerShell_profile.ps1`, `~/.bashrc` and `~/.bash_profile`, and wrote `%APPDATA%\dystroy\broot\data`
(2026-10-17; I removed exactly those lines, and checked the result with `chezmoi diff`). Before probing a tool
with a first-run installer, set its install state first (`broot --set-install-state installed`), and
md5 the profiles before and after.

Related: [[delegation-via-orca]]
