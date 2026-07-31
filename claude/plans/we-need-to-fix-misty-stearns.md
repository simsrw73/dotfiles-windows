# Fix `glow` configuration — replace env vars with a CLI-flag wrapper

## Context

`Tools/glow.json` configures glow via `xdg.method: "env"`, setting
`GLOW_CONFIG_DIR=${XDG_CONFIG_HOME}/glow` and creating that directory. **None of it works.**
Verified empirically against the installed glow 2.1.2 (`f570874`):

| Knob | Result |
| --- | --- |
| `GLOW_CONFIG_DIR` (also `GLOW_CONFIG_HOME`, `GLOW_CONFIG`, `GLOW_CONFIG_FILE`) | **Ignored.** `glow --help` still reports `default C:\Users\simsr\AppData\Local\glow\Config\glow.yml`, and the path does *not* move when `APPDATA`/`LOCALAPPDATA` are redirected — glow resolves it through a Win32 known-folder call, so no environment variable can relocate it. |
| `GLAMOUR_STYLE` (currently set in the live shell, pointing at `$XDG_CONFIG_HOME/glamour/themes/catppuccin-mocha.json`) | **Not read at all** — a deliberately bogus value produces no error and no effect. |
| `GLOW_STYLE` | Read and validated (a bogus path errors), but it loses to glow's non-TTY downgrade, so the style silently fails to apply. Unreliable. |
| `-s <path>` flag | **Works**, and forces the style even when stdout is piped. |
| `--config <path>` flag | Locates the file, but its contents do not affect `glow <file>` rendering — a bogus path, malformed YAML, and a bogus `style:` key all pass silently. Still meaningful for `glow config` (the editor subcommand) and TUI mode. |
| Built-in style names | `auto`, `dark`, `light`, `dracula`, `pink`, `notty`, `ascii`, `tokyo-night` |

Net: the env-var approach is dead code, `$XDG_CONFIG_HOME/glow` is an empty directory DotForge
creates for nothing, and the catppuccin theme never renders. Outcome wanted: `glow` at the prompt
renders with the catppuccin-mocha theme and reads its config from the XDG tree, on this machine and
any other.

## Approach

Wrap `glow` in a global function that passes `--config` and `-s` explicitly. Theme resolution
follows the existing `Tools/psreadline.ps1` pattern (bundled themes + XDG user override +
`$DFConfig` selection).

Three facts settled by testing that shape the design:

1. **A wrapper function does not break carapace completion.** `Register-ArgumentCompleter -Native
   -CommandName glow` still fires when `glow` resolves to a PowerShell function (verified in
   `pwsh`), so `Tools/carapace.ps1`'s ~519 completers are unaffected.
2. **`& glow.exe` inside the wrapper resolves to the Application, not the function** — no recursion.
   (`(Get-Command glow).CommandType` → `Function`; `glow.exe` → `Application`.)
3. **The wrapper must forward piped stdin explicitly.** A naive `& glow.exe @args` body *hangs*
   when used as `'# Hi' | glow` — a PowerShell function without a `process` block swallows pipeline
   input, and glow.exe then blocks on the inherited console stdin. Guarding with
   `$MyInvocation.ExpectingInput` and forwarding `$input` fixes it (verified: piped stdin, file
   argument, and `--version`/subcommands all work).

`Register-DFTool`'s declarative `aliases` mechanism (`Public/Register-DFTool.ps1:136-163`) cannot
express this — it does not expand `${XDG_*}` tokens in `args`, cannot skip `-s` when a theme file is
missing, and produces exactly the naive body that hangs on pipes. **No change to
`Register-DFTool.ps1` is needed**; a companion `.ps1` is the right seam.

## Changes

### 1. `Tools/glow.json`

