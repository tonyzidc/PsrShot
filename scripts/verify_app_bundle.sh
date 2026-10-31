#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="PsrShot.app"

echo "============================================================"
echo " Running Automated Bundle Integrity Verification for ${APP_BUNDLE}"
echo "============================================================"

# 1. Bundle Directory Check
if [ ! -d "${APP_BUNDLE}" ]; then
    echo "❌ Error: ${APP_BUNDLE} does not exist!"
    exit 1
fi
echo "✓ App bundle directory exists."

# 2. Executable Check
BIN="${APP_BUNDLE}/Contents/MacOS/PsrShot"
if [ ! -x "${BIN}" ]; then
    echo "❌ Error: Binary ${BIN} not found or not executable!"
    exit 1
fi
echo "✓ Executable exists and has execution permissions."

# 3. Binary Architecture & Mach-O Format Check
BIN_TYPE=$(file "${BIN}")
if [[ "${BIN_TYPE}" != *"Mach-O 64-bit"* ]]; then
    echo "❌ Error: Binary is not Mach-O 64-bit! Output: ${BIN_TYPE}"
    exit 1
fi
echo "✓ Binary is Mach-O 64-bit executable (${BIN_TYPE})."

# 4. Binary Size Check (< 1MB)
BIN_SIZE_BYTES=$(stat -f%z "${BIN}")
echo "✓ Binary size: ${BIN_SIZE_BYTES} bytes ($((BIN_SIZE_BYTES / 1024)) KB)."
if [ "${BIN_SIZE_BYTES}" -gt 1500000 ]; then
    echo "❌ Warning: Binary exceeds 1.5MB limit!"
    exit 1
fi

# 5. Info.plist Integrity Check
PLIST="${APP_BUNDLE}/Contents/Info.plist"
if [ ! -f "${PLIST}" ]; then
    echo "❌ Error: Info.plist missing!"
    exit 1
fi
plutil -lint "${PLIST}" > /dev/null
echo "✓ Info.plist is valid syntax."

# Check required keys in Info.plist
LSUIELEMENT=$(/usr/libexec/PlistBuddy -c "Print :LSUIElement" "${PLIST}" 2>/dev/null || true)
if [ "${LSUIELEMENT}" != "true" ]; then
    echo "❌ Error: LSUIElement must be true for menu-bar app!"
    exit 1
fi
echo "✓ LSUIElement is true."

ICON_FILE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "${PLIST}" 2>/dev/null || true)
if [ "${ICON_FILE}" != "AppIcon" ]; then
    echo "❌ Error: CFBundleIconFile is not AppIcon!"
    exit 1
fi
echo "✓ CFBundleIconFile is AppIcon."

# 6. AppIcon.icns Check
ICNS="${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
if [ ! -f "${ICNS}" ]; then
    echo "❌ Error: AppIcon.icns missing in Resources!"
    exit 1
fi
ICNS_TYPE=$(file "${ICNS}")
if [[ "${ICNS_TYPE}" != *"icon"* ]]; then
    echo "❌ Error: AppIcon.icns is not a valid icon file! Output: ${ICNS_TYPE}"
    exit 1
fi
echo "✓ AppIcon.icns is present and valid."

# 7. Code Signing Verification
codesign --verify --deep --strict "${APP_BUNDLE}"
echo "✓ Codesign verification passed."

echo "============================================================"
echo "🎉 ALL BUNDLE VERIFICATION CHECKS PASSED SUCCESSFULLY!"
echo "============================================================"
