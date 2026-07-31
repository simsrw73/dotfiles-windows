# Push `main` to origin

## Context

The local `main` branch is 10 commits ahead of `origin/main` (the completion-stack
integration work: coordinator, inshellisense bridge, PSReadLine binding restore, docs,
tests, and data artifacts). The user asked to push. Nothing is staged or modified —
the only working-tree item is one untracked file.

## Change

Run:

```powershell
git push origin main
```

Untracked file `docs/superpowers/plans/2026-07-19-completion-stack-integration.md` is
left alone — not committed, not pushed.

## Verification

```powershell
git status -sb   # expect: ## main...origin/main (no "ahead")
```
