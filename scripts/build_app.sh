#!/usr/bin/env bash
set -e

# Navigate to project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

echo "🔨 Building OpenSide (Release)..."
swift build -c release

APP_NAME="OpenSide"
BUNDLE_DIR="${ROOT_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Packaging ${APP_NAME}.app..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy binary
cp "${ROOT_DIR}/.build/release/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

# App icon. Displayed by the standard About panel invoked from 'About'.
# Run scripts/make_icon.sh to regenerate if the logo changes.
cp "${ROOT_DIR}/assets/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"

# Generate Info.plist (LSUIElement = true: configure as agent / menu bar only app)
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.openside.app</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 bldev2473. Licensed under the MIT License.</string>
</dict>
</plist>
EOF

# Sign the application bundle.
#
# Although the linker signs the executable with an ad-hoc signature, that does not cover the bundle.
# Info.plist and Resources remain unsealed, and identity resolves to the binary name instead of bundle ID.
# Features requiring a stable identity (like login item registration) are rejected as a result.
#
# Sign the entire bundle using an available certificate, falling back to ad-hoc. Ad-hoc signatures
# are valid only on this local Mac; distributable builds must be signed with Developer ID and notarized.
SIGN_IDENTITY="${OPENSIDE_SIGN_IDENTITY:-}"
if [ -z "${SIGN_IDENTITY}" ]; then
    for candidate in "Developer ID Application" "Apple Development"; do
        if security find-identity -v -p codesigning | grep -q "${candidate}"; then
            SIGN_IDENTITY="${candidate}"
            break
        fi
    done
fi

if [ -n "${SIGN_IDENTITY}" ]; then
    echo "🔏 Signing with ${SIGN_IDENTITY}..."
    # Secure timestamps are required when signing with Developer ID. Notarization mandates it,
    # so submissions signed with --timestamp=none are rejected. Involves a network request.
    # Skipped for local development certificates.
    TIMESTAMP_FLAG="--timestamp=none"
    case "${SIGN_IDENTITY}" in
        "Developer ID Application"*) TIMESTAMP_FLAG="--timestamp" ;;
    esac
    codesign --force --options runtime ${TIMESTAMP_FLAG} \
        --sign "${SIGN_IDENTITY}" "${BUNDLE_DIR}"
else
    echo "🔏 No certificate found. Signing ad-hoc (valid on this Mac only)..."
    codesign --force --sign - "${BUNDLE_DIR}"
fi

codesign --verify --strict "${BUNDLE_DIR}"

echo "✅ Successfully built and packaged ${BUNDLE_DIR}"
