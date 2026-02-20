# Markdug — Developer Documentation

This file is for AI assistants. It describes the architecture, design decisions, and current state of the Markdug project.

---

## What Markdug is

A minimal macOS app that renders Markdown files in a floating window. Triggered by a keyboard shortcut via Keyboard Maestro. No Dock icon. Press Escape or Cmd+W to quit.

It exists to fill a specific gap: the user edits `.md` files in Sublime Text and views them canonically on GitHub, but needed a fast zero-friction way to read Markdown locally without opening an editor or browser.

---

## How it works

```
User selects .md file in Finder
  → presses ⌥Space
  → Keyboard Maestro macro fires
  → checks if Markdug is already running (if yes: quits it — toggle behaviour)
  → if no: calls /Applications/Markdug.app/Contents/MacOS/Markdug /path/to/file.md
  → Markdug window appears with rendered Markdown
  → user presses Escape, Cmd+W, or clicks the red traffic light to quit
```

---

## Repository structure

```
Markdug/
├── CLAUDE.md                  ← you are here
├── README.md                  ← user-facing install instructions
├── build.sh                   ← compiles and installs the app
├── km-macro.sh                ← Keyboard Maestro script (paste into KM manually)
└── Markdug/
    ├── AppDelegate.swift      ← the entire app (~150 lines)
    └── Info.plist             ← app metadata, URL scheme registration
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
3. Compiles `AppDelegate.swift` with `swiftc` directly (no Xcode)
4. Copies `Info.plist` into the bundle
5. Installs to `/Applications/Markdug.app`
6. Registers the URL scheme with Launch Services
7. Creates `/usr/local/bin/mdug` CLI tool (Python script that calls `open -a Markdug --args <path>`)

### The CLI tool

`/usr/local/bin/mdug` is a small Python 3 script installed by `build.sh`. It takes a file path, resolves it to an absolute path, and launches the app via `open -a Markdug --args`.

### Keyboard Maestro macro

Not in the repo as an importable file — must be set up manually. The script is in `km-macro.sh`. Key behaviours:
- Uses AppleScript to get the selected file path from Finder
- Checks if Markdug is running via `pgrep` — if yes, kills it (toggle)
- Checks file extension is `.md`, `.markdown`, `.mdx`, or `.mdown`
- Launches via the full app binary path: `/Applications/Markdug.app/Contents/MacOS/Markdug "$FILEPATH" &`
- Set to run **Asynchronously** in KM so it doesn't block

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

---

## Current features

- Renders GitHub-Flavoured Markdown (via marked.js)
- Dark mode support
- Fenced code blocks (``` syntax) — rendered but not syntax highlighted
- "Open in Sublime" pill button in title bar (calls `/usr/local/bin/subl`)
- Toggle behaviour via Keyboard Maestro (⌥Space opens, ⌥Space again closes)
- Escape or Cmd+W quits the app entirely
- Closing the window quits the app entirely

---

## Planned features (v1.1)

- Syntax highlighting in code blocks (highlight.js)
- Remember window size and position between launches
- Trigger from Sublime Text (not just Finder) — open the currently active file
- Remove Dock icon (.accessory activation policy) — previously caused silent window failure, needs revisiting

---

## Environment

- Developer machine: macOS 26.3, Apple Silicon
- Swift 6.2.3
- Sublime Text (with `subl` CLI at `/usr/local/bin/subl`)
- Keyboard Maestro for hotkey triggering
- marked.js loaded from jsDelivr CDN at build time

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
