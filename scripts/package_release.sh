#!/usr/bin/env bash
set -euo pipefail

echo "==> 1. Building App Bundle..."
./scripts/build_app.sh

echo "==> 2. Verifying App Bundle..."
./scripts/verify_app_bundle.sh

echo "==> 3. Creating PsrShot-macOS.zip..."
rm -f PsrShot-macOS.zip
ditto -c -k --sequesterRsrc --keepParent PsrShot.app PsrShot-macOS.zip

echo "==> 4. Creating PsrShot.dmg..."
rm -f PsrShot.dmg
DMG_TEMP_DIR="dmg_temp"
rm -rf "${DMG_TEMP_DIR}"
mkdir -p "${DMG_TEMP_DIR}"
cp -R PsrShot.app "${DMG_TEMP_DIR}/"
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

hdiutil create -volname "PsrShot" \
    -srcfolder "${DMG_TEMP_DIR}" \
    -ov -format UDZO \
    PsrShot.dmg

rm -rf "${DMG_TEMP_DIR}"

echo ""
echo "============================================================"
echo " Release Packages Built Successfully:"
echo " - PsrShot-macOS.zip ($(ls -lh PsrShot-macOS.zip | awk '{print $5}'))"
echo " - PsrShot.dmg ($(ls -lh PsrShot.dmg | awk '{print $5}'))"
echo " SHA256 Checksums:"
shasum -a 256 PsrShot-macOS.zip PsrShot.dmg
echo "============================================================"
