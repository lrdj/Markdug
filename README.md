# Markdug

A tiny floating macOS app that renders Markdown beautifully. No Dock icon. Press Escape or Cmd+W to dismiss. Triggered by a hotkey via Keyboard Maestro.

---

## What it does

```
alt+space  →  Keyboard Maestro  →  gets selected file from Finder
                                →  calls: mdug /path/to/file.md
                                →  Markdug.app appears (floating)
                                →  press Escape or Cmd+W to dismiss and quit
```

---

## Prerequisites

### 1. Xcode Command Line Tools

You need the Swift compiler. If you don't have it:

```bash
xcode-select --install
```

A dialog will appear. Click Install. Takes a few minutes.

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

## Keyboard Maestro setup

### Install Keyboard Maestro

Buy/download from https://www.keyboardmaestro.com (~$36, one-time). The engine runs in the background and is very lightweight.

Set it to launch at login: click the Keyboard Maestro Engine icon in your menu bar → Launch Engine at Login.

### Create the macro

1. Open Keyboard Maestro
2. Click **+** to create a new macro
3. Name it `Markdown Viewer`
4. Add trigger: **Hot Key trigger** → press `⌥Space` (alt+space)
5. Add action: **Execute Shell Script**
6. Set the output dropdown to **Asynchronously**
7. Paste this script:

```bash
#!/bin/bash
FILEPATH=$(osascript -e '
tell application "Finder"
    set sel to selection
    if sel is {} then
        return ""
    else
        return POSIX path of (item 1 of sel as alias)
    end if
end tell
')

if [ -z "$FILEPATH" ]; then
    osascript -e 'display notification "No file selected in Finder" with title "Markdown Viewer"'
    exit 0
fi

case "$FILEPATH" in
    *.md|*.markdown|*.mdx|*.mdown)
        /Applications/Markdug.app/Contents/MacOS/Markdug "$FILEPATH" &
        ;;
    *)
        osascript -e "display notification \"Not a Markdown file\" with title \"Markdown Viewer\""
        ;;
esac
```

8. Save the macro

### Test it

- Open Finder
- Click any `.md` file to select it (single click)
- Press ⌥Space
- Markdug should appear instantly

---

## Troubleshooting

**Window doesn't appear**

Almost always a macOS target version mismatch. Check `swift --version`, find the `Target:` line, and make sure `build.sh` matches. Then rebuild.

**"Markdug can't be opened because it's from an unidentified developer"**

Right-click the app in /Applications → Open → Open anyway. You only need to do this once. This happens because the app isn't signed with an Apple Developer certificate — it's your own personal build.

**⌥Space doesn't trigger**

- Check the Keyboard Maestro macro is enabled (green dot next to it)
- Make sure Keyboard Maestro Engine is running (check menu bar)
- Some apps capture ⌥Space — try a different hotkey like ⌃⌥Space

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
```

Then delete the Keyboard Maestro macro.
