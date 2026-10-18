---
name: arch-review-output
description: "improve-codebase-architecture reports go in the project root as markdown arch-imp-audit-(claude).md, not HTML in temp"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 46f7b924-1be7-4a79-83ae-220caba4d3ee
  modified: 2026-10-06T20:41:23.356Z
---

For `/improve-codebase-architecture` runs in DotForge, write the report as a markdown file in the project root named `arch-imp-audit-(claude).md` (Mermaid diagrams inline), not the skill's default HTML file in %TEMP%.

**Why:** User overrode the skill's location/format on 2026-10-06; other models' audits sit beside it (`arch-imp-audit.md`, `audit.*.md`) for comparison.
**How to apply:** Skip the HTML scaffold; same candidate-card content in markdown. Related: [[typora-doc-review]].
