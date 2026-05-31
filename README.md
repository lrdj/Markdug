# Markdug

A tiny floating macOS app that renders Markdown beautifully. No Dock icon. Press Escape or Cmd+W to dismiss. Triggered by a hotkey via **skhd** (a free, open-source hotkey daemon).

---

## What it does

```
alt+space  →  skhd hotkey daemon  →  runs km-macro.sh
                                  →  gets selected file from Finder
                                  →  launches Markdug.app (floating)
                                  →  press Escape or Cmd+W to dismiss and quit
                                  →  alt+space again toggles it closed
```

---

## Prerequisites

### 1. Xcode Command Line Tools

You need the Swift compiler. If you don't have it:

```bash
xcode-select --install
```

A dialog will appear. Click Install. Takes a few minutes.

### 2. Sublime Text CLI (`subl`)

The "Open in Sublime" button requires the `subl` CLI. Run this once:

```bash
sudo ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /usr/local/bin/subl
```

### 3. Find your macOS target version

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
-target arm64-apple-macosx26.0
```
```bash
-target x86_64-apple-macosx26.0
```

Replace `26.0` with whatever version your Mac reported. Both lines need updating.

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
- Install it to /Applications/Markdug.app
- Create a `mdug` CLI tool at /usr/local/bin/mdug

**Test it works:**

```bash
mdug ~/path/to/any/file.md
```

A window should appear with rendered Markdown. Press Escape or Cmd+W to close.

---

## Hotkey setup (skhd)

The ⌥Space hotkey is provided by [skhd](https://github.com/koekeishiya/skhd) — a tiny, free, open-source hotkey daemon. It runs in the background as a login agent. No licence, no nagware. (This replaced Keyboard Maestro, whose lapsed-trial dormancy kept silently breaking the trigger.)

### One command

```bash
./install-trigger.sh
```

This installs skhd via Homebrew, writes `~/.skhdrc` (binding ⌥Space to this repo's `km-macro.sh`), and starts the login service.

### Grant Accessibility permission (one time)

skhd can't capture keystrokes until macOS lets it. The installer prints this, but to do it manually:

1. **System Settings → Privacy & Security → Accessibility**
2. Click **+**, press **⌘⇧G**, paste `/opt/homebrew/bin/skhd`, add it
3. Toggle it **on**
4. Back in the terminal: `skhd --restart-service`

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

Right-click the app in /Applications → Open → Open anyway. You only need to do this once. This happens because the app isn't signed with an Apple Developer certificate — it's your own personal build.

**⌥Space doesn't trigger**

- Is the daemon running? `pgrep -lx skhd` (should print a PID)
- Check the error log: `tail /tmp/skhd_$USER.err.log`. The line
  `must be run with accessibility access` means the Accessibility permission was
  lost (common after a macOS update) — re-grant it for `/opt/homebrew/bin/skhd`
  and run `skhd --restart-service`. An empty log = it's capturing fine.
- Some apps capture ⌥Space — try a different hotkey by editing `~/.skhdrc`
  (e.g. `ctrl + alt - space`) then `skhd --restart-service`

**Images in Markdown aren't showing**

Relative image paths work if the images are in the same folder as the `.md` file. Absolute paths always work.

---

## Customisation

The CSS lives in `AppDelegate.swift` in the `html` string inside `openFile()`. Edit it and re-run `build.sh` to apply changes.

Window size defaults to 900×700. Change the `width` and `height` constants in `applicationDidFinishLaunching`.

---

## Uninstalling

```bash
rm -rf /Applications/Markdug.app
sudo rm /usr/local/bin/mdug
skhd --stop-service
brew uninstall skhd        # optional — only if nothing else uses skhd
rm -f ~/.skhdrc
```

Then remove `/opt/homebrew/bin/skhd` from System Settings → Privacy & Security → Accessibility.
