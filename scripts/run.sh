#!/usr/bin/env bash
# Baut die App, startet sie im Simulator und legt einen Screenshot ab.
# Damit lässt sich das Ergebnis auch ohne Blick auf den Bildschirm beurteilen.
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-light}"        # light | dark
OUT="${2:-build/screenshot-$MODE.png}"

[ -d PulseMeter.xcodeproj ] || xcodegen generate
DEVICE=$(scripts/sim.sh)
mkdir -p "$(dirname "$OUT")"

echo "Simulator $DEVICE wird gestartet…"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null

echo "Bauen…"
xcodebuild build \
  -project PulseMeter.xcodeproj \
  -scheme PulseMeter \
  -destination "id=$DEVICE" \
  -derivedDataPath build/DerivedData \
  -quiet \
  CODE_SIGNING_ALLOWED=NO

APP=$(find build/DerivedData/Build/Products -name "PulseMeter.app" -maxdepth 3 | head -1)
[ -n "$APP" ] || { echo "PulseMeter.app nicht gefunden" >&2; exit 1; }

xcrun simctl ui "$DEVICE" appearance "$MODE" || true
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" com.pulsemeter.app >/dev/null
sleep 3
xcrun simctl io "$DEVICE" screenshot "$OUT"
echo "Screenshot: $OUT"
