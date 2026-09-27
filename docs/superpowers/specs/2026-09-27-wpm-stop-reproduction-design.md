# wpm explicit-stop reproduction

## Goal

Determine whether `wpmd` honours `wpmctl stop` for a running `Simple` unit
when the unit restart policy is `Never`, `OnFailure`, or `Always`.

## Test workloads

The test adds two uniquely named, non-autostart units:

- A PowerShell process whose script is an infinite sleep loop. It has no child
  process and should not exit normally.
- A directly supervised `notepad.exe` process. It does not involve PowerShell.

Each workload is exercised once for each restart policy. `RestartSec` is one
second, and the observation period after an explicit stop is at least three
seconds.

## Invariant

After `wpmctl stop <unit>` returns, the unit must remain stopped and must not
obtain a new PID, independent of its restart policy. A restart in either
workload disproves the PowerShell-wrapper explanation and is evidence of a
`wpmd` lifecycle defect.

## Evidence and safety

The runner will record wpm version, unit configuration, state and PID before
and after stop, and process-tree observations. Units use `Autostart = false`.
The runner will close only test-owned Notepad processes, stop test units, and
remove only its `wpm-repro-*` files in a `finally` cleanup path.

## Deliverable

Write a Markdown report containing the exact commands, observed outcomes,
conclusion, and—if the invariant fails—a concise upstream issue report.
