#!/bin/zsh
# Build ContinuityCapture.app (universal, ad-hoc signed, no dependencies)
# and install it to ~/Applications so shortcuts can launch it by NAME
# (works from any clone location, any username, any machine).
set -e
cd "$(dirname "$0")"

APP=ContinuityCapture.app
BIN="$APP/Contents/MacOS/ContinuityCapture"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

# Universal binary (Apple Silicon + Intel), deployment target macOS 14
swiftc -O -target arm64-apple-macos14.0  -o /tmp/cc-arm64  main.swift
swiftc -O -target x86_64-apple-macos14.0 -o /tmp/cc-x86_64 main.swift
lipo -create /tmp/cc-arm64 /tmp/cc-x86_64 -output "$BIN"
rm -f /tmp/cc-arm64 /tmp/cc-x86_64

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>ContinuityCapture</string>
	<key>CFBundleIdentifier</key><string>com.techjuicelab.continuitycapture</string>
	<key>CFBundleName</key><string>ContinuityCapture</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.6</string>
	<key>CFBundleVersion</key><string>7</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>LSUIElement</key><true/>
	<key>NSHighResolutionCapable</key><true/>
	<key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# App icon (generated from icon.png with stock sips/iconutil)
if [ -f icon.png ]; then
  ICONSET=/tmp/cc-appicon.iconset
  rm -rf "$ICONSET"; mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z $s $s icon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z $d $d icon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  mkdir -p "$APP/Contents/Resources"
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  rm -rf "$ICONSET"
fi

codesign --force --sign - "$APP"

# Install to ~/Applications and register with LaunchServices
mkdir -p "$HOME/Applications"
ditto "$APP" "$HOME/Applications/$APP"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$HOME/Applications/$APP" || true

echo "built:     $PWD/$APP"
echo "installed: $HOME/Applications/$APP"
echo "launch:    open -na ContinuityCapture --args photo"
