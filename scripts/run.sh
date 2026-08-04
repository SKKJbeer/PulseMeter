#!/usr/bin/env bash
# Startet die App im Simulator und legt Screenshots ab — je einen in Hell und
# Dunkel aus demselben Build.
#
# Gebaut wird nur, wenn noch kein Ergebnis vorliegt. Ein zweiter vollständiger
# Build kostet auf einem gemieteten macOS-Läufer mehrere Minuten und liefert
# dasselbe Programm.
set -euo pipefail
cd "$(dirname "$0")/.."
OUTDIR="${1:-build}"
DERIVED="${PULSE_DERIVED_DATA:-build/DerivedData}"

[ -d PulseMeter.xcodeproj ] || xcodegen generate
DEVICE=$(scripts/sim.sh)
mkdir -p "$OUTDIR"

APP=$(find "$DERIVED/Build/Products" -name "PulseMeter.app" -maxdepth 3 2>/dev/null | head -1 || true)
if [ -z "$APP" ]; then
  echo "Kein fertiger Build gefunden — es wird gebaut."
  xcodebuild build \
    -project PulseMeter.xcodeproj \
    -scheme PulseMeter \
    -destination "id=$DEVICE" \
    -derivedDataPath "$DERIVED" \
    -quiet \
    CODE_SIGNING_ALLOWED=NO
  APP=$(find "$DERIVED/Build/Products" -name "PulseMeter.app" -maxdepth 3 | head -1)
fi
[ -n "$APP" ] || { echo "PulseMeter.app nicht gefunden" >&2; exit 1; }
echo "Verwende $APP"

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
xcrun simctl install "$DEVICE" "$APP"

for MODE in light dark; do
  xcrun simctl ui "$DEVICE" appearance "$MODE" >/dev/null 2>&1 || true
  xcrun simctl terminate "$DEVICE" com.pulsemeter.app >/dev/null 2>&1 || true
  xcrun simctl launch "$DEVICE" com.pulsemeter.app >/dev/null
  sleep 4
  xcrun simctl io "$DEVICE" screenshot "$OUTDIR/screenshot-$MODE.png"
  echo "Screenshot: $OUTDIR/screenshot-$MODE.png"
done
