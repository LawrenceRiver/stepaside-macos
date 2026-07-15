#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/StepAside.app"
CONTENTS="$APP/Contents"
IDENTITY="${CODESIGN_IDENTITY:--}"

"$ROOT/scripts/generate-icons.sh"

if [[ "${UNIVERSAL_BINARY:-1}" == "1" ]]; then
  swift build --package-path "$ROOT" -c release --arch arm64 --arch x86_64
  BIN_DIR="$(swift build --package-path "$ROOT" -c release --arch arm64 --arch x86_64 --show-bin-path)"
else
  swift build --package-path "$ROOT" -c release
  BIN_DIR="$(swift build --package-path "$ROOT" -c release --show-bin-path)"
fi

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_DIR/StepAside" "$CONTENTS/MacOS/StepAside"
cp "$ROOT/Sources/StepAside/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Sources/StepAside/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
chmod 755 "$CONTENTS/MacOS/StepAside"

if [[ "$IDENTITY" == "-" ]]; then
  codesign --force --sign - "$APP"
else
  codesign --force --timestamp --options runtime --sign "$IDENTITY" "$APP"
fi

codesign --verify --deep --strict --verbose=2 "$APP"
echo "Created $APP"

