#!/bin/bash
# Build build/Spaceport.app
#   ./scripts/build.sh              build for this Mac
#   ./scripts/build.sh --universal  build for Apple silicon + Intel (used for releases)
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc not found. Install Xcode Command Line Tools first: xcode-select --install"
  exit 1
fi

VERSION="${VERSION:-$(cat VERSION)}"
APP="build/Spaceport.app"
SOURCES=(Sources/Spaceport/*.swift)
FLAGS=(-O -swift-version 5 -framework Cocoa -framework ApplicationServices)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

if [[ "${1:-}" == "--universal" ]]; then
  for arch in arm64 x86_64; do
    echo "→ Compiling ($arch)"
    swiftc "${FLAGS[@]}" -target "$arch-apple-macos12.0" "${SOURCES[@]}" -o "build/Spaceport-$arch"
  done
  lipo -create -output "$APP/Contents/MacOS/Spaceport" build/Spaceport-arm64 build/Spaceport-x86_64
  rm -f build/Spaceport-arm64 build/Spaceport-x86_64
else
  echo "→ Compiling"
  swiftc "${FLAGS[@]}" "${SOURCES[@]}" -o "$APP/Contents/MacOS/Spaceport"
fi

cp Resources/Info.plist "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "  (ad-hoc codesign failed; the app will still run locally)"

echo "✅ Built $APP (version $VERSION)"
