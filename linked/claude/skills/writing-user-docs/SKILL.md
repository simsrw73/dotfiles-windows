---
name: writing-user-docs
description: Use when writing or overhauling user-facing documentation for a library, tool or config (README, getting-started guide, tutorial, reference, troubleshooting), especially when readers range from beginners to experienced developers.
---

# Writing user docs

## Overview

Good user docs let a reader copy any example, run it, and see what the page
says they'll see. Build each page from runnable steps, simple to advanced, and
prove every example by running it exactly as written.

## Page recipe

Every page has these parts, in this order:

1. **Opening** (2–3 lines): who it's for, what it covers, what the reader can
   do by the end. For example, for an image-resizing tool:
   ```markdown
   **Audience:** photographers comfortable opening a terminal.
   **Topic:** batch-resizing photos with shrinkpic.
   **Goal:** resize a folder of photos for the web in one command.
   ```
2. **Quick start**: the smallest complete program that does something useful,
   how to run it, and what appears.
3. **Tasks**, simple to complex: one sentence of why, one complete example,
   then a numbered explanation of what each part does.
4. **Reference**: a table per function or option (name, type, default,
   description), plus returns and errors raised.
5. **Troubleshooting**: each error message or symptom, its cause, its fix.
6. **Safety**: what it reads, writes (with paths), runs and sends over the
   network, and what not to pass it. "None" is a valid answer per item.

A small project fits all six in one README. A larger one gets a short README
(what, picture, quick start, links) plus pages: tutorial, one guide per
feature, reference, troubleshooting. Add a page on the host language's basics
only when the audience includes beginners in it.

## Examples contract

- Each code block is a **complete program** (imports, setup, data) that runs
  when copied alone. Repeat setup instead of relying on an earlier block.
- Shown output is **copied from a real run**. Mark output that varies:
  `# e.g. 2026-10-04 09:15 ...`, or fix it (a fake clock, a temp folder).
- Use realistic scenarios and only options that exist in the code you read.

## Verify before claiming done

Run every code block exactly as it appears in the file, each in a fresh
directory with no state from other blocks, using a script that extracts and
runs them. If the project has a test runner, add that script (plus a check of
relative links and anchors) so the docs fail the build when they drift.

Reading the source is not running the example; a block that hasn't run isn't
done. Mark a deliberately partial snippet in the page (e.g. `<!-- fragment -->`
on the line before it) and skip it in the check.

## Style

- Active voice, second person, one idea per sentence.
- Define a term on first use; one name per thing.
- Commands and key combinations exactly as typed.
- Alt text on every image, describing what it shows.
- Link to the reference instead of repeating it.

## Common mistakes

| Mistake | Fix |
|---|---|
| Blocks share state (`client` set in block 1, used in block 4) | make each block a complete program |
| Sample output typed from memory | run it and paste the real output |
| Reference only, no path for a beginner | quick start and tasks before the reference |
| Options or defaults guessed | read them from the source |
| Silence on files written or data sent | add the Safety section |
