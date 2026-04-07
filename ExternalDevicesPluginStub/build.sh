#!/bin/bash
# Build a stub x86_64 ExternalDevicesPlugin.plugin bundle.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/ExternalDevicesPlugin.plugin"

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"

clang -arch x86_64 -bundle -fobjc-arc \
  -framework Foundation \
  -o "$OUT/Contents/MacOS/ExternalDevicesPlugin" \
  "$DIR/AUIExternalDevicesLoader.m"

cat > "$OUT/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>English</string>
    <key>CFBundleExecutable</key><string>ExternalDevicesPlugin</string>
    <key>CFBundleIdentifier</key><string>edu.washington.bwark.acqui.ExternalDevices</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundlePackageType</key><string>BNDL</string>
    <key>CFBundleSignature</key><string>PhYZ</string>
    <key>CFBundleVersion</key><string>275</string>
    <key>NSPrincipalClass</key><string>AUIExternalDevicesLoader</string>
</dict>
</plist>
PLIST

echo "Built: $OUT"
file "$OUT/Contents/MacOS/ExternalDevicesPlugin"
