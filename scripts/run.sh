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

# Immer mit `-pulse-reset`: Sonst zeigen die Bilder, was die Oberflächentests
# vorher im Simulator hinterlassen haben — bei einem frisch aufgesetzten Läufer
# also den leeren Zustand, bei einem wiederverwendeten irgendetwas dazwischen.
shoot() {
  local mode="$1" name="$2"
  shift 2
  xcrun simctl ui "$DEVICE" appearance "$mode" >/dev/null 2>&1 || true
  xcrun simctl terminate "$DEVICE" com.pulsemeter.app >/dev/null 2>&1 || true
  xcrun simctl launch "$DEVICE" com.pulsemeter.app -pulse-reset "$@" >/dev/null
  sleep 4
  xcrun simctl io "$DEVICE" screenshot "$OUTDIR/$name.png"
  echo "Screenshot: $OUTDIR/$name.png"
}

shoot light screenshot-light
shoot dark  screenshot-dark
shoot light screenshot-capture-light -pulse-capture
shoot dark  screenshot-capture-dark  -pulse-capture
shoot light screenshot-verlauf-light -pulse-verlauf
shoot dark  screenshot-verlauf-dark  -pulse-verlauf
shoot light screenshot-leer-light -pulse-empty
shoot dark  screenshot-leer-dark  -pulse-empty
shoot light screenshot-zaehler-light -pulse-zaehler
shoot dark  screenshot-zaehler-dark  -pulse-zaehler
