#!/bin/bash
# Builds Panbar in release mode and wraps it in build/Panbar.app.
#   --install   also copy it to ~/Applications and relaunch it there, which
#               gives Launch at Login a stable location to point at
set -euo pipefail

cd "$(dirname "$0")/.."
swift build -c release --product Panbar

app="build/Panbar.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/Panbar" "$app/Contents/MacOS/Panbar"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Panbar</string>
    <key>CFBundleIdentifier</key>
    <string>com.tookalan.panbar</string>
    <key>CFBundleName</key>
    <string>Panbar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$app"
echo "Built $app"

if [[ "${1:-}" == "--install" ]]; then
    dest="$HOME/Applications/Panbar.app"
    pkill -x Panbar || true
    mkdir -p "$HOME/Applications"
    rm -rf "$dest"
    cp -R "$app" "$dest"
    open "$dest"
    echo "Installed $dest"
fi
