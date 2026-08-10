#!/usr/bin/env bash
# build.sh — builds, signs, and packages HoneyDue Calendar Sync as a .dmg
# Usage:
#   ./build.sh              # auto-detect signing identity
#   ./build.sh --identity "Apple Development: daneyand@ibm.com (p52kt93359)"

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
APP_NAME="HoneyDueCalSync"
DISPLAY_NAME="HoneyDue Calendar Sync"
BUNDLE_ID="com.honeydue.calsync"
VERSION="1.0.7"
ENTITLEMENTS="HoneyDueCalSync.entitlements"
DMG_NAME="${DISPLAY_NAME// /-}-${VERSION}.dmg"   # HoneyDue-Calendar-Sync-1.0.dmg

# ── Signing identity ──────────────────────────────────────────────────────────
if [[ "${1:-}" == "--identity" && -n "${2:-}" ]]; then
    SIGN_ID="$2"
else
    # Auto-detect first valid Apple Development / Mac Developer cert
    SIGN_ID=$(security find-identity -v -p codesigning \
        | grep -E "Apple Development|Mac Developer" \
        | head -1 \
        | sed 's/.*"\(.*\)"/\1/' || true)
fi

if [[ -z "$SIGN_ID" ]]; then
    echo "⚠️  No valid codesigning identity found. Falling back to ad-hoc sign (-)."
    echo "   Run 'security find-identity -v -p codesigning' to check your certs."
    SIGN_ID="-"
fi
echo "🔑  Signing identity: $SIGN_ID"

# ── Paths ─────────────────────────────────────────────────────────────────────
BUILD_DIR=".build/release"
APP_DIR="build/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RESOURCES_DIR="${CONTENTS}/Resources"
DMG_STAGE="build/dmg-stage"

# ── 1. Clean ──────────────────────────────────────────────────────────────────
# Remove only transient build artefacts — do NOT wipe the whole build/ dir,
# as that would delete previously committed DMGs and the presentation pptx.
echo "🧹  Cleaning previous build..."
rm -rf "${APP_DIR}" "${DMG_STAGE}"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$DMG_STAGE"

# ── 2. Swift release build ────────────────────────────────────────────────────
echo "🧪  Running unit tests..."
swift test 2>&1
if [ $? -ne 0 ]; then
    echo "❌  Tests failed — aborting build."
    exit 1
fi
echo "   ✓ All tests passed"

echo "🔨  Building release..."
swift build --configuration release

# ── 3. Assemble .app bundle ───────────────────────────────────────────────────
echo "📦  Assembling .app bundle..."

# Binary
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

# Info.plist — embed into Contents (proper .app placement, not linker trick)
cp "Sources/${APP_NAME}/Info.plist" "${CONTENTS}/Info.plist"

# SPM resource bundle (contains IMG_2489.JPG etc.) — may be in arch-specific subdir
BUNDLE_SRC=$(find ".build" -name "${APP_NAME}_${APP_NAME}.bundle" -path "*/release/*" 2>/dev/null | head -1 || true)
if [[ -n "$BUNDLE_SRC" ]]; then
    cp -r "$BUNDLE_SRC" "${RESOURCES_DIR}/"
    echo "   ✓ Resource bundle copied"
else
    echo "   ⚠️  No resource bundle found — images may not load"
fi

# App icon — generate .icns from SVG using svg2icns.swift then embed
echo "   Generating app icon..."
swift svg2icns.swift assets/icon.svg "${RESOURCES_DIR}/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${CONTENTS}/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "${CONTENTS}/Info.plist"
echo "   ✓ Icon embedded"

# ── 4. Code sign ──────────────────────────────────────────────────────────────
echo "✍️   Signing..."
if [[ "$SIGN_ID" == "-" ]]; then
    codesign --force --deep --sign - "${APP_DIR}"
else
    codesign --force --deep \
             --sign "$SIGN_ID" \
             --entitlements "$ENTITLEMENTS" \
             --options runtime \
             "${APP_DIR}"
fi
echo "   ✓ Signed"

# Verify
codesign --verify --deep --strict "${APP_DIR}" && echo "   ✓ Signature verified"

# ── 5. Build DMG ──────────────────────────────────────────────────────────────
echo "💿  Building DMG..."

# Stage: app + Applications symlink + README
cp -r "${APP_DIR}" "${DMG_STAGE}/"
ln -s /Applications "${DMG_STAGE}/Applications"
cp README.md "${DMG_STAGE}/README.md"

# Create DMG
hdiutil create \
    -volname "${DISPLAY_NAME}" \
    -srcfolder "${DMG_STAGE}" \
    -ov \
    -format UDZO \
    "build/${DMG_NAME}"

echo ""
echo "✅  Done!"
echo "   App:  build/${APP_NAME}.app"
echo "   DMG:  build/${DMG_NAME}"
echo ""
echo "   To install: open build/${DMG_NAME} and drag to Applications"
echo "   To remove quarantine after sharing:"
echo "     xattr -cr /Applications/${APP_NAME}.app"
