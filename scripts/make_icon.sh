#!/usr/bin/env bash
#
# assets/logo.svg 와 assets/logo-small.svg 에서 assets/AppIcon.icns 를 만든다.
#
# 아이콘은 만들어 둔 결과물을 저장소에 넣어 두므로 평소에는 돌릴 일이 없다.
# 로고를 고쳤을 때만 이 스크립트로 다시 만든다.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

BIG="assets/logo.svg"
SMALL="assets/logo-small.svg"
SET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "${SET}"

# qlmanage 는 출력 이름을 자기가 정하므로, 매번 빈 디렉터리에 뽑아서 옮긴다.
render() { # $1=svg  $2=크기  $3=결과 이름
    local tmp
    tmp="$(mktemp -d)"
    qlmanage -t -s "$2" -o "${tmp}" "$1" >/dev/null 2>&1
    local out
    out="$(ls "${tmp}"/*.png 2>/dev/null | head -1)"
    if [ -z "${out}" ]; then
        echo "❌ ${1} 을 ${2}px 로 그리지 못했다"
        exit 1
    fi
    sips -z "$2" "$2" "${out}" --out "${SET}/$3" >/dev/null
    rm -rf "${tmp}"
}

# 16 과 32 는 굵은 변형을 쓴다. 기본 로고를 그 크기로 줄이면 테두리가 0.2px 이 되어 사라진다.
echo "🎨 작은 크기..."
render "${SMALL}" 16   icon_16x16.png
render "${SMALL}" 32   icon_16x16@2x.png
render "${SMALL}" 32   icon_32x32.png
render "${SMALL}" 64   icon_32x32@2x.png

echo "🎨 큰 크기..."
render "${BIG}" 128  icon_128x128.png
render "${BIG}" 256  icon_128x128@2x.png
render "${BIG}" 256  icon_256x256.png
render "${BIG}" 512  icon_256x256@2x.png
render "${BIG}" 512  icon_512x512.png
render "${BIG}" 1024 icon_512x512@2x.png

iconutil -c icns "${SET}" -o assets/AppIcon.icns
rm -rf "$(dirname "${SET}")"
echo "✅ assets/AppIcon.icns"
