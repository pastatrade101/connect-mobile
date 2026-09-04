#!/usr/bin/env bash
#
# Build, re-sign and install on a physical iPhone.
#
# Why this exists: Flutter's native-assets pipeline emits
# objective_c.framework ad-hoc signed (Signature=adhoc, no TeamIdentifier),
# and Xcode's embed step does not re-sign it. An ad-hoc signature is fine on
# the simulator and REJECTED on a device, so `flutter install` fails with
#
#   Failed to verify code signature of .../objective_c.framework
#   0xe8008014 (The executable contains an invalid signature.)
#
# which reads like a provisioning or team-id problem and is not one. Clearing
# build/ and build/native_assets does not help — the framework comes out
# ad-hoc every time. So: build normally, re-sign anything still ad-hoc with
# the identity Xcode already used for Runner.app, re-seal the bundle (its
# seal covers the framework hashes), then install.
#
# Usage: tool/ios-device-install.sh [device-udid]
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${1:-$(xcrun devicectl list devices 2>/dev/null | awk '/available/ && /iPhone/ {print $3; exit}')}"
[ -n "$DEVICE" ] || { echo "No iPhone found. Pass the UDID as an argument."; exit 1; }

APP=build/ios/iphoneos/Runner.app
flutter build ios --release

# The identity Xcode chose for the app is the one every nested bundle must use.
IDENTITY=$(codesign -dvvv "$APP" 2>&1 | sed -n 's/^Authority=\(Apple Development:.*\)$/\1/p' | head -1)
[ -n "$IDENTITY" ] || { echo "Could not read the app's signing identity."; exit 1; }
echo "Signing identity: $IDENTITY"

ENT=$(mktemp -t ent).plist
codesign -d --entitlements :- --xml "$APP" > "$ENT" 2>/dev/null

resigned=0
for fw in "$APP"/Frameworks/*.framework; do
  if codesign -dvvv "$fw" 2>&1 | grep -q "^Signature=adhoc"; then
    echo "  re-signing $(basename "$fw") (was ad-hoc)"
    codesign --force --sign "$IDENTITY" --timestamp=none "$fw"
    resigned=$((resigned + 1))
  fi
done

if [ "$resigned" -gt 0 ]; then
  # The app's seal covers the old framework hashes, so it must be re-sealed.
  codesign --force --sign "$IDENTITY" --entitlements "$ENT" "$APP"
fi
rm -f "$ENT"

codesign --verify --deep --strict "$APP"
echo "Bundle verifies. Installing…"
xcrun devicectl device install app --device "$DEVICE" "$APP"
xcrun devicectl device process launch --device "$DEVICE" tz.co.makutano.makutanoConnect
