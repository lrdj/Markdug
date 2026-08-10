# Markdug — Developer Documentation

This file is for AI assistants. It describes the architecture, design decisions, and current state of the Markdug project.

---

## What Markdug is

A minimal macOS app that renders Markdown files in a floating window. Triggered by a keyboard shortcut via a macOS **Quick Action** (an Automator Service — replaced skhd on 2026-08-10, because skhd needs Homebrew + an Accessibility grant, neither available on a machine without admin rights). Shows a Dock icon while open. Press Escape or Cmd+W to quit.

It exists to fill a specific gap: the user edits `.md` files in Sublime Text and views them canonically on GitHub, but needed a fast zero-friction way to read Markdown locally without opening an editor or browser.

Everything — the app, the CLI tool, and the hotkey — installs entirely within the user's home directory. No `sudo`, no admin password, no Homebrew, no Accessibility permission grant, anywhere in the install path. This was a hard requirement from 2026-08-10 onward: the user works from a machine with a standard (non-admin) account, where `/Applications`, `/usr/local/bin`, Homebrew, and the Accessibility permission dialog are all unavailable.

---

## How it works

```
User selects .md file in Finder
  → presses ⌥Space
  → macOS dispatches the shortcut to the "Toggle Markdug" Quick Action (a Service)
  → the Quick Action runs km-macro.sh
  → checks if Markdug is already running (if yes: quits it — toggle behaviour)
  → if no: calls ~/Applications/Markdug.app/Contents/MacOS/Markdug /path/to/file.md
  → Markdug window appears with rendered Markdown
  → user presses Escape, Cmd+W, or clicks the red traffic light to quit
```

`km-macro.sh` is unchanged in spirit across every trigger mechanism this project
has used (Keyboard Maestro → skhd → Quick Action) — only the thing that invokes
it changed. The filename is kept for continuity.

---

## Repository structure

