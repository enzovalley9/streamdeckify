#!/bin/sh
# Builds "Streamdeckify Keys" (macos/keys/) into cache/Streamdeckify Keys.app,
# signed ad hoc. The server runs this by itself the first time a key button
# needs it. It needs Xcode's command line tools (xcode-select --install).
# Each build changes the signature, and macOS stops applying the Accessibility
# permission of the old build: after a rebuild, remove the app from the list in
# System Settings and let it ask again.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/cache/Streamdeckify Keys.app"
mkdir -p "$APP/Contents/MacOS"
cp "$ROOT/macos/keys/Info.plist" "$APP/Contents/Info.plist"
xcrun swiftc -O "$ROOT/macos/keys/main.swift" -o "$APP/Contents/MacOS/keys"
codesign --force --sign - --identifier local.streamdeckify.keys "$APP"
echo "$APP"
