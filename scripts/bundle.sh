#!/bin/bash
# Builds Panbar in release mode and wraps it in build/Panbar.app.
#   --install   also copy it to ~/Applications and relaunch it there, which
#               gives Launch at Login a stable location to point at
#   --release   build a universal (Apple silicon + Intel) app and zip it as
#               build/Panbar-<version>.zip for a GitHub release
set -euo pipefail

version="0.1.0"
bundle_id="com.systemicdream.panbar"

cd "$(dirname "$0")/.."

mode="${1:-}"
if [[ "$mode" == "--release" ]]; then
    arch_flags=(--arch arm64 --arch x86_64)
else
    arch_flags=()
fi
swift build -c release --product Panbar ${arch_flags[@]+"${arch_flags[@]}"}
bin_dir="$(swift build -c release ${arch_flags[@]+"${arch_flags[@]}"} --show-bin-path)"

app="build/Panbar.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/Panbar" "$app/Contents/MacOS/Panbar"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Panbar</string>
    <key>CFBundleIdentifier</key>
    <string>$bundle_id</string>
    <key>CFBundleName</key>
    <string>Panbar</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$version</string>
    <key>CFBundleVersion</key>
    <string>$version</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$app"
echo "Built $app"

case "$mode" in
--install)
    dest="$HOME/Applications/Panbar.app"
    pkill -x Panbar || true
    mkdir -p "$HOME/Applications"
    rm -rf "$dest"
    cp -R "$app" "$dest"
    open "$dest"
    echo "Installed $dest"
    ;;
--release)
    zip="build/Panbar-$version.zip"
    rm -f "$zip"
    ditto -c -k --keepParent "$app" "$zip"
    echo "Packaged $zip ($(lipo -archs "$app/Contents/MacOS/Panbar"))"
    ;;
esac
