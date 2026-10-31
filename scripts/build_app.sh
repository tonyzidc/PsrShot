#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PsrShot"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> 1. Compiling ${APP_NAME} in release configuration..."
swift build -c release

echo "==> 2. Creating macOS App Bundle..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Find the built release binary
BUILD_BIN="$(swift build -c release --show-bin-path)/${APP_NAME}"
if [ ! -f "${BUILD_BIN}" ]; then
    echo "Error: Binary not found at ${BUILD_BIN}"
    exit 1
fi

cp "${BUILD_BIN}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist
cp "Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"

# Generate a high quality App Icon if iconutil / python is available
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

echo "==> 3. Ad-hoc code signing app bundle..."
codesign --force --deep --sign - "${BUNDLE_DIR}"

echo ""
echo "============================================================"
echo " Successfully built: ${BUNDLE_DIR}"
echo " Path: $(pwd)/${BUNDLE_DIR}"
echo " To run: open ${BUNDLE_DIR}"
echo "============================================================"
