# Fix `ls` → eza (coreutils readline hijack) + eza arg-parsing bug

## Context

`ls` stopped resolving to `eza`. **DotForge is not at fault** — its fix (commit `a0abd77`) is
intact and verified working. Two independent problems are stacked:

### Problem 1 — coreutils hijacks `ls` above the alias layer (the reported symptom)

Coreutils for Windows (winget `Microsoft.Coreutils` 2026.6.16, installed 2026-06-22 21:40)
injected a `PSConsoleHostReadLine` override into `Microsoft.PowerShell_profile.ps1`
(installer-owned, marked `DO NOT MODIFY -- coreutils -- 60b36fc6…`; the file is 100% that block).

The hook rewrites the **raw text you type** before PowerShell resolves any command name:

```
ls   →   & 'C:\Program Files\coreutils\cmd\ls.cmd' --color=auto
```

No alias/function/`-Force` can win — the word `ls` is gone before resolution begins. Because the
hook only rewrites *command names*, `Get-Command ls` still reports the eza function, so the alias
**inspects as correct while typing `ls` runs coreutils**. That's the confusing part.

Profile load order (`profile.ps1` → then `Microsoft.PowerShell_profile.ps1`) is a red herring; a
readline hook doesn't race with alias definitions.

Verified in a clean shell — DotForge works correctly:
```
pwsh -NoProfile -Command "Import-Module ./DotForge.psd1; Register-DFTool -Name eza; Get-Command ls"
  → Function ls (eza wrapper)   ✅
```

Beyond `ls`, the hook also captures `touch`, `env`, `paste`, `printenv` (DotForge/profile helpers)
and built-ins `cat`, `sort`, `date`, `echo`, `pwd`, `test`, `sleep`, `find`.

### Problem 2 — real bug in `Tools/eza.json` (currently masked)

eza treats `--icons`/`--hyperlink` as **optional-value** flags. Commit `4d29177` appended
`--hyperlink` to the end of all four aliases, so a trailing flag swallows the path:

```
eza --color=auto --icons --group-directories-first --hyperlink .
  → error: invalid value '.' for '--hyperlink [<WHEN>]'   (exit 2)
eza --color=auto --icons=auto --group-directories-first --hyperlink=auto .
  → 19 entries (exit 0)                                    ✅ fix verified
```

Coreutils masks this for `ls`/`la`. `ll`/`tree` are **not** hooked, so `ll .` / `tree src` fail
today. Fixing only Problem 1 makes `ls .` start erroring — both must land together.

**Outcome:** `ls`/`ll`/`la`/`tree` all run eza and accept a path; `touch`/`env`/`paste`/`printenv`
return to their DotForge/profile implementations.

---

## Part 1 — Disable the hijacked coreutils utilities (system change, needs admin)

Use the **supported** opt-out, not a hand-edit: the installer reads a `DisabledUtilities`
`REG_MULTI_SZ` under `HKLM:\SOFTWARE\Microsoft\coreutils` and regenerates the profile block from it
(`Get-EnabledCoreutilsAliases` in `C:\Program Files\coreutils\pwsh-install.ps1`). Editing the
`DO NOT MODIFY` block directly would be overwritten on the next upgrade; the registry list survives.

Run in an **elevated** shell (writes HKLM):

```powershell
& 'C:\Program Files\coreutils\bin\coreutils-manager.exe' disable ls touch env paste printenv
```

Key detail: there is **no `la.cmd`**. `la` only enters the list via the installer's
`if ($aliases.Contains('ls')) { $aliases.Add('la') }` special case — so disabling `ls` removes
`la` automatically. Do **not** pass `la`; it is not a real utility name and may be rejected.

If `coreutils-manager` does not itself regenerate the profiles, run the refresh explicitly
(elevated) — it rewrites every recorded profile from the registry:

```powershell
& 'C:\Program Files\coreutils\pwsh-install.ps1' -Action Refresh -CmdDir 'C:\Program Files\coreutils\cmd'
```

