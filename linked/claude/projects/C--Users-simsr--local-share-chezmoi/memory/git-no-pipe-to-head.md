---
name: git-no-pipe-to-head
description: "Never pipe git commands that refresh the index (diff, status) into head — it leaves a stale index.lock"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 21dd6f4e-b9c1-4c12-9198-5e75cc6d2985
  modified: 2026-10-02T00:06:00.950Z
---

Don't run `git diff … | head` or `git status … | head` in the user's repos. `head` exits early, git gets SIGPIPE while refreshing the index under `.git/index.lock`, and the lock is left behind, blocking the next commit (happened 2026-10-01 in the dotfiles repo).

**Why:** a stale lock looks like "another git process is running"; it cost a confused 5-minute wait and a scare about killing the user's processes.
**How to apply:** write git output to a file and read part of it, use `--stat`/`-- path` to keep output small, or `git --no-optional-locks`. Before removing an index.lock, confirm no git process is working in that repo (UniGetUI/Scoop run unrelated `git pull`s).
