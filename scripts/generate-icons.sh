#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MASTER="$ROOT/Brand/AppIcon-1024.png"
ICONSET="$ROOT/Brand/AppIcon.iconset"
OUTPUT="$ROOT/Sources/StepAside/Resources/AppIcon.icns"

for tool in sips iconutil; do
  command -v "$tool" >/dev/null || {
    echo "Required macOS tool is missing: $tool" >&2
    exit 1
  }
done

[[ -f "$MASTER" ]] || {
  echo "Missing icon master: $MASTER" >&2
  exit 1
}

width="$(sips -g pixelWidth "$MASTER" | awk '/pixelWidth/ {print $2}')"
height="$(sips -g pixelHeight "$MASTER" | awk '/pixelHeight/ {print $2}')"
[[ "$width" == "1024" && "$height" == "1024" ]] || {
  echo "AppIcon-1024.png must be exactly 1024x1024; got ${width}x${height}." >&2
  exit 1
}

rm -rf "$ICONSET"
mkdir -p "$ICONSET" "$(dirname "$OUTPUT")"

render() {
  local size="$1"
  local filename="$2"
  sips -z "$size" "$size" "$MASTER" --out "$ICONSET/$filename" >/dev/null
}

render 16 icon_16x16.png
render 32 icon_16x16@2x.png
render 32 icon_32x32.png
render 64 icon_32x32@2x.png
render 128 icon_128x128.png
render 256 icon_128x128@2x.png
render 256 icon_256x256.png
render 512 icon_256x256@2x.png
render 512 icon_512x512.png
render 1024 icon_512x512@2x.png

rm -f "$OUTPUT"
iconutil -c icns "$ICONSET" -o "$OUTPUT"
echo "Created $OUTPUT"

