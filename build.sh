#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
BUILD_DIR="${COPYPOP_BUILD_DIR:-$PWD/.build-release}"
mkdir -p "$BUILD_DIR/cache" "$BUILD_DIR/CopyPop.app/Contents/MacOS" "$BUILD_DIR/CopyPop.app/Contents/Resources"
for arch in arm64 x86_64; do
  xcrun swiftc -O -swift-version 5 -target "$arch-apple-macosx13.0" -module-cache-path "$BUILD_DIR/cache" Sources/CopyPop/*.swift -o "$BUILD_DIR/CopyPop-$arch"
done
lipo -create "$BUILD_DIR/CopyPop-arm64" "$BUILD_DIR/CopyPop-x86_64" -output "$BUILD_DIR/CopyPop.app/Contents/MacOS/CopyPop"
cp Info.plist "$BUILD_DIR/CopyPop.app/Contents/Info.plist"
xattr -cr "$BUILD_DIR/CopyPop.app"
codesign --force --sign - "$BUILD_DIR/CopyPop.app"
codesign --verify --strict "$BUILD_DIR/CopyPop.app"
echo "Built: $BUILD_DIR/CopyPop.app"
