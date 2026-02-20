# Markdug — Changelog

---

## v1.1 (in progress) — 2026-02-20

### Added
- **Syntax highlighting** in fenced code blocks via highlight.js 11.9.0
  - Light theme: GitHub (matches existing body styles)
  - Dark theme: GitHub Dark (respects `prefers-color-scheme`)
  - Graceful fallback if highlight.js files are missing from bundle
  - `build.sh` now downloads 3 additional files from cdnjs at build time

- **Window size/position memory** — window restores to last position and size between launches
  - Implemented via `NSWindow.setFrameAutosaveName` (one line, AppKit handles the rest)
  - First launch centers at 900×700; subsequent launches restore saved frame

- **App icon** — custom icon support wired up
  - `CFBundleIconFile` and `CFBundleIconName` added to Info.plist
  - `build.sh` copies `Markdug/AppIcon.icns` into the bundle at build time
  - Icon file (`AppIcon.icns`) is generated from a 1024×1024 RGBA PNG
  - ⚠️ Icon not yet displaying in Finder or Dock — debugging in progress (see below)

### Changed
- `LSUIElement` removed from Info.plist (was `true`, conflicted with `.regular` activation policy)
- Activation policy is `.regular` (Dock icon shows while app is running)

### Investigated and reverted
- **No Dock icon (`.accessory` policy)** — attempted but abandoned:
  - `.accessory` policy without `NSApp.activate` → Dock pulse, window opens in background
  - `.accessory` with `NSApp.activate` → brief Dock flash, window in front but scroll requires click first
  - `orderFrontRegardless()` → no Dock interaction but window in background, no scroll without click
  - Decision: live with Dock icon while app is running; `.accessory` not worth the UX trade-offs

### Known issue — icon not displaying
Everything appears correctly configured but the icon does not show in Finder or the Dock:
- `AppIcon.icns` present in `Contents/Resources/` ✅
- `CFBundleIconFile` + `CFBundleIconName` in Info.plist ✅
- Ad-hoc code signature applied (`codesign --force --deep --sign -`) ✅
- Various icon cache clears attempted (`lsregister`, `killall Dock`, `killall iconservicesd`, etc.)

**Next steps to try:**
1. Check for quarantine xattr: `xattr -l /Applications/Markdug.app`
2. Convert source PNG from Display P3 → sRGB before generating icns
3. Add `PkgInfo` file to bundle (`Contents/PkgInfo` containing `APPL????`)
4. Use `ditto` instead of `cp -R` in build.sh for the install step
5. Add `codesign` step to build.sh (after install)
6. More aggressive icon cache clear: `sudo rm -rf /Library/Caches/com.apple.iconservices.store`

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
