# Markdug — Developer Documentation

This file is for AI assistants. It describes the architecture, design decisions, and current state of the Markdug project.

---

## What Markdug is

A minimal macOS app that renders Markdown files in a floating window. Triggered by a keyboard shortcut via a **Shortcuts.app** shortcut (replaced an Automator Quick Action on 2026-08-10 — the Quick Action's Run Shell Script action was unreliable and difficult to debug on a standard, non-admin account with no way to copy/paste diagnostics off it). Shows a Dock icon while open. Press Escape or Cmd+W to quit.

It exists to fill a specific gap: the user edits `.md` files in Sublime Text and views them canonically on GitHub, but needed a fast zero-friction way to read Markdown locally without opening an editor or browser.

Everything — the app, the CLI tool, and the hotkey — installs entirely within the user's home directory. No `sudo`, no admin password, no Homebrew, no Accessibility permission grant, anywhere in the install path. This was a hard requirement from 2026-08-10 onward: the user works from a machine with a standard (non-admin) account, where `/Applications`, `/usr/local/bin`, Homebrew, and the Accessibility permission dialog are all unavailable.

---

## How it works

```
User selects .md file in Finder (Finder must be the focused app)
  → presses ⌃⌥Space
  → macOS dispatches the shortcut to the "Toggle Markdug" Shortcuts.app shortcut
  → the shortcut runs km-macro.sh via a Run Shell Script action
  → checks if Markdug is already running (if yes: quits it — toggle behaviour)
  → if no: calls ~/Applications/Markdug.app/Contents/MacOS/Markdug /path/to/file.md
  → Markdug window appears with rendered Markdown
  → user presses Escape, Cmd+W, or clicks the red traffic light to quit
  → (to toggle closed via keystroke instead: click back into Finder, then ⌃⌥Space again — see gotcha below)
```

`km-macro.sh` is unchanged in spirit across every trigger mechanism this project
has used (Keyboard Maestro → skhd → Quick Action → Shortcuts.app) — only the
thing that invokes it changed. The filename is kept for continuity.

---

## Repository structure

```
Markdug/
├── CLAUDE.md                  ← you are here
├── README.md                  ← user-facing install instructions
├── build.sh                   ← compiles and installs the app (all to $HOME, no root)
├── install-trigger.sh         ← (historical, superseded 2026-08-10) installed the old Quick Action into ~/Library/Services
├── Toggle Markdug.workflow/   ← (historical, superseded 2026-08-10) committed Automator Quick Action bundle — kept for reference/rollback
├── debugging-10Aug.md         ← checkpoint-based build/debug guide for the Shortcuts.app trigger
├── km-macro.sh                ← the trigger script the Shortcuts.app shortcut runs (reads Finder selection, launches app)
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

### The hotkey trigger (Shortcuts.app)

Since 2026-08-10 the hotkey is supplied by a **Shortcuts.app** shortcut named
`Toggle Markdug`, containing a single **Run Shell Script** action that calls
`km-macro.sh`. Built by hand in the Shortcuts.app GUI — unlike the old Quick
Action, this isn't scriptable/committable to the repo, so there's no
`install-trigger.sh` equivalent. See `debugging-10Aug.md` for the full
checkpoint-based build guide; summary:

1. Shortcuts → Settings → Advanced → enable **"Allow Running Scripts"** (off
   by default; the Run Shell Script action is otherwise blocked or missing).
2. New shortcut → `Toggle Markdug` → add **Run Shell Script** action → shell
   `/bin/bash`, input **nothing**, script body:
   `/bin/bash "$HOME/Sites/Markdug/km-macro.sh"` (path adjusted per account).
3. Test standalone first (▶ Run inside the Shortcuts editor, with a `.md`
   file selected in Finder) before touching any hotkey — this isolates the
   script layer from the trigger layer. First run triggers a one-time
   **Automation** consent dialog (System Settings → Privacy & Security →
   Automation → Shortcuts → Finder) for the AppleScript call to Finder — a
   standard per-user toggle, not an admin gate, but easy to dismiss by
   accident.
4. Bind the keyboard shortcut in the shortcut's own detail pane
   (ⓘ → "Add Keyboard Shortcut") if offered; otherwise enable "Use as Quick
   Action" / "Show in Services Menu" and bind via System Settings → Keyboard
   → Keyboard Shortcuts… → Services, same place the old Quick Action was
   bound.
5. Test independent of the hotkey with `shortcuts run "Toggle Markdug"` — the
   `automator ~/Library/Services/...` equivalent for this trigger.

**Shortcut is ⌃⌥Space, not ⌥Space:** plain ⌥Space did not register — likely
already claimed elsewhere on this account. ⌃⌥Space works.

`km-macro.sh` itself (the script the shortcut runs) is unchanged:
- Uses AppleScript to get the selected file path from Finder
- Checks if Markdug is running via `pgrep` — if yes, kills it (toggle)
- Checks file extension is `.md`, `.markdown`, `.mdx`, or `.mdown`
- Launches via the full app binary path: `~/Applications/Markdug.app/Contents/MacOS/Markdug "$FILEPATH" &`

**Known limitation — Finder must be focused to close via keystroke:** because
the shortcut is bound as a Finder Quick Action/Service rather than a truly
global System Settings shortcut, ⌃⌥Space only fires when Finder is the active
app. Opening Markdug from a Finder selection works fine; toggling it *closed*
by keystroke requires clicking back into Finder first, then pressing
⌃⌥Space — pressing it while Markdug itself is focused does nothing. Escape,
Cmd+W, or the red traffic light still close the window at any time. See
**Planned features** for possible fixes.

**Shortcuts.app gotchas:**
- If the hotkey stops working, first test with `shortcuts run "Toggle Markdug"`
  to rule out the trigger layer, then run it standalone from inside the
  Shortcuts editor (▶) to rule out the script layer.
- If nothing happens on either test, check Shortcuts → Settings → Advanced →
  "Allow Running Scripts" is still enabled, and check System Settings →
  Privacy & Security → Automation → Shortcuts → Finder is still granted.
- Remember the shortcut only fires with Finder focused — before assuming it's
  broken, check which app is active.

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
is a standard per-user preference with no elevated-privilege gate.

### (Historical) Automator Quick Action was unreliable and hard to debug on the standard account
**Resolved 2026-08-10 by moving the hotkey to a Shortcuts.app shortcut — kept here for context.**
The Quick Action (`Toggle Markdug.workflow`) worked in principle — no root,
no Homebrew, no Accessibility grant — but proved unreliable in practice on the
locked-down standard account, and debugging it was slow going with no
copy/paste between accounts to compare state. No root cause was conclusively
confirmed before the decision was made to pivot rather than keep debugging;
`Toggle Markdug.workflow` and `install-trigger.sh` are kept in the repo for
reference/rollback but are no longer the active trigger. If the hotkey
misbehaves today, see the **Shortcuts.app gotchas** above, not this section.

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
- Toggle behaviour via the ⌃⌥Space Shortcuts.app shortcut (opens from Finder; to close via keystroke, focus Finder then press ⌃⌥Space again — see gotcha above)
- Escape or Cmd+W quits the app entirely
- Closing the window quits the app entirely
- Fully root-free install: app in `~/Applications`, CLI in `~/.local/bin`, hotkey via a per-user Shortcuts.app shortcut

---

## Planned features

- Trigger from Sublime Text (not just Finder) — open the currently active file
- Remove Dock icon (.accessory activation policy) — previously caused silent window failure, needs revisiting
- Make the toggle-closed keystroke work regardless of which app is focused (currently must re-focus Finder first) — likely needs either a genuinely global shortcut binding rather than a Finder Quick Action/Service, or an in-app key handler inside Markdug itself for the close half of the toggle

## Done

- ~~KM-independent trigger~~ — **done 2026-05-31**: replaced Keyboard Maestro with
  skhd. Removed the licence/Engine single point of failure.
- ~~Root-free v2~~ — **done 2026-08-10**: replaced skhd (Homebrew + Accessibility)
  with a Quick Action (`Toggle Markdug.workflow`, `install-trigger.sh`); moved the
  app to `~/Applications` and the CLI to `~/.local/bin`; replaced the `subl` CLI
  shim with `open -a "Sublime Text"`. Nothing in the install or trigger path
  needs `sudo`, an admin password, or Homebrew.
- ~~Shortcuts.app trigger~~ — **done 2026-08-10**: replaced the Automator Quick
  Action with a Shortcuts.app shortcut (⌃⌥Space) after the Quick Action proved
  unreliable and hard to debug on the standard account. Trade-off: the
  shortcut only fires with Finder focused, so closing Markdug via keystroke
  needs a re-focus-Finder step first — see Planned features.

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

### Set up / repair the ⌃⌥Space hotkey (Shortcuts.app)
No install script — the shortcut is built by hand in Shortcuts.app. See
`debugging-10Aug.md` for the full checkpoint guide. Quick checks:
```bash
shortcuts run "Toggle Markdug"   # test the shortcut directly, bypassing the hotkey
```
- Not firing at all via ⌃⌥Space? Check Finder is the focused app first (known limitation).
- Fires via CLI but not the hotkey? Rebind in the shortcut's ⓘ detail pane, or via System Settings → Keyboard → Keyboard Shortcuts… → Services.
- Doesn't fire via CLI either? Check Shortcuts → Settings → Advanced → "Allow Running Scripts", and System Settings → Privacy & Security → Automation → Shortcuts → Finder.

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
