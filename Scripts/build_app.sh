#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Perch"
BUILD_DIR=".build/release"
APP_BUNDLE="build/${APP_NAME}.app"

echo "Building ${APP_NAME} (release)..."
swift build -c release

echo "Packaging ${APP_NAME}.app..."
rm -rf "build"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

# Copy SPM-bundled resources (e.g. the status bar icon) alongside the executable.
RESOURCE_BUNDLE="${BUILD_DIR}/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "${RESOURCE_BUNDLE}" ]; then
    cp -R "${RESOURCE_BUNDLE}" "${APP_BUNDLE}/Contents/Resources/"
fi

codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true

echo "Built ${APP_BUNDLE}"
echo "Run with: open ${APP_BUNDLE}"