Recorded target (from `HKLM:\SOFTWARE\Microsoft\coreutils\PowerShellProfiles`):
`OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`.

**Trade-off accepted:** GNU `touch`/`env`/`paste`/`printenv` are no longer available bare at the
prompt. They remain reachable via `coreutils touch …` or the `bin`/`cmd` directories.

## Part 2 — Fix `Tools/eza.json`

Make both optional-value flags explicit in **all four** aliases (`ls`, `ll`, `la`, `tree`):

- `"--icons"` → `"--icons=auto"`
- `"--hyperlink"` → `"--hyperlink=auto"`

Leave `--color=auto` as-is (already explicit). `Tools/eza.json:41` already uses the correct
`--color=always` form for the picker — this makes the aliases consistent with it.

## Part 3 — Close the test gap

`tests/Register-DFTool.Tests.ps1` asserts wrappers **exist** but never **invokes** one — which is
why `4d29177` shipped unnoticed. `TODO.md:18` already requests this coverage.

Add a test that invokes a generated wrapper with a path argument and asserts the path reaches the
command as a positional arg (not swallowed by a preceding flag). Follow the existing fixture
pattern at `tests/Register-DFTool.Tests.ps1:36-47` (`tt` zero-arg, `tt-v` arg-bearing) and its
`-Scope Global` cleanup at lines 56-59. Assert against a stub command rather than spawning real
`eza`, consistent with the `Invoke-DFFzf` mocking approach in CLAUDE.md.

## Critical files

| File | Change |
|---|---|
| `Tools/eza.json` | `=auto` on `--icons`/`--hyperlink` in all 4 aliases |
| `tests/Register-DFTool.Tests.ps1` | new wrapper-invocation test |
| `HKLM:\SOFTWARE\Microsoft\coreutils` → `DisabledUtilities` | via `coreutils-manager` (not hand-edited) |

`Public/Register-DFTool.ps1` needs **no change** — its alias/wrapper logic is correct.

## Verification

1. **Registry + profile regenerated:**
   ```powershell
   (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\coreutils).DisabledUtilities   # ls touch env paste printenv
   $p = Get-Content $PROFILE.CurrentUserCurrentHost -Raw
   foreach ($n in 'ls','la','touch','env','paste','printenv') { "$n present: $($p -match "'$n'")" }  # all False
   ```
2. **eza args fixed (no profile needed):**
   ```powershell
   pwsh -NoProfile -Command "& eza --color=auto --icons=auto --group-directories-first --hyperlink=auto ."
   ```
   Expect exit 0 and a listing. (Note: bare `eza` with no path **blocks** in a headless shell —
   always pass a path when testing non-interactively.)
3. **Tests:** `pwsh -NoProfile -Command "Invoke-Pester tests/Register-DFTool.Tests.ps1 -Output Detailed"`
4. **End-to-end — in a NEW interactive terminal** (the readline hook only rebuilds on shell start):
   - `ls`, `ls .`, `ll .`, `la .`, `tree` → eza output, no clap error
   - `Get-Command ls` → Function (eza wrapper)
   - `touch`, `env`, `paste`, `printenv` → DotForge/profile versions
   - Regression check: `cat`, `sort`, `find` still resolve to coreutils

## Notes / follow-ups (not in scope)

- `touch` is defined **twice**: `ProfileModules/Aliases.ps1:7` (`New-File`) then DotForge's
  `-Force` (`New-DFFile`) wins, since `Import-Module DotForge` runs after. Reclaiming `touch`
  yields DotForge's `New-DFFile`. This is exactly the `-Force` clobbering `TODO.md:17` tracks.
- `ProfileModules/cli_tools_config.ps1` is **dead code** — not dot-sourced by any profile. It still
  contains the legacy eza `_ls`/`_ll`/`_la`/`_tree` functions, and `Aliases.ps1:11` has a stale
  comment claiming ls/ll/la/tree live in `Functions.ps1` (they don't). Worth deleting/correcting.
- A coreutils upgrade re-runs the injector, but it reads `DisabledUtilities` — so this fix persists.
