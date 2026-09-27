---
name: yasb-bar-design
description: "User's yasb status bar design spec (Catppuccin Mocha, komorebi, grouper pills) and setup gotchas; rebuilt 2026-09-26 after the original config was lost"
metadata:
  node_type: memory
  type: project
  originSessionId: 523b82bd-cf41-49d4-a822-d8b0393e8f70
  modified: 2026-09-26T14:46:52.326Z
---

yasb config lives in `~/.config/yasb/` (config.yaml + styles.css). The original was lost in ~Sept 2026 with no backup; rebuilt 2026-09-26 from the user's spec. If it's lost again, rebuild from this.

Spec: Catppuccin Mocha; minimal, professional, easy to scan; important info most visible, rarely-used info dim but findable; dark glassy slightly-translucent floating top bar, softly rounded corners, generous spacing; popups/tooltips share the same dark bg/radius/spacing; similar items grouped in grouper pills. Layout — Left: launchpad · [komorebi control, layout, stack, workspaces] · active window title. Center: [HH:MM, yyyy-mm-dd]. Right: [media_lite, audio_visualizer] · [memory, cpu, gpu, disk, traffic — dimmed, must never change width] · [systray popup | volume, control center, bluetooth, wifi] · [github, notifications] · power menu (Catppuccin red icon). No update_check widget — user uses UniGetUI for updates. Disk popup lists C, G, H, S. Full bar on primary monitor, slim bar (launchpad, workspaces, window title, time) on the other. Fonts: Inter + JetBrainsMono Nerd Font.

**Why:** the user lost the first version and had to re-specify everything from memory.
**How to apply:** use this as the brief for any yasb changes; suggest committing `~/.config/yasb` to the `~/.config` git repo after changes.

Gotchas found: the Windows primary is the Dell S2725QS (4K); LG UltraGear is the secondary — use `screens: ["primary"]`/`["*"]`. Qt QSS ignores `:hover` on ancestors (`.a:hover .b` applies always) — style the hovered element itself. Power-menu `` falls back to a wrong font; use `\U000F0425`. User wants: hover feedback on every clickable item, tooltips where supported, systray as a popup (`show_in_popup`), popups with a 16px inset and roomy item spacing. In v2.0.7 only bluetooth/clock/control_center/github/media_lite/notifications/update_check/volume support tooltips; the others have no hook. Popup spacing must go on the inner classed QFrames (header/footer/items); plain-QWidget parts such as `.traffic-menu .header` ignore padding, so pad their children. Popup-internal icons need `font-family: "Segoe Fluent Icons"`. The komorebi control widget's class is `.komorebi-control-widget`, and the power popup is `.power-menu-compact`. Don't run `yasbc reload` right as the file watcher reloads (they collide and yasb exits; `yasbc start` fixes it).
 Known bug (filed 2026-09-26 as amnweb/yasb#1135): grouper `hide_empty` never hides a pill that contains `audio_visualizer` with `hide_idle`. The visualizer collapses to 0px wide instead of calling hide(), so an empty narrow media pill shows when nothing is playing. Check the issue for a fix before working around it.
