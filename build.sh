#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Building release binary..."
swift build -c release

BIN="$SCRIPT_DIR/.build/release/AITokenMenubar"
APP_DIR="$SCRIPT_DIR/AITokenMenubar.app"

echo "==> Creating .app bundle at $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN" "$APP_DIR/Contents/MacOS/AITokenMenubar"

cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AITokenMenubar</string>
    <key>CFBundleIdentifier</key>
    <string>com.aitoken.menubar</string>
    <key>CFBundleName</key>
    <string>AI Token</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Done!"
echo ""
echo "App bundle: $APP_DIR"
echo ""
echo "To add to Login Items (开机自启):"
echo "  1. 系统设置 → 通用 → 登录项与扩展"
echo "  2. 点击 + 号，选择 $APP_DIR"
echo ""
echo "Or run directly: open '$APP_DIR'"
