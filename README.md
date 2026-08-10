# Markdug

A tiny floating macOS app that renders Markdown beautifully. No Dock icon. Press Escape or Cmd+W to dismiss. Triggered by a hotkey via a **Shortcuts.app** shortcut — no admin rights required.

---

## What it does

```
ctrl+alt+space (Finder focused)  →  Shortcuts.app shortcut ("Toggle Markdug")  →  runs km-macro.sh
                                                                              →  gets selected file from Finder
                                                                              →  launches Markdug.app (floating)
                                                                              →  press Escape or Cmd+W to dismiss and quit
                                                                              →  focus Finder, ctrl+alt+space again to toggle closed
```

Note: the hotkey only fires while Finder is the focused app — pressing it while Markdug's own window is focused does nothing (click back into Finder first). Escape, Cmd+W, or the red traffic light always close the window regardless of focus.

Everything installs into your own home directory — the app, the CLI tool, and the hotkey. No `sudo`, no Homebrew, no admin password, no Accessibility permission grant.

---

## Prerequisites

### 1. Xcode Command Line Tools

You need the Swift compiler. If you don't have it:

```bash
xcode-select --install
```

A dialog will appear. Click Install. Takes a few minutes. (This doesn't need an admin password on most Macs — if it asks for one and you don't have it, ask whoever manages the machine to run this once.)

### 2. Find your macOS target version

This is the most important step — the build script needs to match your macOS version or the window won't appear.

```bash
swift --version
```

Look for the `Target:` line in the output. For example:

```
Target: arm64-apple-macosx26.0
```

The part you need is `macosx26.0` (or `macosx14.0`, `macosx15.0` etc depending on your Mac).

Open `build.sh` in a text editor and find these two lines:

```bash
-target arm64-apple-macosx15.0
```
```bash
-target x86_64-apple-macosx15.0
```

Replace `15.0` with whatever version your Mac reported. Both lines need updating.

---

## Install

```bash
git clone https://github.com/YOURUSERNAME/Markdug.git
cd Markdug
chmod +x build.sh && ./build.sh
```

The script will:
- Download marked.js (the Markdown parser, ~40kb)
- Compile the Swift app
- Install it to `~/Applications/Markdug.app`
- Create a `mdug` CLI tool at `~/.local/bin/mdug` (added to `PATH` automatically if it isn't already)

None of this touches `/Applications`, `/usr/local/bin`, or anything else outside your home directory.

**Test it works:**

```bash
mdug ~/path/to/any/file.md
```

(If `mdug: command not found`, restart your terminal — `build.sh` just added `~/.local/bin` to your `PATH`.)

A window should appear with rendered Markdown. Press Escape or Cmd+W to close.

---

## Hotkey setup (Shortcuts.app)

The hotkey is a **Shortcuts.app** shortcut running a Run Shell Script action — Apple's own automation app, no background daemon, no Homebrew, no Accessibility permission needed. It's built by hand in the Shortcuts app GUI (there's no install script for this part — Shortcuts don't have a simple committable file format the way the old Automator Quick Action did).

### Build the shortcut (one time)

1. **Shortcuts app → Settings → Advanced** → turn on **"Allow Running Scripts"**
2. New shortcut → name it **Toggle Markdug**
3. Add action: **Run Shell Script** — Shell: `/bin/bash`, Input: nothing, script:
   ```
   /bin/bash "$HOME/path/to/Markdug/km-macro.sh"
   ```
   (use this repo's actual path on your machine)
4. Select a `.md` file in Finder, then hit **Run (▶)** inside the Shortcuts editor to test it standalone before wiring up a hotkey. The first run will prompt a one-time Automation permission dialog (Shortcuts → Finder) — allow it.

### Bind the shortcut (one time)

Try the shortcut's own detail pane first — click its ⓘ icon and look for **"Add Keyboard Shortcut"**. If that's not available on your macOS version, fall back to Services:

1. In the shortcut's settings, enable **"Use as Quick Action"** / **"Show in Services Menu"**
2. **System Settings → Keyboard → Keyboard Shortcuts… → Services**
3. Find **Toggle Markdug**, double-click its shortcut column, and set your combo

No admin password needed either way — this is a standard per-user preference. Plain **⌥Space** may already be claimed by something else on your Mac; **⌃⌥Space** (ctrl+alt+space) is a safer bet if ⌥Space alone doesn't register.

### Test it

- Open Finder
- Click any `.md` file to select it (single click)
- Press your hotkey (e.g. ⌃⌥Space) → Markdug appears instantly
- Click back into Finder, press the hotkey again → it toggles closed

Or test independent of the hotkey entirely: `shortcuts run "Toggle Markdug"`

---

## Troubleshooting

**Window doesn't appear**

Almost always a macOS target version mismatch. Check `swift --version`, find the `Target:` line, and make sure `build.sh` matches. Then rebuild.

**"Markdug can't be opened because it's from an unidentified developer"**

Right-click the app in `~/Applications` → Open → Open anyway. You only need to do this once. This happens because the app isn't signed with an Apple Developer certificate — it's your own personal build.

**Hotkey doesn't trigger**

- Check you're pressing it with Finder focused — the shortcut is scoped to Finder, so it does nothing while Markdug or any other app is active (click into Finder first, or select a `.md` file, then press the hotkey)
- Test the shortcut logic directly, bypassing the hotkey entirely: `shortcuts run "Toggle Markdug"`
- If that does nothing either, check Shortcuts → Settings → Advanced → **"Allow Running Scripts"** is still on, and System Settings → Privacy & Security → Automation → Shortcuts → Finder is still granted
- If the CLI test works but the hotkey doesn't, re-check the binding: the shortcut's own ⓘ detail pane, or System Settings → Keyboard → Keyboard Shortcuts… → Services → **Toggle Markdug**
- Some combinations (plain ⌥Space, for instance) may already be claimed elsewhere — try ⌃⌥Space or another combination in the same binding panel

**`mdug: command not found`**

`~/.local/bin` isn't on your `PATH` yet in this shell — restart your terminal, or run `source ~/.zshrc`.

**"Open in Sublime" button does nothing**

It calls `open -a "Sublime Text"`, so Sublime Text just needs to be installed in a location macOS can find it (Spotlight-visible, e.g. `/Applications` or `~/Applications`) — no CLI shim or `PATH` setup required.

**Images in Markdown aren't showing**

Relative image paths work if the images are in the same folder as the `.md` file. Absolute paths always work.

---

## Customisation

The CSS lives in `AppDelegate.swift` in the `html` string inside `openFile()`. Edit it and re-run `build.sh` to apply changes.

Window size defaults to 900×700. Change the `width` and `height` constants in `applicationDidFinishLaunching`.

---

## Uninstalling

```bash
rm -rf ~/Applications/Markdug.app
rm -f ~/.local/bin/mdug
```

Then delete the **Toggle Markdug** shortcut in Shortcuts.app, and remove its keyboard binding (its own ⓘ pane, or System Settings → Keyboard → Keyboard Shortcuts… → Services) if you want.
