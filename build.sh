#!/bin/bash
# Builds Keys and assembles "build/Keys.app".
#
# Signing: the device key's handle lives in the Keychain, which remembers the app by its
# signature. Set KEYS_SIGNING_IDENTITY to a code-signing identity from your keychain to keep the
# same signature across builds, so macOS stops asking whether Keys may read it after every
# rebuild. `scripts/create-signing-cert.sh` creates a local one. Without it, or with
# KEYS_SIGNING_IDENTITY=-, the app is signed ad hoc.
#
# Releases also set KEYS_VERSION, stamped into the bundle's Info.plist, and KEYS_OUTPUT_DIR, so
# packaging never replaces the app you are running from build/.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="${KEYS_OUTPUT_DIR:-build}/Keys.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Keys "$APP/Contents/MacOS/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
# The interface's translations, where macOS and `Interface` look for them (see Localization.swift).
cp -R Sources/Keys/Resources/*.lproj "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/"
if [[ -n "${KEYS_VERSION:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $KEYS_VERSION" "$APP/Contents/Info.plist"
fi

IDENTITY="${KEYS_SIGNING_IDENTITY:-Keys Local Signing}"
if [[ "$IDENTITY" != "-" ]] && security find-identity -p codesigning | grep -q "$IDENTITY"; then
  codesign --force --options runtime --sign "$IDENTITY" "$APP"
elif [[ -n "${KEYS_SIGNING_IDENTITY:-}" && "$KEYS_SIGNING_IDENTITY" != "-" ]]; then
  # An identity asked for by name must be used: a build signed ad hoc by accident would lose
  # access to the device key in the Keychain.
  echo "error: signing identity \"$KEYS_SIGNING_IDENTITY\" not found" >&2
  exit 1
else
  codesign --force --sign - "$APP"
fi

echo "Built: $APP"
echo "Open it with: open \"$APP\""