```
Markdug/
├── CLAUDE.md                  ← you are here
├── README.md                  ← user-facing install instructions
├── build.sh                   ← compiles and installs the app (all to $HOME, no root)
├── install-trigger.sh         ← installs the "Toggle Markdug" Quick Action into ~/Library/Services
├── Toggle Markdug.workflow/   ← committed Automator Quick Action bundle (Info.plist + document.wflow)
├── km-macro.sh                ← the trigger script the Quick Action runs (reads Finder selection, launches app)
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
- "Open in Sublime" calls `open -a "Sublime Text" <path>` rather than a `subl` CLI shim — `open -a` needs no CLI to be installed anywhere on `PATH`, so it works with zero setup regardless of admin rights

### The build script

`build.sh` does everything in one shot, entirely inside `$HOME` — nothing requires root:
1. Creates the `.app` bundle directory structure manually
2. Downloads `marked.min.js` from jsDelivr CDN into `Resources/`
3. Downloads `highlight.min.js`, `highlight.min.css`, `highlight-dark.min.css` from cdnjs into `Resources/`
4. Compiles `AppDelegate.swift` with `swiftc` directly (no Xcode)
5. Copies `Info.plist` into the bundle
6. Writes `Contents/PkgInfo` (`APPL????`)
7. Copies `AppIcon.icns` into `Resources/`
8. Installs to `~/Applications/Markdug.app`
9. Ad-hoc code signs the installed bundle (`codesign --force --deep --sign -`)
10. Registers the URL scheme with Launch Services (`lsregister -f`, per-user, no root needed)
11. Flushes icon caches (`killall Finder && killall Dock` — kills the user's own processes, no root needed)
12. Creates `~/.local/bin/mdug` CLI tool (Python script that calls `open -a Markdug --args <path>`), adding `~/.local/bin` to `PATH` in `~/.zshrc` if it isn't there already

### The CLI tool

`~/.local/bin/mdug` is a small Python 3 script installed by `build.sh`. It takes a file path, resolves it to an absolute path, and launches the app via `open -a Markdug --args`. `open -a` finds apps in `~/Applications` automatically, same as `/Applications` — no change needed there for the move to a per-user install location.

### The hotkey trigger (Quick Action)

Since 2026-08-10 the ⌥Space hotkey is supplied by a macOS **Quick Action**
(`Toggle Markdug.workflow`, an Automator Service bundle committed to the repo).
Quick Actions are a first-class OS feature: assigning one a global keyboard
shortcut happens entirely in **System Settings → Keyboard → Keyboard
Shortcuts… → Services**, by any standard account, with no admin password —
because the OS itself owns the global-shortcut dispatch, unlike a background
daemon (skhd, Keyboard Maestro) that needs Accessibility permission to capture
raw key events itself.

- The bundle lives at `Toggle Markdug.workflow/` in the repo, with the shell
  command in `Contents/document.wflow` containing the placeholder
  `__MACRO_PATH__`.
- `install-trigger.sh` copies the bundle to `~/Library/Services/`, replaces
  `__MACRO_PATH__` with this repo's actual `km-macro.sh` path (via `sed`, same
  pattern the old `~/.skhdrc` generation used), and runs
  `/System/Library/CoreServices/pbs -update` to refresh the Services cache.
- Binding the actual shortcut (⌥Space) is a one-time **manual step** in System
  Settings — it can't be scripted, but it needs nothing beyond what any
  logged-in account already has.

**Building/verifying the workflow bundle:** the `document.wflow` XML format is
undocumented and easy to get subtly wrong (this project has direct history of
silently-broken plists — see the Info.plist gotcha below). Before trusting a
hand-written one, verify it actually executes:
```bash
automator "Toggle Markdug.workflow"   # runs the workflow's actions directly, no Services registration needed
```
and verify it registers correctly as a Service with:
```bash
/System/Library/CoreServices/pbs -update
/System/Library/CoreServices/pbs -dump | grep -A5 -i markdug
```

`km-macro.sh` itself (the script the Quick Action runs) behaviour is unchanged:
- Uses AppleScript to get the selected file path from Finder
- Checks if Markdug is running via `pgrep` — if yes, kills it (toggle)
- Checks file extension is `.md`, `.markdown`, `.mdx`, or `.mdown`
- Launches via the full app binary path: `~/Applications/Markdug.app/Contents/MacOS/Markdug "$FILEPATH" &`

**Quick Action gotchas:**
- If ⌥Space stops working, first check the Quick Action is actually installed:
  `ls ~/Library/Services` should list `Toggle Markdug.workflow`.
- If it's installed but not listed in System Settings → Keyboard Shortcuts →
  Services, re-run `install-trigger.sh` to refresh the Services cache
  (`pbs -update`), or log out and back in.
- If it's listed but ⌥Space does nothing, test the Quick Action directly
  (bypassing the hotkey and Services layer entirely) with
  `automator ~/Library/Services/Toggle\ Markdug.workflow` — if that doesn't
  launch Markdug, the bug is in `km-macro.sh` or the app, not the trigger.

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
plutil -lint ~/Applications/Markdug.app/Contents/Info.plist
```
An invalid plist does **not** prevent the app from launching — it silently falls back to defaults for everything it can't read. The Markdug icon was invisible for this reason: `</dict>` instead of `</array>` on line 39 made the entire plist unreadable. The same class of failure applies to `Toggle Markdug.workflow/Contents/Info.plist` and `document.wflow` — `plutil -lint` both before assuming the Quick Action is broken elsewhere.

### Hand-built bundles need PkgInfo + codesign + cache flush
For a hand-built `.app` bundle (no Xcode), three steps are needed for the icon to display reliably:
1. `Contents/PkgInfo` file containing the literal bytes `APPL????`
2. `codesign --force --deep --sign -` applied after install
3. `killall Finder && killall Dock` after `lsregister` to flush icon caches

All three are now in `build.sh`. None require root — ad-hoc signing and killing the user's own Finder/Dock processes both work fine on a standard account.

