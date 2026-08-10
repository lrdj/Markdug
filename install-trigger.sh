#!/bin/bash
# Markdug trigger installer (Quick Action)
#
# Sets up the global ⌥Space hotkey that launches Markdug — no root, no
# Homebrew, no Accessibility permission required. Run once per Mac, after
# ./build.sh has installed the app:
#   chmod +x install-trigger.sh && ./install-trigger.sh
#
# What it does:
#   1. Copies this repo's "Toggle Markdug.workflow" (a macOS Quick Action —
#      built with Automator, runs km-macro.sh) into ~/Library/Services
#   2. Patches it to point at THIS repo's km-macro.sh
#   3. Refreshes the Services cache so it shows up immediately
#
# Quick Actions are a standard per-user macOS feature: assigning one a global
# keyboard shortcut is done entirely in System Settings, by any account, with
# no admin password and no Accessibility grant — unlike a background hotkey
# daemon (e.g. skhd), which needs both.

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
MACRO_PATH="$PROJECT_DIR/km-macro.sh"
SOURCE_WORKFLOW="$PROJECT_DIR/Toggle Markdug.workflow"
SERVICES_DIR="$HOME/Library/Services"
DEST_WORKFLOW="$SERVICES_DIR/Toggle Markdug.workflow"

echo "🔨 Installing Markdug trigger (Quick Action)..."

if [ ! -d "$SOURCE_WORKFLOW" ]; then
    echo "❌ Couldn't find \"Toggle Markdug.workflow\" in $PROJECT_DIR"
    exit 1
fi

# ── Make sure the macro script is executable ─────────────────────────────────
chmod +x "$MACRO_PATH"

# ── Install the Quick Action into ~/Library/Services ─────────────────────────
echo "📝 Installing Quick Action to $DEST_WORKFLOW..."
mkdir -p "$SERVICES_DIR"
rm -rf "$DEST_WORKFLOW"
cp -R "$SOURCE_WORKFLOW" "$DEST_WORKFLOW"

# Point the copied workflow at THIS repo's km-macro.sh (works regardless of
# where the repo was cloned)
sed -i '' "s#__MACRO_PATH__#$MACRO_PATH#" "$DEST_WORKFLOW/Contents/document.wflow"

# ── Refresh the Services cache so it appears without logging out ─────────────
echo "🔄 Refreshing Services menu..."
/System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true

echo ""
echo "✅ Trigger installed!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ONE MANUAL STEP — bind it to ⌥Space:"
echo ""
echo "  System Settings → Keyboard → Keyboard Shortcuts… → Services"
echo "  Find \"Toggle Markdug\" (under General), double-click its shortcut"
echo "  column, and press ⌥Space."
echo ""
echo "  No admin password needed — this is a standard per-user shortcut."
echo "  Then select a .md file in Finder and press ⌥Space to test."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
