---
name: pure-powershell-fallbacks
description: "User prefers that every tool DotForge itself needs to run (e.g. gsudo for elevation) has a pure-PowerShell fallback; a preference, not yet a rule"
metadata:
  node_type: memory
  type: user
  originSessionId: 65f42b7a-7576-46c7-aab0-94ef5afa94e2
  modified: 2026-10-10T20:10:07.331Z
---

The user prefers that any outside tool DotForge depends on to do its own job (not the tools it configures) has a pure-PowerShell fallback. Example: gsudo (the `elevator` role) will likely be in the `core` group, but elevation should still fall back to a standard PowerShell way (`Start-Process -Verb RunAs`, or Windows' built-in sudo) when no elevator is installed.

Stated 2026-10-10 during the Update-DFTool design: "I'd prefer that all the tools we require to run dotforge have a pure powershell fallback, but I've not studied that yet, so I wont make it a rule until then. Just preference."

**How to apply:** when a design adds a dependency on an outside program for DotForge's own operation, propose a pure-PowerShell fallback and say what it costs (e.g. a separate UAC window, no captured output). Don't enforce it as a rule or block work on it until the user decides.
