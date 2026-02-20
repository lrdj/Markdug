# Markdug — Changelog

---

## v1.1 — 2026-02-20

### Added
- **Syntax highlighting** in fenced code blocks via highlight.js 11.9.0
  - Light theme: GitHub (matches existing body styles)
  - Dark theme: GitHub Dark (respects `prefers-color-scheme`)
  - Graceful fallback if highlight.js files are missing from bundle
  - `build.sh` now downloads 3 additional files from cdnjs at build time

- **Window size/position memory** — window restores to last position and size between launches
  - Implemented via `NSWindow.setFrameAutosaveName` (one line, AppKit handles the rest)
  - First launch centers at 900×700; subsequent launches restore saved frame

- **App icon** — custom icon displaying correctly in Finder and Dock
  - `CFBundleIconFile` and `CFBundleIconName` added to Info.plist
  - `build.sh` copies `Markdug/AppIcon.icns` into the bundle at build time
  - Source was a 1024×1024 Display P3 PNG; converted to sRGB with `sips`, scaled to all
    required sizes, and compiled to `AppIcon.icns` with `iconutil`
  - See debugging notes below for the full root cause investigation

### Changed
- `LSUIElement` removed from Info.plist (was `true`, conflicted with `.regular` activation policy)
- Activation policy is `.regular` (Dock icon shows while app is running)

### Investigated and reverted
- **No Dock icon (`.accessory` policy)** — attempted but abandoned:
  - `.accessory` policy without `NSApp.activate` → Dock pulse, window opens in background
  - `.accessory` with `NSApp.activate` → brief Dock flash, window in front but scroll requires click first
  - `orderFrontRegardless()` → no Dock interaction but window in background, no scroll without click
  - Decision: live with Dock icon while app is running; `.accessory` not worth the UX trade-offs

### Icon debugging — root cause and fix

The icon was not displaying in Finder or the Dock despite the `.icns` file being present and
`CFBundleIconFile` being set. Root cause: **the `Info.plist` was invalid XML**.

The `CFBundleURLTypes` array was closed with `</dict>` instead of `</array>`, which made the
entire plist unreadable by macOS. Because the plist couldn't be parsed, `CFBundleIconFile` was
never read, and macOS fell back to the default white-grid icon.

**Diagnosis approach:**

The most useful step was an isolation test: build a completely minimal Hello World app bundle
from scratch on the same machine, give it a known-good sRGB red square icon, and check whether
*that* shows correctly. It did — immediately, in both Finder and Dock. This ruled out environment
issues (macOS version, icon cache, machine-level quarantine, etc.) and confirmed the problem was
specific to Markdug's bundle.

From there: `plutil -lint /Applications/Markdug.app/Contents/Info.plist` immediately reported:

```
(Close tag on line 39 does not match open tag array)
```

**The fix:** One character change in `Markdug/Info.plist`, line 39: `</dict>` → `</array>`.

**Other improvements made during debugging** (all now in `build.sh`):
- `PkgInfo` file written to `Contents/PkgInfo` (`APPL????`) — recommended for hand-built bundles
- `codesign --force --deep --sign -` run after install
- `killall Finder && killall Dock` run after `lsregister` to flush icon caches

**Lesson:** When an icon (or any app metadata) silently fails, run `plutil -lint` on `Info.plist`
first. An invalid plist gives no error at launch — the app still runs — but metadata like icons,
URL schemes, and version strings are simply not read.

---

## v1.0 — initial release

- Single-file Swift app (`AppDelegate.swift`, ~150 lines)
- Renders GitHub-flavoured Markdown via `marked.js` (bundled at build time)
- Dark mode support via `@media (prefers-color-scheme: dark)`
- Floating window, 900×700 default size
- "Open in Sublime" pill button in title bar
- Escape or Cmd+W quits; closing window quits
- No Dock icon while idle (toggle via Keyboard Maestro: ⌥Space opens, ⌥Space again kills)
- `build.sh` compiles and installs in one step
- `/usr/local/bin/mdug` CLI tool installed by build script
- Keyboard Maestro macro for hotkey trigger (set up manually, see `km-macro.sh`)
