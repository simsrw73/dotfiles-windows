# AutoHotkey wpm watchdog design

## Goal

Run the user's primary AutoHotkey v2 script as soon as the interactive logon
session starts, restart it after an unexpected exit, and tolerate AutoHotkey
reloads that replace the script process PID.

## Context

`wpmd` starts at interactive logon through the `wpmd` Scheduled Task. Its
units use `Autostart = true`. A direct AutoHotkey unit would not be suitable:
AutoHotkey reloads can replace the interpreter process, leaving wpm tracking
the exited PID instead of the replacement process. The current Startup-folder
shortcut also launches the script separately and must be removed to keep a
single startup authority.

## Design

Add two files to `linked/wpm`:

1. `autohotkey-watchdog.toml` starts a non-interactive PowerShell watchdog at
   wpmd startup, restarts that watchdog unconditionally if it exits, and uses
   a short restart delay.
2. `autohotkey-watchdog.ps1` looks for a running `AutoHotkey64.exe` whose
   command line includes the canonical script path
   `C:\\Users\\simsr\\.config\\autohotkey\\autohotkey.ahk`. It does not track a
   PID. If no matching process exists for a small grace interval, it launches
   `C:\\Program Files\\AutoHotkey\\v2\\AutoHotkey64.exe` with that script.

The watchdog intentionally does not attempt hung-window detection. It logs
state transitions to the wpm log and supports a pause-file override for
intentional temporary shutdowns.

## Startup cleanup

Remove the existing `autohotkey.ahk.lnk` from the user's Startup folder only
after the wpm unit has been installed and started successfully. This prevents
two independent startup launches.

## Validation

- Parse and exercise the watchdog in a one-iteration/dry-run mode.
- Reload wpm and start the new unit.
- Confirm `wpmctl log autohotkey-watchdog` records management of the script.
- Start or reload the script manually; confirm the PID may change without the
  watchdog launching a second copy.
- Confirm the Startup-folder shortcut has been removed only after the unit is
  working.

## Improvements considered

The existing Scheduled Task already uses an interactive logon trigger, limited
token, no execution time limit, and `IgnoreNew` for duplicate starts. Those
settings are appropriate for a GUI automation process. No boot trigger is
appropriate because AutoHotkey needs the user's interactive desktop.
