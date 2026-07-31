---
name: dotforge-fnm-xdg-globals
description: "fnm.json redirects FNM_DIR to the XDG tree, which needs its own copy of global npm packages"
metadata: 
  node_type: memory
  type: project
  originSessionId: c87dfc90-8ebd-4e72-8270-eea3dcfb2104
  modified: 2026-07-20T15:43:26.975Z
---

`Tools/fnm.json` sets `FNM_DIR = ${XDG_DATA_HOME}/fnm` (`~/.local/share/fnm`). fnm installs
node **and global npm packages per FNM_DIR**, so the XDG tree is a *separate* Node install
from the default `%APPDATA%\fnm` tree. Global packages installed under one FNM_DIR are invisible
under the other.

On 2026-07-20 `@microsoft/inshellisense` (`is`) lived only in the `%APPDATA%\fnm` tree, so with
DotForge's XDG FNM_DIR active, `is` resolved as MISSING and the Carapace inshellisense bridge
never fired. Fix chosen by the user: **keep XDG, migrate globals** — `npm i -g` the packages into
the XDG tree while it is active (`FNM_DIR=~/.local/share/fnm` + `fnm env | iex`). corepack/npm were
already present there; only inshellisense needed installing.

If node/npm globals go missing after an fnm change, check which FNM_DIR tree is active and whether
the global lives there. Related: [[dotforge-module-junction]]
