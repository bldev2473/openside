#!/usr/bin/env bash
set -e

# 프로젝트 디렉토리 이동
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

# 바이너리 복사
cp "${ROOT_DIR}/.build/release/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

# 아이콘. '정보' 가 띄우는 표준 About 패널이 이것을 보여준다.
# 로고를 고쳤으면 scripts/make_icon.sh 로 다시 만든다.
cp "${ROOT_DIR}/assets/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"

# Info.plist 생성 (LSUIElement = true: 메뉴바 상주 앱 설정)
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

# 번들에 서명한다.
#
# 링커가 실행 파일에 ad-hoc 서명을 붙여 주기는 하지만 그것은 번들을 덮지 않는다. Info.plist
# 와 Resources 가 봉인되지 않고, 신원도 번들 식별자가 아니라 실행 파일 이름으로 남는다.
# 로그인 항목 등록처럼 안정된 신원을 요구하는 기능이 그 때문에 거부된다.
#
# 인증서가 있으면 그것으로, 없으면 ad-hoc 으로 번들 전체를 서명한다. ad-hoc 은 이 맥에서만
# 유효하므로, 남에게 나눠 줄 빌드라면 Developer ID 로 서명하고 공증까지 받아야 한다.
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
    # Developer ID 로 서명할 때는 보안 타임스탬프를 받아야 한다. 공증이 그것을 요구하므로
    # --timestamp=none 으로 서명한 것은 제출해도 거부된다. 네트워크를 한 번 탄다.
    # 로컬 개발 서명은 그럴 필요가 없어 건너뛴다.
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
