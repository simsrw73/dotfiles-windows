# Completion Stack — fix the live shell

## Context

Codex added a completion-stack feature (PSReadLine + Carapace + PSFzf +
inshellisense) in **this** clone (`projects/DotForge-Codex-Carapace-Inshellisense-Integration`,
35 tools). The user's shell reported `docker <TAB>` emitting ANSI, `scoop <TAB>`
completing as `.\`, and fnm/node/inshellisense "broken."

**Root cause (single):** the PowerShell module symlink
`~/OneDrive/Documents/PowerShell/Modules/DotForge` points at a *different* clone
(`projects/DotForge`, package-universe branch, 33 tools) that has **no fnm,
no inshellisense, and no completion-stack resolver**. The shell has never run the
feature. Same git repo (root commit `a8e3f11`), two divergent branches.

Secondary defects (real in this clone too, verified in the user's terminal):
- carapace styles `ListItemText` with ANSI **only when console-attached** →
  invisible to headless tests. Tab=`Complete` inserts the styled common prefix.
- carapace ships **no scoop spec** → `scoop <TAB>` falls to filesystem completion.
- PSFzf runs fzf **without `--ansi`**, so even the picker shows raw escapes.
- `carapace.ps1` runs the inshellisense-bridge check *before* fnm puts `is` on
  PATH → `CARAPACE_BRIDGES` never populated.
- `fnm.json` sets `FNM_DIR=${XDG_DATA_HOME}/fnm`, a Node tree missing the global
  npm packages (`is`, corepack) that live in `%APPDATA%\fnm`.

## Decisions (user)

1. Repoint the module symlink to this clone.
2. Keep FNM_DIR XDG; migrate global npm packages into `~/.local/share/fnm`.
3. Add a carapace user spec for scoop (documented `~/.config/carapace/specs`).
4. Add `--ansi` via the documented `FZF_DEFAULT_OPTS` env var (no PSFzf internals).

## Work

### A. Environment (immediate relief)
- **A1** Repoint symlink: delete the reparse point (link only) and recreate
  `…/Modules/DotForge` → this clone. Dev Mode is on, no admin needed.
- **A2** Migrate npm globals: with `FNM_DIR=~/.local/share/fnm` active, install
  `@microsoft/inshellisense` and `corepack` into that Node tree.

### B. Code (this clone)
- **B1** scoop carapace spec. Bundle `Tools/carapace/specs/scoop.yaml`; extend
  `Tools/carapace.ps1` to deploy bundled specs into `$XDG_CONFIG_HOME/carapace/specs/`.
- **B2** `--ansi`. In `Private/Initialize-DFCompletionStack.ps1`, when the PSFzf
  Tab handler is selected, idempotently ensure `$env:FZF_DEFAULT_OPTS` contains
  `--ansi` (same merge style as the bridge de-dup).
- **B3** Bridge ordering. Add `"dependsOn": ["fnm"]` to `Tools/carapace.json` so
  `is` is on PATH when `Enable-DFCarapaceInshellisenseBridge` runs.

### C. Docs + tests
- Pester: scoop-spec deploy, `--ansi` idempotent merge, carapace→fnm ordering.
- README completion-stack section + `docs/external-dependencies.md` (carapace ANSI
  console-only behavior; scoop specs dir). CHANGELOG `[Unreleased]`.

## Verification
- New shell: `node -v`, `npm -v`, `is --version` all resolve; `Get-Module DotForge`
  → this clone, 35 tools.
- `docker <TAB>` opens a colored fzf picker, inserts clean `build ` (no escapes).
- `scoop <TAB>` lists install/uninstall/update/… via carapace.
- `$env:CARAPACE_BRIDGES` contains `inshellisense`; `$env:FZF_DEFAULT_OPTS`
  contains `--ansi`.
- `Invoke-Pester tests/ -Output Detailed` green (run from `pwsh -NoProfile`).
