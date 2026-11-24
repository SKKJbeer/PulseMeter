#!/usr/bin/env bash
# Führt alles aus, was geprüft werden kann. Ohne Argumente: alles.
set -euo pipefail
cd "$(dirname "$0")/.."
SCOPE="${1:-all}"

say() { printf "\n\033[1m%s\033[0m\n" "$1"; }

if [ "$SCOPE" = "all" ] || [ "$SCOPE" = "core" ]; then
  say "PulseCore"
  scripts/test-core.sh
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
  DEVICE=$(scripts/sim.sh "${PULSE_FAMILIE:-iphone}")
  # Dasselbe Ableseverzeichnis wie run.sh, damit die Screenshots den bereits
  # gebauten Stand verwenden und nicht ein zweites Mal übersetzen.
  # Ohne `-quiet`, vollständig in eine Datei **und** gefiltert auf die
  # Konsole. Zwei Blindstellen sind daran schuld:
  #
  # 1. Mit `-quiet` nennt xcodebuild die Namen der gefallenen Prüfungen, aber
  #    nicht den Grund. Ein Lauf, der „testX ist gefallen" sagt und schweigt,
  #    kostet zwanzig Minuten fürs Raten.
  # 2. Leitet man stattdessen alles in eine Datei und gibt die Begründungen
  #    nur im Fehlerzweig aus, sieht man bei einem **abgebrochenen** Lauf gar
  #    nichts — der Zweig wird nie erreicht. Genau so ging ein Lauf verloren.
  #
  # Deshalb `tee`: Die Datei bleibt vollständig, und auf der Konsole läuft
  # mit, wie weit die Prüfungen gekommen sind. Wo ein Lauf abbricht, ist dann
  # ohne Artefakt zu sehen.
  mkdir -p build
  LOG="build/xcodebuild-test.log"

  # **Der Simulator läuft, bevor der erste Test startet, seit 0.139.1.** Der erste Test
  # (`testAddingAMeterFromTheMetersTab`) braucht auch in grünen Läufen
  # 72 Sekunden (gemessen, Lauf zu 0.138.0), die anderen zwei bis zwölf. Am 24. Oktober fiel er
  # mit „Timed out while launching application via Xcode" nach 70 Sekunden durch, bei
  # unverändertem Code. **Vermutung, nicht bewiesen:** Der Start des Geräts steckt in der Zeit
  # des ersten Tests. `bootstatus -b` wartet, bis das Gerät fertig ist. Ob es hilft, zeigt der
  # nächste Lauf: Steht der Test danach bei ein paar Sekunden, war es das.
  # Schlägt der Befehl fehl, geht es trotzdem weiter: Er ist eine Hilfe, keine Voraussetzung.
  xcrun simctl boot "$DEVICE" 2>/dev/null || true
  xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || true

  # **In der CI bekommt eine gefallene Oberflächenprüfung einen zweiten Anlauf,
  # seit 0.180.1.** Vom 22. bis 24. November fiel der iPad-Zweig neunmal, jedes
  # Mal an einer einzelnen Prüfung, die im Lauf davor oder danach mit demselben
  # Code grün war (Kamera-Vorführung, Kaufblatt, Tabellenimport). Jeder rote
  # Lauf kostete einen neuen von über einer Stunde und hielt die PRs dahinter
  # fest. Ein echter Fehler fällt zweimal und bleibt rot; was erst im zweiten
  # Anlauf durchgeht, steht unten als Warnung mit Namen da, damit es niemand
  # übersieht. Lokal bleibt es bei einem Anlauf: Dort soll man das Wackeln sehen.
  WIEDERHOLEN=()
  if [ -n "${CI:-}" ]; then
    WIEDERHOLEN=(-retry-tests-on-failure -test-iterations 2)
  fi

  set +e
  xcodebuild test \
      -project PulseMeter.xcodeproj \
      -scheme PulseMeter \
      -destination "id=$DEVICE" \
      -derivedDataPath "${PULSE_DERIVED_DATA:-build/DerivedData}" \
      ${WIEDERHOLEN[@]+"${WIEDERHOLEN[@]}"} \
      CODE_SIGNING_ALLOWED=NO 2>&1 \
    | tee "$LOG" \
    | grep --line-buffered -E "Test Case .*(started|passed|failed)|Test Suite .*(passed|failed)|Executed [0-9]+ test|error:|Assertion Failure|\*\* TEST|^MESSUNG "
  status=${PIPESTATUS[0]}
  set -e

  if [ "$status" -ne 0 ]; then
    echo
    echo "--- Gefallene Prüfungen, mit Begründung ---"
    # `-A 12`: Eine Begründung darf mehrzeilig sein. Ohne das kam nur ihre
    # erste Zeile an, und der Rest — bei einer Prüfung, die den halben
    # Zugänglichkeitsbaum ausgibt, die eigentliche Auskunft — blieb im
    # Artefakt liegen.
    grep -A 12 -E "error:|Assertion Failure|XCTAssert|Failing tests:|^[[:space:]]+[A-Za-z]+Tests\." "$LOG" \
      | tail -100
    echo "--- Ende ---"
    exit "$status"
  fi

  # Grün, aber nicht im ersten Anlauf: benennen, nicht verschweigen.
  wackelig=$(grep -oE "Test Case '-\[[^]]+\]' failed" "$LOG" | sed -E "s/.*[ .]([A-Za-z0-9_]+)\]' failed/\1/" | sort -u || true)
  if [ -n "$wackelig" ]; then
    for name in $wackelig; do
      echo "::warning::Wackelige Oberflächenprüfung (erst im zweiten Anlauf grün): $name"
    done
  fi
fi

printf "\n\033[32mAlles durchgelaufen.\033[0m\n"