### (Historical) Lapsed Keyboard Maestro trial silently disabled the trigger
**Resolved 2026-05-31 by moving the hotkey to skhd.**
When the trigger was Keyboard Maestro, a lapsed trial/licence silently stopped
the KM Engine from executing macros: ⌥Space never fired, and the `.md` file fell
through to whatever else handled it (the "full-screen black window with an 'open
markdown editor' button" symptom — that string is **not** in this codebase). The
recurring "Continue Trial" popup was the warning sign.

See `refactor-loose-KBM-May17.md` for the original investigation write-up.

### (Historical) skhd required Homebrew + Accessibility — broke on a no-admin machine
**Resolved 2026-08-10 by moving the hotkey to a Quick Action — kept here for context.**
skhd was a real improvement over Keyboard Maestro (free, no licence dormancy),
but it still had two dependencies that assume an admin account: installing it
needed Homebrew (which needs `sudo` to create `/opt/homebrew` from scratch), and
capturing the hotkey needed a one-time grant in System Settings → Privacy &
Security → Accessibility — a dialog that **requires an admin password**
regardless of `sudo` access, even for the account's own settings.

Neither is available on a standard (non-admin) macOS account. The fix was to
stop using a background daemon that captures raw key events at all, and use a
Quick Action instead — a keyboard shortcut assigned via System Settings, which
is a standard per-user preference with no elevated-privilege gate. If ⌥Space
misbehaves today, see the **Quick Action gotchas** above, not this section.

The app itself can always be proven healthy independent of the trigger:
   `~/Applications/Markdug.app/Contents/MacOS/Markdug ~/Sites/Markdug/README.md`

---

## Current features

- Renders GitHub-Flavoured Markdown (via marked.js)
- Syntax highlighting in fenced code blocks (highlight.js 11.9.0 — GitHub light / GitHub Dark themes)
- Dark mode support
- Custom app icon (displays in Finder and Dock)
- Window size and position remembered between launches
- "Open in Sublime" pill button in title bar (calls `open -a "Sublime Text"` — no CLI shim needed)
- Toggle behaviour via the ⌥Space Quick Action (opens, ⌥Space again closes)
- Escape or Cmd+W quits the app entirely
- Closing the window quits the app entirely
- Fully root-free install: app in `~/Applications`, CLI in `~/.local/bin`, hotkey via a per-user Quick Action

---

## Planned features

- Trigger from Sublime Text (not just Finder) — open the currently active file
- Remove Dock icon (.accessory activation policy) — previously caused silent window failure, needs revisiting

## Done

- ~~KM-independent trigger~~ — **done 2026-05-31**: replaced Keyboard Maestro with
  skhd. Removed the licence/Engine single point of failure.
- ~~Root-free v2~~ — **done 2026-08-10**: replaced skhd (Homebrew + Accessibility)
  with a Quick Action (`Toggle Markdug.workflow`, `install-trigger.sh`); moved the
  app to `~/Applications` and the CLI to `~/.local/bin`; replaced the `subl` CLI
  shim with `open -a "Sublime Text"`. Nothing in the install or trigger path
  needs `sudo`, an admin password, or Homebrew.

---

## Environment

- Developer machine: macOS 26.3, Apple Silicon (has admin rights and Homebrew;
  used only to build and verify the root-free path actually works root-free)
- Target machine (2026-08-10 onward): standard macOS account, no admin password,
  no Homebrew, no Accessibility grants available
- Swift 6.2.3
- Sublime Text (no CLI shim needed — `open -a "Sublime Text"` is used instead)
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
~/Applications/Markdug.app/Contents/MacOS/Markdug ~/path/to/file.md
```

### Set up / repair the ⌥Space hotkey (Quick Action)
```bash
cd ~/path/to/Markdug && ./install-trigger.sh   # then bind ⌥Space in System Settings (see README.md)
ls ~/Library/Services                            # is "Toggle Markdug.workflow" there?
automator ~/Library/Services/Toggle\ Markdug.workflow   # test the Quick Action directly, bypassing the hotkey
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
