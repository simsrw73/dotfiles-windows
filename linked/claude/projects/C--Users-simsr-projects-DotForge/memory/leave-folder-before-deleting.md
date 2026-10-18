---
name: leave-folder-before-deleting
description: "On Windows, cd out of a worktree (and stop scans inside a folder) before removing or moving it; the shell's own cwd caused every \"Permission denied\" leftover"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 65f42b7a-7576-46c7-aab0-94ef5afa94e2
  modified: 2026-10-11T00:06:55.607Z
---

Before `git worktree remove`, `rm -rf` or moving a folder, make sure no process of mine is using it: `cd` out first (the Bash tool's working directory persists between calls), and stop any background scan (`du`, `grep -r`) running inside it.

**Why:** on 2026-10-10 every worktree removal failed with "Permission denied", and moving `build/.package-universe` failed with "Access denied". The user checked with LockSmith/FileSmith and found no lock. The cause was my own shell's working directory sitting inside the worktree (and a `du` still walking the clone). After `cd`-ing to the main checkout, both succeeded at once.

**How to apply:** in the cleanup command, start with `cd /c/Users/simsr/projects/DotForge` (or another folder outside the target), then remove. Don't ask the user to delete leftovers by hand before retrying from outside.
