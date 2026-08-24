#!/usr/bin/env bash
# build.sh — builds, signs, packages, and publishes HoneyDue Calendar Sync
#
# Usage:
#   ./build.sh                        # build + publish GitHub release (default)
#   ./build.sh --local                # build DMG only, no git commit / GitHub release
#   ./build.sh --identity "Apple Development: you@example.com (TEAMID)"
#   ./build.sh --local --identity "..."

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
APP_NAME="HoneyDueCalSync"
DISPLAY_NAME="HoneyDue Calendar Sync"
BUNDLE_ID="com.honeydue.calsync"
VERSION="1.0.8"
ENTITLEMENTS="HoneyDueCalSync.entitlements"
DMG_NAME="${DISPLAY_NAME// /-}-${VERSION}.dmg"

# ── Flags ─────────────────────────────────────────────────────────────────────
LOCAL_ONLY=false
SIGN_ID=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --local)     LOCAL_ONLY=true; shift ;;
        --identity)  SIGN_ID="${2:-}"; shift 2 ;;
        *)           echo "Unknown argument: $1"; exit 1 ;;
    esac
done

# ── Signing identity ──────────────────────────────────────────────────────────
if [[ -z "$SIGN_ID" ]]; then
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
DMG_PATH="build/${DMG_NAME}"

# ── 1. Clean ──────────────────────────────────────────────────────────────────
# Remove only transient build artefacts — do NOT wipe the whole build/ dir,
# as that would delete previously committed DMGs and the presentation pptx.
echo "🧹  Cleaning previous build..."
rm -rf "${APP_DIR}" "${DMG_STAGE}"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$DMG_STAGE"

# ── 2. Swift tests + release build ───────────────────────────────────────────
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
    "${DMG_PATH}"

echo "   ✓ DMG created: ${DMG_PATH}"

# ── 6. Git commit + tag + GitHub release ──────────────────────────────────────
if [[ "$LOCAL_ONLY" == "true" ]]; then
    echo ""
    echo "✅  Local build complete (--local flag set — skipping git/GitHub steps)."
    echo "   App:  ${APP_DIR}"
    echo "   DMG:  ${DMG_PATH}"
    echo ""
    echo "   To install: open ${DMG_PATH} and drag to Applications"
    echo "   To remove quarantine after sharing:"
    echo "     xattr -cr /Applications/${APP_NAME}.app"
    exit 0
fi

echo ""
echo "🐙  Publishing to GitHub..."

# Check gh CLI is available
if ! command -v gh &>/dev/null; then
    echo "❌  'gh' CLI not found — install it with: brew install gh"
    echo "   Skipping GitHub release. DMG is at: ${DMG_PATH}"
    exit 1
fi

# Check for uncommitted source changes (warn but don't abort — DMG may be the only change)
GIT_DIRTY=$(git status --porcelain | grep -v "^??" || true)
if [[ -n "$GIT_DIRTY" ]]; then
    echo "   Staging and committing changed files..."
    git add -A
    git commit -m "Release v${VERSION} — $(git diff --cached --name-only | tr '\n' ' ')" || true
fi

# Ensure DMG is staged if not already committed
if git status --porcelain | grep -q "${DMG_NAME}"; then
    git add "${DMG_PATH}"
    git commit -m "Release v${VERSION} — add ${DMG_NAME}" || true
fi

# Tag (skip if tag already exists)
if git rev-parse "v${VERSION}" &>/dev/null; then
    echo "   Tag v${VERSION} already exists — skipping tag creation."
else
    git tag "v${VERSION}"
    echo "   ✓ Tagged v${VERSION}"
fi

# Push commits + tag
git push origin main
git push origin "v${VERSION}"
echo "   ✓ Pushed to GitHub"

# Build release notes from a RELEASE_NOTES temp var (edit here for each version)
# The notes are auto-generated; override by passing RELEASE_NOTES env var before calling build.sh
RELEASE_NOTES="${RELEASE_NOTES:-"## ${DISPLAY_NAME} v${VERSION}

### What's New
See the README for full details.

### Install
1. Download \`${DMG_NAME}\` below
2. Open the DMG and drag **${APP_NAME}** to your Applications folder
3. Launch the app — the 🐝 bee appears in your menu bar

> **First launch Gatekeeper warning:** Right-click the app → Open → click Open.
> Or run \`xattr -cr /Applications/${APP_NAME}.app\` in Terminal.

### Requirements
- macOS 13 (Ventura) or later
- Both work and personal calendars added to macOS Calendar.app via System Settings → Internet Accounts

*From the Minds of Daneyand & Bob!*"}"

# Create or update GitHub release
if gh release view "v${VERSION}" &>/dev/null; then
    echo "   Release v${VERSION} already exists on GitHub — uploading/replacing DMG asset..."
    gh release upload "v${VERSION}" "${DMG_PATH}" --clobber
    echo "   ✓ DMG asset updated on existing release"
else
    gh release create "v${VERSION}" \
        "${DMG_PATH}" \
        --title "${DISPLAY_NAME} v${VERSION}" \
        --latest \
        --notes "${RELEASE_NOTES}"
    echo "   ✓ GitHub release v${VERSION} created"
fi

echo ""
echo "✅  Done!"
echo "   App:     ${APP_DIR}"
echo "   DMG:     ${DMG_PATH}"
echo "   Release: https://github.com/007Style/honeydue-cal-sync/releases/tag/v${VERSION}"
echo ""
echo "   To install: open ${DMG_PATH} and drag to Applications"
echo "   To remove quarantine after sharing:"
echo "     xattr -cr /Applications/${APP_NAME}.app"
