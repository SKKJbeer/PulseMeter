#!/usr/bin/env bash
# Führt alles aus, was geprüft werden kann. Ohne Argumente: alles.
set -euo pipefail
cd "$(dirname "$0")/.."
SCOPE="${1:-all}"

say() { printf "\n\033[1m%s\033[0m\n" "$1"; }

if [ "$SCOPE" = "all" ] || [ "$SCOPE" = "core" ]; then
  say "PulseCore"
  ( cd Packages/PulseCore && swift test )
fi

if [ "$SCOPE" = "all" ] || [ "$SCOPE" = "data" ]; then
  say "PulseData"
  # Braucht SwiftData und damit eine Apple-Plattform; auf dem Mac reicht das
  # macOS-Ziel des Pakets, ein Simulator ist dafür nicht nötig.
  ( cd Packages/PulseData && swift test )
fi

if [ "$SCOPE" = "all" ] || [ "$SCOPE" = "app" ]; then
  say "App im Simulator"
  [ -d PulseMeter.xcodeproj ] || xcodegen generate
  DEVICE=$(scripts/sim.sh)
  # Dasselbe Ableseverzeichnis wie run.sh, damit die Screenshots den bereits
  # gebauten Stand verwenden und nicht ein zweites Mal übersetzen.
  # Ohne `-quiet` und in eine Datei: Mit `-quiet` nennt xcodebuild zwar die
  # Namen der gefallenen Prüfungen, aber nicht den Grund. Ein Lauf, der sagt
  # „testX ist gefallen" und verschweigt warum, kostet eine ganze Runde von
  # zwanzig Minuten fürs Raten — und genau das ist einmal passiert.
  mkdir -p build
  LOG="build/xcodebuild-test.log"
  if xcodebuild test \
      -project PulseMeter.xcodeproj \
      -scheme PulseMeter \
      -destination "id=$DEVICE" \
      -derivedDataPath "${PULSE_DERIVED_DATA:-build/DerivedData}" \
      CODE_SIGNING_ALLOWED=NO > "$LOG" 2>&1; then
    grep -E "Executed [0-9]+ test" "$LOG" | tail -3
  else
    status=$?
    echo
    echo "--- Gefallene Prüfungen, mit Begründung ---"
    grep -E "error:|Assertion Failure|XCTAssert|Failing tests:|^[[:space:]]+[A-Za-z]+Tests\." "$LOG" \
      | tail -80
    echo "--- Ende ---"
    exit $status
  fi
fi

printf "\n\033[32mAlles durchgelaufen.\033[0m\n"
