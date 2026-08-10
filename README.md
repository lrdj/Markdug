# Markdug

A tiny floating macOS app that renders Markdown beautifully. No Dock icon. Press Escape or Cmd+W to dismiss. Triggered by a hotkey via a macOS **Quick Action** — no admin rights required.

---

## What it does

```
alt+space  →  Quick Action ("Toggle Markdug")  →  runs km-macro.sh
                                               →  gets selected file from Finder
                                               →  launches Markdug.app (floating)
                                               →  press Escape or Cmd+W to dismiss and quit
                                               →  alt+space again toggles it closed
```

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

## Hotkey setup (Quick Action)

The ⌥Space hotkey is a macOS **Quick Action** — Apple's own mechanism for binding a keyboard shortcut to a script, configured entirely in System Settings. It needs no background daemon, no Homebrew, and no Accessibility permission, because the OS itself owns the global shortcut, not the script.

### One command

```bash
./install-trigger.sh
```

This copies this repo's `Toggle Markdug.workflow` into `~/Library/Services`, points it at this repo's `km-macro.sh`, and refreshes the Services menu.

### Bind the shortcut (one time)

1. **System Settings → Keyboard → Keyboard Shortcuts… → Services**
2. Find **Toggle Markdug** under **General**
3. Double-click its shortcut column and press **⌥Space**

No admin password needed — assigning a keyboard shortcut to a Service is a standard per-user preference.

### Test it

- Open Finder
- Click any `.md` file to select it (single click)
- Press ⌥Space → Markdug appears instantly
- Press ⌥Space again → it toggles closed

---

## Troubleshooting

**Window doesn't appear**

Almost always a macOS target version mismatch. Check `swift --version`, find the `Target:` line, and make sure `build.sh` matches. Then rebuild.

**"Markdug can't be opened because it's from an unidentified developer"**

Right-click the app in `~/Applications` → Open → Open anyway. You only need to do this once. This happens because the app isn't signed with an Apple Developer certificate — it's your own personal build.

**⌥Space doesn't trigger**

- Check the Quick Action is installed: `ls ~/Library/Services` should list `Toggle Markdug.workflow`
- Check the shortcut is actually bound: System Settings → Keyboard → Keyboard Shortcuts… → Services → General → **Toggle Markdug**
- If it's not there at all, re-run `./install-trigger.sh` — it refreshes the Services cache
- Some apps capture ⌥Space — bind a different combination in the same Services panel instead
- You can test the Quick Action in isolation, without the hotkey, by running:
  `automator ~/Library/Services/Toggle\ Markdug.workflow`

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
rm -rf ~/Library/Services/"Toggle Markdug.workflow"
/System/Library/CoreServices/pbs -update
```

Then remove the ⌥Space binding in System Settings → Keyboard → Keyboard Shortcuts… → Services (if you want).
