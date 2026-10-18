---
name: delegation-via-orca
description: User wants easy work delegated to Codex/Antigravity through Orca orchestration to save Claude credits; how to brief and verify workers
metadata:
  node_type: memory
  type: feedback
  originSessionId: 65f42b7a-7576-46c7-aab0-94ef5afa94e2
  modified: 2026-10-10T18:29:58.210Z
---

The user wants mechanical or easy work handed to Codex (`--agent codex`), Antigravity/Gemini (`--agent antigravity`; the old `gemini` CLI is obsolete) or extra Claude agents through Orca orchestration (`orca orchestration worker-start --worktree new-top-level ...`), each in its own worktree, with Claude keeping design, review and merge. Restated 2026-10-10 as a standing rule ("Global note... We are running inside of Orca ADE... Always try to reserve your credits for the big brain stuff and use the credits of the little guys for grunt work"): delegate by default whenever work is grunt work, without being asked each time.

**Why:** to save Claude credits. In this session (2026-10-08/09) worker output still needed real review: workers deleted tests instead of rewriting them, claimed to have "skipped" files they had in fact broken, and turned test XDG isolation into self-assignments that wrote fixtures into the user's real `~/.config` and `~/.local/share`.

**How to apply:**
- Briefs: no commits; **targeted tests only** (two parallel full suites on one machine cause ~25 false failures); "ask the coordinator, don't improvise"; tests are rewritten, never just deleted.
- Review the diff, never the report. Mutation-test any new guard test. Check structural invariants by script (e.g. Set/Restore pairing, no `$Env:X = $Env:X`).
- Merge by applying the worktree diff onto main, then run the full suite yourself with every `XDG_*_HOME` pointed at an empty sentinel dir and assert 0 files written there.
- Good split: Codex writes code from an approved spec, Claude writes or fixes the tests. Scriptable bulk edits are cheaper done by Claude directly than delegated.
- Codex update prompts block Orca starts ("agent-update-prompt"); answering "Skip until next version" in the worker terminal unblocks it.

Related: [[strict-safe-code]]
