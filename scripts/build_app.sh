#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${VERSION:-v1.0.0}"
SHORT_VERSION="${VERSION#v}"

echo "==> Running unit tests..."
swift run NetPrioritySelfTest

echo "==> Building release binary ($VERSION)..."
ARCH_LABEL="$(uname -m)"
BIN_PATH="$ROOT_DIR/.build/release/NetPriority"

if swift build -c release --arch arm64 --arch x86_64; then
  BIN_PATH="$ROOT_DIR/.build/apple/Products/Release/NetPriority"
  ARCH_LABEL="universal"
else
  echo "Universal build unavailable; falling back to native architecture ($ARCH_LABEL)..."
  swift build -c release
  BIN_PATH="$ROOT_DIR/.build/release/NetPriority"
fi

APP_DIR="$ROOT_DIR/build/NetPriority.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/NetPriority"
chmod +x "$APP_DIR/Contents/MacOS/NetPriority"

ICONSET_DIR="$ROOT_DIR/build/AppIcon.iconset"
swift "$ROOT_DIR/scripts/make_icon.swift" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>NetPriority</string>
  <key>CFBundleExecutable</key>
  <string>NetPriority</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>io.github.wmwgz.netpriority</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>NetPriority</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${SHORT_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "==> Ad-hoc signing app bundle..."
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --verbose=2 "$APP_DIR"

INSTALL_DIR="/Applications"
if [ ! -w "$INSTALL_DIR" ]; then
  INSTALL_DIR="$HOME/Applications"
  mkdir -p "$INSTALL_DIR"
fi

TARGET_APP="$INSTALL_DIR/NetPriority.app"
rm -rf "$TARGET_APP"
cp -R "$APP_DIR" "$TARGET_APP"
codesign --verify --verbose=2 "$TARGET_APP"
echo "==> Installed to $TARGET_APP"

DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR"
ZIP_NAME="NetPriority-${VERSION}-macos-${ARCH_LABEL}.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
rm -f "$ZIP_PATH" "$ZIP_PATH.sha256"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
(cd "$DIST_DIR" && shasum -a 256 "$ZIP_NAME" > "${ZIP_NAME}.sha256")
echo "==> Release package created: $ZIP_PATH"
cat "${ZIP_PATH}.sha256"
