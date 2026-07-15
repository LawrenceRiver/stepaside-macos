#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DMG="$ROOT/dist/StepAside.dmg"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/stepaside-dmg.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT

"$ROOT/scripts/build-app.sh"

cp -R "$ROOT/dist/StepAside.app" "$STAGING/StepAside.app"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"

hdiutil create \
  -volname StepAside \
  -srcfolder "$STAGING" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  "$DMG"

hdiutil verify "$DMG"
echo "Created $DMG"

