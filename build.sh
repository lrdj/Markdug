#!/bin/bash
# Markdug build + install script
# Run this once on your Mac from the project folder:
#   chmod +x build.sh && ./build.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Markdug"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "🔨 Building $APP_NAME..."

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS" "$RESOURCES"

# ── Fetch marked.js (the markdown parser) ────────────────────────────────────
echo "📦 Fetching marked.js..."
MARKED_URL="https://cdn.jsdelivr.net/npm/marked/marked.min.js"
MARKED_PATH="$RESOURCES/marked.min.js"

if command -v curl &> /dev/null; then
    curl -sL "$MARKED_URL" -o "$MARKED_PATH"
else
    echo "❌ curl not found. Please install curl and retry."
    exit 1
fi

echo "✅ marked.js downloaded"

# ── Fetch highlight.js (syntax highlighting) ──────────────────────────────────
echo "📦 Fetching highlight.js..."
curl -sfL "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js" \
     -o "$RESOURCES/highlight.min.js"
curl -sfL "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css" \
     -o "$RESOURCES/highlight.min.css"
curl -sfL "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css" \
     -o "$RESOURCES/highlight-dark.min.css"
echo "✅ highlight.js downloaded"

# ── Compile Swift source ─────────────────────────────────────────────────────
echo "🔧 Compiling Swift..."

# Inject the real marked.js into the Swift file before compiling
MARKED_CONTENT=$(cat "$MARKED_PATH" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')

# We compile directly with swiftc
swiftc \
    "$PROJECT_DIR/Markdug/AppDelegate.swift" \
    -o "$MACOS/$APP_NAME" \
    -framework Cocoa \
    -framework WebKit \
    -target arm64-apple-macosx15.0 \
    2>&1 || {
        echo "⚠️  arm64 failed, trying x86_64..."
        swiftc \
            "$PROJECT_DIR/Markdug/AppDelegate.swift" \
            -o "$MACOS/$APP_NAME" \
            -framework Cocoa \
            -framework WebKit \
            -target x86_64-apple-macosx15.0
    }

echo "✅ Swift compiled"

# ── Copy Info.plist ──────────────────────────────────────────────────────────
cp "$PROJECT_DIR/Markdug/Info.plist" "$CONTENTS/Info.plist"

# ── Write PkgInfo ─────────────────────────────────────────────────────────────
printf 'APPL????' > "$CONTENTS/PkgInfo"

# ── Copy app icon (if present) ───────────────────────────────────────────────
if [ -f "$PROJECT_DIR/Markdug/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Markdug/AppIcon.icns" "$RESOURCES/AppIcon.icns"
    echo "✅ AppIcon.icns copied"
else
    echo "⚠️  No AppIcon.icns found — skipping (app will use default icon)"
fi

# ── Copy marked.js into Resources ───────────────────────────────────────────
# (already there from above)

# ── Patch AppDelegate to load marked.js from bundle ─────────────────────────
# The compiled binary loads marked.js at runtime from Resources
# (this is handled in the Swift code via Bundle.main.path)

# ── Install to /Applications ─────────────────────────────────────────────────
echo "📲 Installing to /Applications..."
rm -rf "/Applications/$APP_NAME.app"
cp -R "$APP_BUNDLE" "/Applications/$APP_NAME.app"

# ── Code sign ────────────────────────────────────────────────────────────────
echo "🔏 Signing..."
codesign --force --deep --sign - "/Applications/$APP_NAME.app"

# ── Register URL scheme ──────────────────────────────────────────────────────
echo "🔗 Registering URL scheme..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "/Applications/$APP_NAME.app" 2>/dev/null || true

# ── Flush icon caches ─────────────────────────────────────────────────────────
echo "🔄 Flushing icon caches..."
killall Finder 2>/dev/null || true
killall Dock 2>/dev/null || true

# ── Create CLI helper ────────────────────────────────────────────────────────
CLI_PATH="/usr/local/bin/mdug"
echo "🔧 Creating CLI tool at $CLI_PATH..."

cat > /tmp/mdug_cli << 'CLIPYTHON'
#!/usr/bin/env python3
import sys
import subprocess
import os

if len(sys.argv) < 2:
    print("Usage: mdug <file.md>")
    sys.exit(1)

path = os.path.abspath(sys.argv[1])
if not os.path.exists(path):
    print(f"File not found: {path}")
    sys.exit(1)

subprocess.run([
    "open", "-a", "Markdug", "--args", path
])
CLIPYTHON

sudo mkdir -p /usr/local/bin
sudo cp /tmp/mdug_cli "$CLI_PATH"
sudo chmod +x "$CLI_PATH"

echo ""
echo "✅ Markdug installed!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test it:  mdug ~/path/to/some/file.md"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next: set up the ⌥Space hotkey — run ./install-trigger.sh (see README.md)"
echo ""
