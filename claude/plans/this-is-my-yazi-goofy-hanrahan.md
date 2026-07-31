# Fix: `min-preview` keybinding never fires

## Context

In this yazi config, the `toggle-pane` plugin works for hiding the parent pane
(`<F9>` → `min-parent`) and for maximizing the preview pane (`<C-F10>` →
`max-preview`), but the binding meant to hide/show the preview pane does
nothing.

Root cause is a typo, not a plugin or version problem: the key spec on
`keymap.toml:198` is `"<F10"` — the closing `>` is missing. Yazi does not
error on this; an unclosed `<` falls back to being parsed as a literal
character sequence (`<`, `F`, `1`, `0`), so the rest of the keymap loads
normally and only this one binding is unreachable by pressing F10.

This explains the symptom precisely: the two bindings that work are exactly
the two whose key specs are well-formed.

Ruled out during investigation:

- **Version mismatch** — `plugins/toggle-pane.yazi/main.lua` declares
  `@since 26.1.22`; installed yazi is 26.5.6. Compatible.
- **Conflicting binding** — `<F10` is the only F10 entry in `keymap.toml`.
- **Zero-width preview** — `yazi.toml:7` sets `ratio = [1, 4, 3]`, so preview
  has a nonzero width for `min-preview` to toggle away from.
- **Startup state conflict** — `init.lua:2` calls
  `require("toggle-pane"):entry("min-parent")`, which pre-seeds the plugin's
  `st.new`/`st.old`. The plugin stores the full 3-element ratio in both, so a
  later `min-preview` correctly resolves to `[0, 4, 0]`. No interference.

## Change

**File: `C:\Users\simsr\.config\yazi\keymap.toml`** (line 198)

Add the missing `>`:

```toml
{ on   = "<F10>", run  = "plugin toggle-pane min-preview", desc = "Show or hide the preview pane" },
```

That is the entire fix — a one-character edit. No changes to `init.lua`,
`yazi.toml`, or the plugin itself.

## Verification

1. Restart yazi (keymap is read at startup).
2. Press `~` or `<F1>` to open help and confirm the entry now renders as
   `F10  Show or hide the preview pane`. If the key spec were still malformed,
   help would show the literal character sequence instead.
3. Press `F10` — the preview pane should collapse; press again — it returns to
   width 3.
4. Regression check on the neighbours: `F9` still toggles the parent pane, and
   `Ctrl+F10` still maximizes/restores the preview.
5. Combination check: with parent hidden via `F9`, `F10` should still collapse
   the preview (both panes hidden, current fills the screen). This confirms the
   `init.lua` startup `min-parent` call isn't clobbering the toggle state.

## If F10 still does nothing after the fix

The remaining suspect is the terminal, not yazi — some Windows terminals
intercept bare `F10` (a legacy conhost convention where F10 activates the
window menu) and never forward it to the application. Distinguishing test:
`Ctrl+F10` already works, so if `F10` alone stays dead while help shows the
binding correctly, the key is being swallowed upstream.

Two ways to confirm and resolve:

- Check the terminal's key-binding settings for an `F10` entry and unbind it.
- Or sidestep it by rebinding to a key the terminal doesn't claim — e.g. `T`,
  which is the plugin README's own suggestion and is currently unbound in this
  keymap:

  ```toml
  { on   = "T", run  = "plugin toggle-pane min-preview", desc = "Show or hide the preview pane" },
  ```