- `xdg.method`: `"env"` → `"wrapper"` (the value Register-DFTool already maps to "handled by
  companion .ps1", `Public/Register-DFTool.ps1:129-131`).
- Delete `xdg.vars` (the `GLOW_CONFIG_DIR` entry) and `xdg.dirs` — both are inert. The sidecar
  creates the directory via `New-DFDirectory` instead, same as `Tools/carapace.ps1` does for its
  spec dir.
- Add a `settings` block, read by the sidecar through the `$DFCurrentTool` contract:
  ```json
  "settings": { "theme": "catppuccin-mocha", "configFile": "${XDG_CONFIG_HOME}/glow/glow.yml" }
  ```
- Leave `"picker": null` — no picker in scope here.

### 2. `Tools/glow/catppuccin-mocha.json` (new)

Copy of `C:\Users\simsr\.config\glamour\themes\catppuccin-mocha.json` (verified to be a valid
glamour style document — `document`/`h1`..`h6`/`code_block.chroma`/`table` etc.). Bundling it is
what makes the fix portable; today that file exists only outside the repo.

**Only this one theme is bundled.** `dark`, `light`, `dracula`, `pink`, `ascii`, `tokyo-night`, and
`auto` already ship inside glow, so shipping duplicates would be dead weight — the resolver passes
bare built-in names straight through to `-s` instead.

### 3. `Tools/glow.ps1` (new companion)

Modeled directly on `Tools/psreadline.ps1`. Responsibilities, in order:

1. Read `$DFCurrentTool.settings` for `theme` and `configFile`; expand `configFile` with the private
   `Expand-DFXdgPath` (`Private/Expand-DFXdgPath.ps1`). Let `$Global:DFConfig['GlowTheme']` override
   the theme name, mirroring `PSReadLineTheme` (`Tools/psreadline.ps1:103-107`).
2. `New-DFDirectory` on the config file's parent directory.
3. Define `global:Resolve-DFGlowStyle -Name <n>` returning the string to hand `-s`, resolving in
   this order (mirrors `Invoke-DFApplyPSReadLineTheme`'s lookup, `Tools/psreadline.ps1:59-80`):
   - rooted path that exists → use verbatim
   - `$XDG_CONFIG_HOME/glow/themes/<n>.json` → use
   - bundled `Join-Path $PSScriptRoot 'glow' "<n>.json"` → use
   - `<n>` is one of glow's built-ins (`auto|dark|light|dracula|pink|notty|ascii|tokyo-night`) →
     return the bare name
   - otherwise → `Write-Warning` and return `'auto'`
   The fallback matters: `-s` pointing at a nonexistent file makes glow **exit 1** with
   `Error: specified style does not exist`, which would break the command outright on a machine
   without the theme.
4. Store the result in `$global:DFGlowStyle`. The wrapper reads this at call time rather than
   capturing it, so `$global:DFGlowStyle = 'dracula'` switches the theme live for the session. It
   doubles as a test-observable side channel, like `$DFPSReadLineColors`.
5. Define the wrapper, capturing `$_cfg` via `.GetNewClosure()`:
   ```powershell
   Set-Item -Path 'function:global:glow' -Value ({
       if ($MyInvocation.ExpectingInput) {
           $input | & glow.exe --config $_cfg -s $global:DFGlowStyle @args
       } else {
           & glow.exe --config $_cfg -s $global:DFGlowStyle @args
       }
   }.GetNewClosure())
   ```
   A simple (non-advanced) function is required so `@args` stays available and glow's own flags
   (`-w`, `-p`, `-t`, `-a`) pass through unbound. Both flags are persistent in cobra — verified that
   `glow --config X -s Y completion powershell`, `... help`, and `... --version` all still work.

### 4. Tests — `tests/glow.Tests.ps1` (new)

Follow `tests/psreadline.Tests.ps1`: dot-source the same helper chain in `BeforeAll`, point
`$Env:XDG_CONFIG_HOME` at `$TestDrive`, call
`Register-DFTool -Name 'glow' -ToolsPath <real Tools>`, and clean up the global function,
`$DFGlowStyle`, and `$DFConfig` in `AfterEach`. Cover:

- registering glow defines `function:global:glow`
- `$global:DFGlowStyle` resolves to the bundled `Tools/glow/catppuccin-mocha.json` path by default
- a theme file dropped in `$TestDrive/glow/themes/<n>.json` wins over the bundled copy
- `$DFConfig['GlowTheme'] = 'dracula'` yields the bare built-in name `dracula`
- an unknown theme name warns and falls back to `auto`
- the config directory is created

Guard the suite with a `glow.exe`-present check where a test would actually invoke it — most
assertions inspect resolution state and need no binary.

### 5. Docs

- `README.md`: add `GlowTheme = 'catppuccin-mocha'` to the `$DFConfig` block (~line 80) and a
  **glow** entry to the *Tool-Specific Helpers* section (~line 500) documenting the `glow` wrapper
  and `Resolve-DFGlowStyle` / `$DFGlowStyle`.
- `CHANGELOG.md`: `[Unreleased]` — Fixed: glow ignored `GLOW_CONFIG_DIR`/`GLAMOUR_STYLE`; now
  configured via `--config`/`-s`.
- `docs/external-dependencies.md`: add an entry. This takes a dependency on glow's **flag surface**
  (`--config`, `-s`) and its built-in style names, plus the fact that its config path is
  known-folder-derived and env-immune. Degradation: an unknown/renamed style falls back to `auto`
  (warn, never fail); glow itself is untouched if the flags ever change meaning.
- `examples/`: no glow references exist today (grep-verified) — add one only if a profile example
  gains a `GlowTheme` line.

## Out of scope

The `fgl` / `Read-MarkdownFile` picker listed as a lost feature in
`docs/superpowers/specs/2026-07-15-legacy-profile-fold-in-design.md:151`, and any glow *theme*
picker analogous to `fprl`. Both are additive features, not part of this fix.

## Verification

```powershell
pwsh -NoProfile -Command 'Invoke-Pester tests/glow.Tests.ps1 -Output Detailed'
pwsh -NoProfile -Command 'Invoke-Pester tests/ -Output Detailed'   # no regressions
```

Then in a real session:

```powershell
Import-Module ./DotForge.psd1 -Force
Register-DFTool -Name glow -Verbose
(Get-Command glow).CommandType      # Function
$global:DFGlowStyle                 # -> ...\Tools\glow\catppuccin-mocha.json
glow README.md                      # colored headings/code, not plain text
'# Hi' | glow                       # renders — must NOT hang (the regression guarded against)
glow --version                      # subcommand/flag passthrough intact
$global:DFGlowStyle = 'dracula'; glow README.md   # live theme switch
glow <Tab>                          # carapace completion still fires
```

Also confirm the stale env var is gone: `$Env:GLOW_CONFIG_DIR` should be unset in a fresh session
after this change (the currently-set `GLAMOUR_STYLE` comes from outside the repo and can be dropped
from your profile once the wrapper lands).
