#!/usr/bin/env bash
#
# Archive, export and upload a build to TestFlight.
#
# No re-signing step, deliberately. The ad-hoc native-asset framework that
# breaks development installs (see tool/ios-device-install.sh) does NOT occur
# on this path — Xcode signs every embedded framework during archive and again
# during export. Verified 4 Sep 2026 on the exported IPA: every framework
# carries TeamIdentifier=25X3LP3BZ6 and `codesign --verify --deep --strict`
# passes. If you ever find yourself re-signing to make an upload work, stop:
# something has changed and the cause is worth finding.
#
# Signing and upload both use the Apple ID signed into Xcode, so no credential
# is stored here. The account needs App Manager (or Admin) on team 25X3LP3BZ6.
#
# A build number can only be used ONCE. Bump `version:` in pubspec.yaml
# (the +N suffix) before every upload; App Store Connect rejects a repeat.
#
# Usage: tool/testflight.sh
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM=25X3LP3BZ6
BUILD_DIR=$(mktemp -d -t makutano-testflight)
trap 'rm -rf "$BUILD_DIR"' EXIT

VERSION=$(grep -E '^version:' pubspec.yaml | sed 's/version: *//')
echo "== Shipping $VERSION  (bundle tz.co.makutano.makutanoConnect, team $TEAM)"
echo "   A build number cannot be reused. Ctrl-C now if ${VERSION##*+} has been uploaded before."
sleep 3

echo "== Archiving"
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
  -archivePath "$BUILD_DIR/Runner.xcarchive" -destination "generic/platform=iOS" \
  -allowProvisioningUpdates archive 2>&1 | tail -3

APP="$BUILD_DIR/Runner.xcarchive/Products/Applications/Runner.app"
echo "== Checking the archive before it goes anywhere"
codesign --verify --deep --strict "$APP"
for fw in "$APP"/Frameworks/*.framework; do
  if codesign -dvvv "$fw" 2>&1 | grep -q '^Signature=adhoc'; then
    echo "REFUSING TO UPLOAD: $(basename "$fw") is ad-hoc signed. Apple will reject this." >&2
    exit 1
  fi
done
echo "   every embedded framework is properly signed"

cat > "$BUILD_DIR/UploadOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>destination</key><string>upload</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

echo "== Uploading to App Store Connect"
xcodebuild -exportArchive -archivePath "$BUILD_DIR/Runner.xcarchive" \
  -exportOptionsPlist "$BUILD_DIR/UploadOptions.plist" \
  -exportPath "$BUILD_DIR/upload" -allowProvisioningUpdates 2>&1 | tail -8

echo
echo "Uploaded. Apple processes the build for a few minutes before it appears in"
echo "TestFlight, and it needs export-compliance answered before testers get it."
