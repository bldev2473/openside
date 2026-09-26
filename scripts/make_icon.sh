#!/usr/bin/env bash
#
# Generates assets/AppIcon.icns from assets/logo.svg and assets/logo-small.svg.
#
# Generated icon assets are committed to the repository, so running this script is rarely needed.
# Run only when updating or redesigning the logo.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

BIG="assets/logo.svg"
SMALL="assets/logo-small.svg"
SET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "${SET}"

# qlmanage determines output filenames automatically; render to empty temporary directory and move.
render() { # $1=svg  $2=size  $3=output name
    local tmp
    tmp="$(mktemp -d)"
    qlmanage -t -s "$2" -o "${tmp}" "$1" >/dev/null 2>&1
    local out
    out="$(ls "${tmp}"/*.png 2>/dev/null | head -1)"
    if [ -z "${out}" ]; then
        echo "❌ Failed to render ${1} at ${2}px"
        exit 1
    fi
    sips -z "$2" "$2" "${out}" --out "${SET}/$3" >/dev/null
    rm -rf "${tmp}"
}

# Use bold variant for 16 and 32 sizes. Scaling standard logo causes borders to shrink to 0.2px and vanish.
echo "🎨 Small sizes..."
render "${SMALL}" 16   icon_16x16.png
render "${SMALL}" 32   icon_16x16@2x.png
render "${SMALL}" 32   icon_32x32.png
render "${SMALL}" 64   icon_32x32@2x.png

echo "🎨 Large sizes..."
render "${BIG}" 128  icon_128x128.png
render "${BIG}" 256  icon_128x128@2x.png
render "${BIG}" 256  icon_256x256.png
render "${BIG}" 512  icon_256x256@2x.png
render "${BIG}" 512  icon_512x512.png
render "${BIG}" 1024 icon_512x512@2x.png

iconutil -c icns "${SET}" -o assets/AppIcon.icns
rm -rf "$(dirname "${SET}")"
echo "✅ assets/AppIcon.icns"
