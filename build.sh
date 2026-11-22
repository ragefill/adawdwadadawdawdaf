#!/usr/bin/env bash
set -euo pipefail

# JailbreakLite build script (macOS + Xcode required)
# Produces an .xcarchive and an unsigned/debug-signed .ipa depending on your signing setup.

PROJECT="JailbreakLite.xcodeproj"
SCHEME="JailbreakLite"
CONFIG="Release"
DERIVED="build/DerivedData"
ARCHIVE="build/JailbreakLite.xcarchive"
EXPORT="build/export"

echo "[*] Cleaning build directory"
rm -rf build
mkdir -p build

echo "[*] Archiving"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED" \
  -archivePath "$ARCHIVE" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_STYLE=Manual \
  AD_HOC_CODE_SIGNING_ALLOWED=YES \
  archive

echo "[*] Exporting IPA"
# If you have a valid signing setup, remove CODE_SIGNING_* overrides above and use ExportOptions.plist.
# For an unsigned IPA payload, we package the .app manually.
APP_PATH="$ARCHIVE/Products/Applications/JailbreakLite.app"
if [ ! -d "$APP_PATH" ]; then
  echo "[!] App not found at $APP_PATH"
  exit 1
fi

mkdir -p "$EXPORT/Payload"
cp -R "$APP_PATH" "$EXPORT/Payload/"
(cd "$EXPORT" && zip -qr ../JailbreakLite-unsigned.ipa Payload)
rm -rf "$EXPORT/Payload"

echo "[+] Built: build/JailbreakLite-unsigned.ipa"
echo "[!] Unsigned IPA must be signed/install via your preferred method (AltStore, Sideloadly, TrollStore, ldid, etc.)"
