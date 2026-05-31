# Markdug — Developer Documentation

This file is for AI assistants. It describes the architecture, design decisions, and current state of the Markdug project.

---

## What Markdug is

A minimal macOS app that renders Markdown files in a floating window. Triggered by a keyboard shortcut via **skhd** (a free, open-source hotkey daemon — replaced Keyboard Maestro on 2026-05-31). Shows a Dock icon while open. Press Escape or Cmd+W to quit.

It exists to fill a specific gap: the user edits `.md` files in Sublime Text and views them canonically on GitHub, but needed a fast zero-friction way to read Markdown locally without opening an editor or browser.

---

## How it works

```
User selects .md file in Finder
  → presses ⌥Space
  → skhd (hotkey daemon) fires the bound command: km-macro.sh
  → checks if Markdug is already running (if yes: quits it — toggle behaviour)
  → if no: calls /Applications/Markdug.app/Contents/MacOS/Markdug /path/to/file.md
  → Markdug window appears with rendered Markdown
  → user presses Escape, Cmd+W, or clicks the red traffic light to quit
```

The trigger script (`km-macro.sh`) is unchanged from the Keyboard Maestro era —
only the thing that binds ⌥Space to it changed (KM → skhd). The filename is kept
for continuity; it is no longer Keyboard Maestro-specific.

---

## Repository structure

```
Markdug/
├── CLAUDE.md                  ← you are here
├── README.md                  ← user-facing install instructions
├── build.sh                   ← compiles and installs the app
├── install-trigger.sh         ← installs skhd + ~/.skhdrc (the ⌥Space hotkey)
├── skhdrc                      ← committed skhd config (copied to ~/.skhdrc)
├── km-macro.sh                ← the trigger script skhd runs (reads Finder selection, launches app)
└── Markdug/
    ├── AppDelegate.swift      ← the entire app (~175 lines)
    ├── Info.plist             ← app metadata, URL scheme registration
    └── AppIcon.icns           ← compiled icon (source was a 1024×1024 Display P3 PNG)
```

---

## Architecture

### The app

A single-file Swift app. No Xcode project, no storyboards, no SwiftUI. Just `AppDelegate.swift` compiled directly with `swiftc`.

