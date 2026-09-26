# AutoHotkey application structure

## Goal

Make the personal AutoHotkey v2 script safer and easier to extend while
preserving its current global shortcuts.

## Structure

- `autohotkey.ahk` remains the entry point and contains only directives,
  includes, and application startup.
- `Lib/App.ahk` defines an `App` class that owns tray-menu setup, script
  editing, reloading, exiting, and explicit Startup-folder registration.
- `Lib/WindowLauncher.ahk` defines a `WindowLauncher` class that restores and
  activates an existing window or launches an executable and waits for its
  window before activation.
- `hotkeys.ahk` contains named hotkey handlers and delegates window work to
  `WindowLauncher`.

## Lifecycle and startup

The entry point will require AutoHotkey v2, force a single instance, and enable
warnings. Startup registration will no longer happen during launch. Instead,
the tray menu will expose a checked `Run at startup` item. The application will
only delete the exact shortcut it created, avoiding deletion of a user-owned
shortcut with the same name.

## Window behavior

The Windows Terminal and File Explorer shortcuts will first restore and
activate an existing matching window. If none exists, the launcher will start
the program, wait for the expected window, then activate it. A failed launch or
timeout will show a concise error rather than causing an unhandled error.

## Verification

A PowerShell static test will validate the v2 directives, class boundaries,
startup-menu wiring, explicit function calls, and launcher safety checks. The
test does not run the entry script because running it may modify the user's
Startup folder.

## Non-goals

This change does not add a GUI, a settings file, configurable hotkeys, or a
general application registry. Those can be introduced later without changing
the public responsibilities of `App` or `WindowLauncher`.
