#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${VERSION:-v1.0.0}"
SHORT_VERSION="${VERSION#v}"
PACKAGE_TARGETS="${PACKAGE_TARGETS:-native}"
SKIP_INSTALL="${SKIP_INSTALL:-0}"

BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

echo "==> Running unit tests..."
swift run NetPrioritySelfTest

echo "==> Generating app icon..."
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
ICNS_PATH="$BUILD_DIR/AppIcon.icns"
rm -rf "$ICONSET_DIR" "$ICNS_PATH"
swift "$ROOT_DIR/scripts/make_icon.swift" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
rm -rf "$ICONSET_DIR"

verify_binary_archs() {
  local bin_path="$1"
  local expected="$2"
  local actual
  actual="$(lipo -archs "$bin_path")"

  case "$expected" in
    universal)
      if [[ " $actual " != *" arm64 "* ]] || [[ " $actual " != *" x86_64 "* ]]; then
        echo "ERROR: Expected universal binary (arm64 + x86_64), got: $actual" >&2
        exit 1
      fi
      ;;
    arm64|x86_64)
      if [[ "$actual" != "$expected" ]]; then
        echo "ERROR: Expected architecture '$expected', got: $actual" >&2
        exit 1
      fi
      ;;
    *)
      if [[ " $actual " != *" $expected "* ]]; then
        echo "ERROR: Expected architecture '$expected', got: $actual" >&2
        exit 1
      fi
      ;;
  esac
}

package_bundle() {
  local arch_label="$1"
  local bin_path="$2"
  local expected_archs="$3"

  local app_dir="$BUILD_DIR/${arch_label}/NetPriority.app"
  rm -rf "$app_dir"
  mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"

  cp "$bin_path" "$app_dir/Contents/MacOS/NetPriority"
  chmod +x "$app_dir/Contents/MacOS/NetPriority"
  cp "$ICNS_PATH" "$app_dir/Contents/Resources/AppIcon.icns"

  verify_binary_archs "$app_dir/Contents/MacOS/NetPriority" "$expected_archs"

  cat > "$app_dir/Contents/Info.plist" <<PLIST
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

  echo "==> Ad-hoc signing ${arch_label} app bundle..."
  codesign --force --deep --sign - "$app_dir"
  codesign --verify --verbose=2 "$app_dir"
  lipo -info "$app_dir/Contents/MacOS/NetPriority"

  local zip_name="NetPriority-${VERSION}-macos-${arch_label}.zip"
  local zip_path="$DIST_DIR/$zip_name"
  rm -f "$zip_path" "$zip_path.sha256"
  ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$zip_path"
  (cd "$DIST_DIR" && shasum -a 256 "$zip_name" > "${zip_name}.sha256")
  echo "==> Release package created: $zip_path"
  cat "${zip_path}.sha256"
}

INSTALL_SOURCE_APP=""

case "$PACKAGE_TARGETS" in
  all)
    echo "==> Building arm64 release binary ($VERSION)..."
    swift build -c release --arch arm64
    ARM64_BIN="$(swift build -c release --arch arm64 --show-bin-path)/NetPriority"

    echo "==> Building x86_64 release binary ($VERSION)..."
    swift build -c release --arch x86_64
    X86_64_BIN="$(swift build -c release --arch x86_64 --show-bin-path)/NetPriority"

    echo "==> Creating universal binary ($VERSION)..."
    UNIVERSAL_BIN="$BUILD_DIR/NetPriority-universal"
    rm -f "$UNIVERSAL_BIN"
    lipo -create "$ARM64_BIN" "$X86_64_BIN" -output "$UNIVERSAL_BIN"

    package_bundle arm64 "$ARM64_BIN" arm64
    package_bundle x86_64 "$X86_64_BIN" x86_64
    package_bundle universal "$UNIVERSAL_BIN" universal
    INSTALL_SOURCE_APP="$BUILD_DIR/universal/NetPriority.app"
    ;;
  native)
    ARCH_LABEL="$(uname -m)"
    echo "==> Building native release binary ($VERSION, $ARCH_LABEL)..."
    swift build -c release
    NATIVE_BIN="$(swift build -c release --show-bin-path)/NetPriority"

    package_bundle "$ARCH_LABEL" "$NATIVE_BIN" "$ARCH_LABEL"
    INSTALL_SOURCE_APP="$BUILD_DIR/${ARCH_LABEL}/NetPriority.app"
    ;;
  *)
    echo "ERROR: Unsupported PACKAGE_TARGETS='$PACKAGE_TARGETS' (expected 'native' or 'all')" >&2
    exit 1
    ;;
esac

if [ "$SKIP_INSTALL" != "1" ]; then
  INSTALL_DIR="/Applications"
  if [ ! -w "$INSTALL_DIR" ]; then
    INSTALL_DIR="$HOME/Applications"
    mkdir -p "$INSTALL_DIR"
  fi

  TARGET_APP="$INSTALL_DIR/NetPriority.app"
  rm -rf "$TARGET_APP"
  cp -R "$INSTALL_SOURCE_APP" "$TARGET_APP"
  codesign --verify --verbose=2 "$TARGET_APP"
  echo "==> Installed to $TARGET_APP"
else
  echo "==> Skipping local /Applications install (SKIP_INSTALL=1)"
fi