**Key decisions:**
- Uses `NSApplication` / `NSApplicationDelegate` pattern with an explicit entry point at the bottom of the file (not `@main`) — this was required to work correctly on macOS 26
- `NSApp.setActivationPolicy(.regular)` — shows in Dock while open, disappears when quit
- `WKWebView` renders the HTML/CSS/JS output
- `marked.js` (bundled in the app's Resources folder) parses Markdown to HTML at runtime
- CSS is GitHub-flavoured, embedded as a Swift string in `openFile()`
- Dark mode is handled via `@media (prefers-color-scheme: dark)` in the CSS

### The build script

`build.sh` does everything in one shot:
1. Creates the `.app` bundle directory structure manually
2. Downloads `marked.min.js` from jsDelivr CDN into `Resources/`
3. Downloads `highlight.min.js`, `highlight.min.css`, `highlight-dark.min.css` from cdnjs into `Resources/`
4. Compiles `AppDelegate.swift` with `swiftc` directly (no Xcode)
5. Copies `Info.plist` into the bundle
6. Writes `Contents/PkgInfo` (`APPL????`)
7. Copies `AppIcon.icns` into `Resources/`
8. Installs to `/Applications/Markdug.app`
9. Ad-hoc code signs the installed bundle (`codesign --force --deep --sign -`)
10. Registers the URL scheme with Launch Services
11. Flushes icon caches (`killall Finder && killall Dock`)
12. Creates `/usr/local/bin/mdug` CLI tool (Python script that calls `open -a Markdug --args <path>`)

### The CLI tool

`/usr/local/bin/mdug` is a small Python 3 script installed by `build.sh`. It takes a file path, resolves it to an absolute path, and launches the app via `open -a Markdug --args`.

### The hotkey trigger (skhd)

Since 2026-05-31 the ⌥Space hotkey is supplied by **skhd**, a tiny free
open-source hotkey daemon (`brew install koekeishiya/formulae/skhd`). It runs as
a LaunchAgent (auto-starts at login) and needs a one-time Accessibility grant.

- Config lives in `~/.skhdrc` (committed to the repo as `skhdrc`); the single
  binding is `alt - space : ~/Sites/Markdug/km-macro.sh`.
- `install-trigger.sh` installs skhd, writes `~/.skhdrc` (rewriting the path to
  wherever the repo was cloned), and starts the service.
- This replaced Keyboard Maestro, whose lapsed-trial dormancy was a recurring
  single point of failure (see the gotcha below and `refactor-loose-KBM-May17.md`).

`km-macro.sh` itself (the script skhd runs) is unchanged. Key behaviours:
- Uses AppleScript to get the selected file path from Finder
- Checks if Markdug is running via `pgrep` — if yes, kills it (toggle)
- Checks file extension is `.md`, `.markdown`, `.mdx`, or `.mdown`
- Launches via the full app binary path: `/Applications/Markdug.app/Contents/MacOS/Markdug "$FILEPATH" &`

**skhd gotchas:**
- If ⌥Space stops working, check the daemon is running (`pgrep -lx skhd`) and the
  error log: `tail /tmp/skhd_$USER.err.log`. The message
  `must be run with accessibility access` means the Accessibility permission was
  lost (common after a major OS update) — re-grant it for `/opt/homebrew/bin/skhd`
  and run `skhd --restart-service`.
- An **empty** err log after a restart = accessibility OK, daemon capturing.

---

## Key technical gotchas

### macOS target version
The `swiftc` target in `build.sh` must match the developer's macOS version. On macOS 26 this is `arm64-apple-macosx26.0`. On older Macs it will be `macosx14.0`, `macosx15.0` etc. Mismatching this causes the window to silently not appear — the app launches but shows nothing.

### @main vs explicit entry point
Using `@main` on the AppDelegate class with `-parse-as-library` flag caused silent window failures on macOS 26. The fix was to remove `@main` and add an explicit entry point at the bottom of the file:
```swift
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

### NSTitlebarAccessoryViewController adds height
Using `NSTitlebarAccessoryViewController` to add the "Open in Sublime" button created an extra row below the title bar. The fix was to get the traffic light button's superview and add the button directly to it using Auto Layout constraints.

### marked.js must be in Resources
`Bundle.main.path(forResource: "marked.min", ofType: "js")` looks in the app bundle's Resources/ folder. The build script downloads it there. If it's missing, the app falls back to a `<pre>` tag renderer.

### Invalid Info.plist silently breaks icons (and other metadata)
If the app icon (or URL scheme, or version string) stops working, run `plutil -lint` on the plist first:
```bash
plutil -lint /Applications/Markdug.app/Contents/Info.plist
```
An invalid plist does **not** prevent the app from launching — it silently falls back to defaults for everything it can't read. The Markdug icon was invisible for this reason: `</dict>` instead of `</array>` on line 39 made the entire plist unreadable.

### Hand-built bundles need PkgInfo + codesign + cache flush
For a hand-built `.app` bundle (no Xcode), three steps are needed for the icon to display reliably:
1. `Contents/PkgInfo` file containing the literal bytes `APPL????`
2. `codesign --force --deep --sign -` applied after install
3. `killall Finder && killall Dock` after `lsregister` to flush icon caches

All three are now in `build.sh`.

### (Historical) Lapsed Keyboard Maestro trial silently disabled the trigger
**Resolved 2026-05-31 by moving the hotkey to skhd — kept here for context.**
When the trigger was Keyboard Maestro, a lapsed trial/licence silently stopped
the KM Engine from executing macros: ⌥Space never fired, and the `.md` file fell
through to whatever else handled it (the "full-screen black window with an 'open
markdown editor' button" symptom — that string is **not** in this codebase). The
recurring "Continue Trial" popup was the warning sign.

That single point of failure is gone now that skhd (free, no licence) supplies
the hotkey. If ⌥Space misbehaves today, see the **skhd gotchas** above, not this
section. The app itself can always be proven healthy independent of the trigger:
   `/Applications/Markdug.app/Contents/MacOS/Markdug ~/Sites/Markdug/README.md`

See `refactor-loose-KBM-May17.md` for the original investigation write-up.

---

## Current features

- Renders GitHub-Flavoured Markdown (via marked.js)
- Syntax highlighting in fenced code blocks (highlight.js 11.9.0 — GitHub light / GitHub Dark themes)
- Dark mode support
- Custom app icon (displays in Finder and Dock)
- Window size and position remembered between launches
- "Open in Sublime" pill button in title bar (calls `/usr/local/bin/subl`)
- Toggle behaviour via skhd hotkey (⌥Space opens, ⌥Space again closes)
- Escape or Cmd+W quits the app entirely
- Closing the window quits the app entirely

---

## Planned features

- Trigger from Sublime Text (not just Finder) — open the currently active file
- Remove Dock icon (.accessory activation policy) — previously caused silent window failure, needs revisiting

## Done

- ~~KM-independent trigger~~ — **done 2026-05-31**: replaced Keyboard Maestro with
  skhd (see `install-trigger.sh`, `skhdrc`). Removes the licence/Engine single
  point of failure.

---

## Environment

- Developer machine: macOS 26.3, Apple Silicon
- Swift 6.2.3
- Sublime Text (with `subl` CLI at `/usr/local/bin/subl`)
- skhd for hotkey triggering (`brew install koekeishiya/formulae/skhd`)
- marked.js loaded from jsDelivr CDN at build time
- highlight.js 11.9.0 loaded from cdnjs at build time

---

## Common tasks

### Rebuild and reinstall after editing AppDelegate.swift
```bash
cd ~/path/to/Markdug && ./build.sh
```

### Test the app directly
```bash
/Applications/Markdug.app/Contents/MacOS/Markdug ~/path/to/file.md
```

### Set up / repair the ⌥Space hotkey (skhd)
```bash
cd ~/path/to/Markdug && ./install-trigger.sh   # then grant Accessibility to skhd
skhd --restart-service                           # after granting/repairing permission
pgrep -lx skhd                                   # is the daemon running?
tail /tmp/skhd_$USER.err.log                     # empty = accessibility OK
```

### Test the CLI
```bash
mdug ~/path/to/file.md
```

### Check if Markdug is running
```bash
pgrep -x Markdug
```

### Kill Markdug
```bash
pkill Markdug
```

### Regenerate the app icon from a new PNG
The source PNG must be 1024×1024. If it's Display P3 (common for screenshots and exports from
design tools), convert to sRGB first — macOS icon services can misread P3 assets.

```bash
# Convert colour space (safe to run even if already sRGB)
sips --matchTo '/System/Library/ColorSync/Profiles/sRGB Profile.icc' input.png --out /tmp/icon_srgb.png

# Generate all required sizes
mkdir -p /tmp/app.iconset
for size in 16 32 128 256 512; do
    sips -z $size $size /tmp/icon_srgb.png --out /tmp/app.iconset/icon_${size}x${size}.png
    sips -z $((size*2)) $((size*2)) /tmp/icon_srgb.png --out /tmp/app.iconset/icon_${size}x${size}@2x.png
done

# Compile
iconutil -c icns /tmp/app.iconset -o Markdug/AppIcon.icns

# Rebuild the app
./build.sh
```
