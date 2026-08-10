# Trying Shortcuts.app as the ⌥Space trigger

Pivoting the hotkey trigger from the Automator Quick Action to a
**Shortcuts.app** shortcut, to try on the standard (non-admin) account.
Debugging the Quick Action there is difficult (no copy/paste between
accounts), so this is structured as a sequence of checkpoints — each step
proves itself before moving to the next, so a failure narrows down to exactly
one layer.

## 1. Enable script execution first (easy to miss)

Shortcuts → Settings (or Shortcuts menu → Settings) → Advanced → turn on
**"Allow Running Scripts"**. Without this the Run Shell Script action either
won't be offered or will silently fail. Per-user toggle, no admin needed.

## 2. Build the shortcut

- Shortcuts.app → new shortcut → name it `Toggle Markdug`
- Add action: search for **"Run Shell Script"**
- Shell: `/bin/bash` (or `/bin/zsh`), Input: **nothing** (`km-macro.sh` gets
  the file itself via AppleScript, it doesn't need stdin)
- Script content: the full path to `km-macro.sh` on *this* account, e.g.
  ```
  /bin/bash "$HOME/Sites/Markdug/km-macro.sh"
  ```
  (adjust to wherever the repo actually lives on the standard account)

## 3. Test it standalone — before touching any hotkey

Select a `.md` file in Finder, then in the Shortcuts editor hit **Run** (▶)
on the shortcut itself. This isolates the shell-script layer from the
trigger layer.

If Markdug doesn't appear, check for a permissions prompt — the first
`osascript`/AppleScript call to Finder from Shortcuts triggers a one-time
**Automation** consent dialog (System Settings → Privacy & Security →
Automation → Shortcuts → Finder). That's a normal user-consent toggle, not an
admin gate, but easy to dismiss by accident and then wonder why nothing
happens.

## 4. Assign the keyboard shortcut

In the shortcut's detail pane there's usually an **"Add Keyboard Shortcut"**
field directly in the Shortcuts app (click the ⓘ / details icon on the
shortcut) — try that first, simpler than going through Services. If it's not
offered on this macOS version, fall back to: toggle **"Use as Quick Action"**
/ **"Show in Services Menu"** in the shortcut's settings, then bind it the
same way as the old Quick Action — System Settings → Keyboard → Keyboard
Shortcuts → Services.

## 5. Test via CLI, bypassing the hotkey entirely

```bash
shortcuts run "Toggle Markdug"
```

This is the `automator ~/Library/Services/...` equivalent — confirms the
shortcut fires correctly independent of whatever ⌥Space is or isn't doing.
If this works but ⌥Space doesn't, the bug is purely in the key-binding step
(4), not the shortcut logic.

## Report back

At whichever checkpoint something breaks, note which step failed and what
was observed (nothing happened / permission prompt / wrong error) — that
narrows it down far faster than "it doesn't work."
