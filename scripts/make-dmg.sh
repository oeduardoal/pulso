#!/bin/bash
# Builds Pulso, signs it with Developer ID, packs it into a DMG, then notarizes and staples the DMG.
# Used by the release workflow and for local releases.
#
# Usage: scripts/make-dmg.sh <version>
#
# Environment:
#   SIGNING_IDENTITY  Code signing identity (default "Developer ID Application")
#   DEVELOPMENT_TEAM  Team ID (default 6HC4RKRHXD)
#   BUILD_NUMBER      CFBundleVersion (default: number of commits on HEAD)
#   ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
#                     App Store Connect API key used by notarytool
#   NOTARIZE=0        Skip notarization, for a local dry run
#
# Output: build/Pulso-<version>.dmg and build/Pulso-<version>.dmg.sha256
set -euo pipefail

VERSION="${1:?usage: scripts/make-dmg.sh <version>}"
IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"
TEAM="${DEVELOPMENT_TEAM:-6HC4RKRHXD}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD)}"
NOTARIZE="${NOTARIZE:-1}"

cd "$(dirname "$0")/.."
DERIVED=build/release
APP="$DERIVED/Build/Products/Release/Pulso.app"
DMG="build/Pulso-$VERSION.dmg"

echo "==> Building Pulso $VERSION ($BUILD_NUMBER) signed with \"$IDENTITY\""
xcodegen generate --quiet
rm -rf "$DERIVED"
xcodebuild -project Pulso.xcodeproj -scheme Pulso -configuration Release -derivedDataPath "$DERIVED" \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" DEVELOPMENT_TEAM="$TEAM" \
  OTHER_CODE_SIGN_FLAGS="--timestamp" CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  -quiet build
codesign --verify --deep --strict --verbose=1 "$APP"

echo "==> Packing $DMG"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Pulso.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Pulso $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
codesign --sign "$IDENTITY" --timestamp "$DMG"

if [[ "$NOTARIZE" != "0" ]]; then
  : "${ASC_KEY_ID:?set ASC_KEY_ID}" "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}" "${ASC_KEY_PATH:?set ASC_KEY_PATH}"
  echo "==> Notarizing (this usually takes a few minutes)"
  xcrun notarytool submit "$DMG" --key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --wait
  xcrun stapler staple "$DMG"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
else
  echo "==> Skipping notarization (NOTARIZE=0)"
fi

(cd build && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "==> Done: $DMG"
cat "$DMG.sha256"
