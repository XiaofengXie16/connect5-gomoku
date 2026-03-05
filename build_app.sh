#!/bin/bash
# Build Connect5 as a native macOS .app and optionally install it.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Connect5"
BUNDLE="$APP_NAME.app"
CONTENTS="$BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "╔══════════════════════════════════╗"
echo "║   Building Connect 5 — Gomoku    ║"
echo "╚══════════════════════════════════╝"
echo ""

# 1. Compile release binary
echo "▸ Compiling release build..."
swift build -c release --quiet
echo "  Done."
echo ""

# 2. Create .app bundle structure
echo "▸ Packaging .app bundle..."
rm -rf "$BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"
cp ".build/release/$APP_NAME" "$MACOS/$APP_NAME"
chmod +x "$MACOS/$APP_NAME"

# 3. Write Info.plist
cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>     <string>Connect5</string>
    <key>CFBundleIdentifier</key>    <string>com.user.connect5</string>
    <key>CFBundleName</key>          <string>Connect5</string>
    <key>CFBundleDisplayName</key>   <string>Connect 5</string>
    <key>CFBundleVersion</key>       <string>1.0</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundlePackageType</key>   <string>APPL</string>
    <key>NSPrincipalClass</key>      <string>NSApplication</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>CFBundleIconFile</key>      <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key> <string>13.0</string>
    <key>LSApplicationCategoryType</key> <string>public.app-category.games</string>
    <key>NSHumanReadableCopyright</key>  <string>© 2025</string>
</dict>
</plist>
EOF

# 4. Generate app icon
echo "▸ Generating app icon..."
if swift Scripts/make_icon.swift "$RESOURCES/AppIcon.icns" 2>/dev/null; then
    echo "  Icon created."
else
    echo "  Icon skipped (non-critical)."
fi
echo ""

# 5. Ad-hoc code sign (required to run without Xcode signing)
echo "▸ Code signing (ad-hoc)..."
codesign --sign - --force --deep "$BUNDLE" 2>/dev/null && echo "  Signed." || echo "  Signing skipped."
echo ""

echo "✓ $BUNDLE is ready!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 6. Offer to install
read -p "Install to ~/Applications? [Y/n] " choice
choice="${choice:-Y}"

if [[ "$choice" =~ ^[Yy]$ ]]; then
    mkdir -p ~/Applications
    rm -rf ~/Applications/"$BUNDLE"
    cp -r "$BUNDLE" ~/Applications/
    echo ""
    echo "✓ Installed to ~/Applications/Connect5.app"
    echo ""
    read -p "Open the app now? [Y/n] " open_now
    open_now="${open_now:-Y}"
    if [[ "$open_now" =~ ^[Yy]$ ]]; then
        open ~/Applications/"$BUNDLE"
    fi
else
    echo ""
    echo "You can find the app at:"
    echo "  $SCRIPT_DIR/$BUNDLE"
    echo ""
    echo "To run it:     open $BUNDLE"
    echo "To install:    cp -r $BUNDLE ~/Applications/"
    echo "               cp -r $BUNDLE /Applications/   (system-wide)"
fi
