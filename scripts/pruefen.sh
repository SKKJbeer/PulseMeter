#!/usr/bin/env bash
# Alles, was die CI prüft — nur hier, auf dem Mac, und in einem Bruchteil der
# Zeit.
#
# **Warum es das gibt.** Ein CI-Lauf braucht zwölf bis fünfzehn Minuten, und
# das meiste davon ist Arbeit, die auf einem Mac schon getan ist: Läufer
# anfordern, Repository holen, Homebrew, XcodeGen, und vor allem ein Build von
# null. Lokal bleibt das Ableseverzeichnis liegen; nach dem ersten Durchgang
# baut Xcode nur noch das Geänderte. Aus fünfzehn Minuten werden je nach
# Änderung zwanzig Sekunden bis zwei Minuten.
#
# Die Reihenfolge ist nach Kosten sortiert, nicht nach Wichtigkeit: Was in
# einer Sekunde bricht, soll auch in einer Sekunde brechen. Ein Tippfehler im
# Rechenkern darf nicht erst nach dem App-Build auffallen.
#
# Aufruf:
#   scripts/pruefen.sh              alles, wie die CI
#   scripts/pruefen.sh schnell      ohne App-Build — Sekunden statt Minuten
#   scripts/pruefen.sh app          nur App-Build und Oberflächentests
#   scripts/pruefen.sh bilder       nur die Screenshots (setzt einen Build voraus)
#
# Schalter:
#   --nur <Name>    nur eine Oberflächenprüfung (Teilname genügt)
#   --ohne-bilder   Screenshots überspringen
#   --seriell       Oberflächentests nacheinander statt auf mehreren Simulatoren
#   --sauber        Ableseverzeichnis vorher wegräumen (wie die CI, langsam)
#   --melden        Ergebnis in den Zweig `pruefungen` schreiben, damit eine
#                   Sitzung ohne Zugriff auf diesen Rechner es sehen kann
set -uo pipefail
cd "$(dirname "$0")/.."

SCOPE="alles"
ONLY=""
SHOTS=1
PARALLEL=1
CLEAN=0
REPORT=0

while [ $# -gt 0 ]; do
  case "$1" in
    alles|schnell|app|bilder) SCOPE="$1" ;;
    --nur) shift; ONLY="${1:-}" ;;
    --ohne-bilder) SHOTS=0 ;;
    --seriell) PARALLEL=0 ;;
    --sauber) CLEAN=1 ;;
    --melden) REPORT=1 ;;
    -h|--hilfe|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unbekannter Schalter: $1" >&2; exit 2 ;;
  esac
  shift
done

# ---------------------------------------------------------------- Darstellung

BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'
YELLOW=$'\033[33m'; RESET=$'\033[0m'
START=$(date +%s)
FAILED=()

step() { printf "\n%s▸ %s%s\n" "$BOLD" "$1" "$RESET"; }
ok()   { printf "  %s✓%s %s %s(%ss)%s\n" "$GREEN" "$RESET" "$1" "$DIM" "$2" "$RESET"; }
bad()  { printf "  %s✗%s %s %s(%ss)%s\n" "$RED" "$RESET" "$1" "$DIM" "$2" "$RESET"; FAILED+=("$1"); }
note() { printf "  %s%s%s\n" "$DIM" "$1" "$RESET"; }

# Führt einen Schritt aus, misst ihn und merkt sich einen Fehlschlag, ohne
# abzubrechen: Wer drei Dinge kaputt gemacht hat, will alle drei sehen und
# nicht dreimal starten. Ausnahme ist der App-Build — was danach kommt, setzt
# ihn voraus.
run() {
  local name="$1"; shift
  local began; began=$(date +%s)
  if "$@" > /tmp/pulse-schritt.log 2>&1; then
    ok "$name" "$(( $(date +%s) - began ))"
    return 0
  fi
  bad "$name" "$(( $(date +%s) - began ))"
  tail -25 /tmp/pulse-schritt.log | sed 's/^/    /'
  return 1
}

# ------------------------------------------------------------------ Vorsorge

# Auf einem Mac läuft alles. Unter Linux läuft, was ohne Xcode geht — und der
# Rest wird benannt statt verschwiegen. Dasselbe Skript an beiden Orten heißt:
# Der Ablauf kann nicht auseinanderlaufen, und niemand muss sich zwei merken.
# Unter Linux liegt die Swift-Toolchain nicht auf dem Pfad (siehe CLAUDE.md).
# Ohne diese Zeile bricht der Rechenkern mit „swift: command not found“ ab —
# ein Fehlschlag, der wie ein Testfehler aussieht und keiner ist.
if ! command -v swift >/dev/null 2>&1 && [ -x /opt/swift/usr/bin/swift ]; then
  PATH="/opt/swift/usr/bin:$PATH"
  export PATH
fi

APPLE=0
if command -v xcodebuild >/dev/null 2>&1; then
  APPLE=1
elif [ "$SCOPE" = "app" ] || [ "$SCOPE" = "bilder" ]; then
  printf "%sxcodebuild fehlt.%s „%s“ braucht Xcode.“ Auf einem Mac: scripts/setup-mac.sh.\n" \
    "$RED" "$RESET" "$SCOPE"
  exit 1
fi

if [ "$CLEAN" = "1" ]; then
  step "Ableseverzeichnis wegräumen"
  rm -rf build/DerivedData
  note "Der nächste Build läuft von null — wie auf der CI."
fi

# ------------------------------------- 1. Was in einer Sekunde brechen könnte

if [ "$SCOPE" != "bilder" ]; then
  step "Sofortprüfungen"
  run "Zeichenketten" python3 scripts/check-strings.py || true
  # Kostet nichts und hält die Fläche klein, auf der überhaupt etwas
  # schiefgehen kann — siehe docs/11-sicherheit.md, Abschnitt 6.
  run "Angriffsfläche" scripts/check-sicherheit.sh || true
  # Reines Parsen, ohne SDK und ohne Typprüfung — und deshalb auch unter Linux.
  #
  # Es findet nicht alles, aber eine ganze Fehlerklasse: einen Block, der in der
  # falschen Struktur gelandet ist, eine Klammer zu wenig, ein Anführungszeichen
  # an der falschen Stelle. Genau so ging 0.32.0 auf der CI zu Bruch — eine
  # Hilfsfunktion war in die benachbarte Struktur gerutscht, und der Lauf
  # meldete es nach fünfzehn Minuten. Hier kostet es drei Sekunden.
  if command -v swiftc >/dev/null 2>&1; then
    # `AppUITests` gehört dazu. Es fehlte, und das ist die schlechtere Hälfte:
    # Ein Tippfehler in einer Oberflächenprüfung fällt sonst erst nach dem
    # vollständigen App-Build auf — also nach der teuersten Minute des Laufs,
    # für einen Fehler, der drei Sekunden zum Finden braucht.
    run "Syntax der iOS-Quellen" swiftc -parse \
      App/*.swift Packages/PulseUI/Sources/PulseUI/*.swift Widget/*.swift \
      AppUITests/*.swift || true
  fi
fi

# ----------------------- 2. Der Entwurf — läuft nebenher, er braucht kein Xcode

PROTO_PID=""
PROTO_LOG="build/pruefen-entwurf.log"
WEB_PID=""
WEB_LOG="build/pruefen-website.log"
if [ "$SCOPE" != "bilder" ] && [ "$SCOPE" != "app" ]; then
  mkdir -p build
  if [ ! -d node_modules/playwright ]; then
    step "Chromium für den Entwurf einrichten"
    note "Einmalig, danach nie wieder."
    npm install --no-save playwright@1.62.1 >/dev/null 2>&1
    # In einer vorbereiteten Umgebung liegt Chromium schon da; dann spart der
    # Schalter den Nachladeversuch, der dort ohnehin geblockt wäre.
    [ -n "${PULSE_CHROMIUM:-}" ] || npx playwright install chromium >/dev/null 2>&1
  fi
  # Nebenher: Der Entwurf braucht vierzehn Sekunden, Xcode braucht länger.
  # Beides gleichzeitig kostet nichts und spart die kürzere der beiden Zeiten.
  ( node scripts/check-prototype.mjs > "$PROTO_LOG" 2>&1 ) &
  PROTO_PID=$!
  # Die Website hängt am selben Chromium und läuft daneben mit. Sie kostet
  # damit keine zusätzliche Wartezeit — und wird geprüft, ohne dass jemand
  # daran denken muss. Genau daran ist der Klick-Dummy vorher gescheitert.
  ( node scripts/check-website.mjs > "$WEB_LOG" 2>&1 ) &
  WEB_PID=$!
fi

# ------------------------------------------------------------- 3. Die Pakete

if [ "$SCOPE" = "alles" ] || [ "$SCOPE" = "schnell" ]; then
  step "Rechenkern und Speicher"
  run "PulseCore" swift test --package-path Packages/PulseCore || true
  if [ "$APPLE" = "1" ]; then
    run "PulseData" swift test --package-path Packages/PulseData || true
  else
    note "PulseData übersprungen — SwiftData gibt es nur auf einer Apple-Plattform."
  fi
fi

# ---------------------------------------------------------------- 4. Die App

APP_OK=1
SHOTS_RAN=0
if { [ "$SCOPE" = "alles" ] || [ "$SCOPE" = "app" ]; } && [ "$APPLE" = "0" ]; then
  step "App"
  note "Übersprungen — SwiftUI und der Simulator brauchen Xcode."
elif [ "$SCOPE" = "alles" ] || [ "$SCOPE" = "app" ]; then
  step "App bauen und Oberflächentests"
  # Auch dann neu erzeugen, wenn `project.yml` jünger ist als das Projekt.
  # Die CI baut immer von null und merkt das nie; lokal bleibt das Projekt
  # liegen, und eine Änderung an `project.yml` — eine neue Datei im Ziel, eine
  # andere Versionsnummer, ein zusätzliches Ziel — wäre stillschweigend nicht
  # im Build gewesen. Genau der Unterschied, der einen lokalen Lauf grün und
  # die CI danach rot macht.
  if [ ! -d PulseMeter.xcodeproj ] || [ project.yml -nt PulseMeter.xcodeproj ]; then
    note "Xcode-Projekt fehlt oder ist älter als project.yml — wird erzeugt."
    xcodegen generate >/dev/null
  fi
  DEVICE=$(scripts/sim.sh 2>/dev/null)
  # Der Simulator wird einmal gestartet und bleibt es. Ein kalter Start kostet
  # bei jedem Lauf zwanzig Sekunden, und niemand schaltet seinen Mac zwischen
  # zwei Testläufen aus.
  xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true

  ARGS=(test -project PulseMeter.xcodeproj -scheme PulseMeter
        -destination "id=$DEVICE"
        -derivedDataPath "${PULSE_DERIVED_DATA:-build/DerivedData}"
        CODE_SIGNING_ALLOWED=NO)
  if [ -n "$ONLY" ]; then
    # Ein Teilname genügt: Wer eine Prüfung gerade repariert, will sie einzeln
    # laufen lassen und nicht neunzehn.
    MATCH=$(grep -ho "func test[A-Za-z0-9_]*" AppUITests/*.swift \
            | sed 's/func //' | grep -i -- "$ONLY" | head -1)
    [ -n "$MATCH" ] || { printf "%sKeine Prüfung passt auf „%s“.%s\n" "$RED" "$ONLY" "$RESET"; exit 2; }
    note "Nur $MATCH"
    ARGS+=(-only-testing:"PulseMeterUITests/LaunchTests/$MATCH")
  elif [ "$PARALLEL" = "1" ]; then
    # Auf geklonten Simulatoren parallel. Die Prüfungen setzen ihren
    # Ausgangszustand selbst (`-pulse-reset`) und hängen deshalb nicht
    # voneinander ab — sonst wäre das hier verboten.
    ARGS+=(-parallel-testing-enabled YES -maximum-parallel-testing-workers 3)
  fi

  mkdir -p build
  LOG="build/xcodebuild-test.log"
  began=$(date +%s)
  set +e
  xcodebuild "${ARGS[@]}" 2>&1 \
    | tee "$LOG" \
    | grep --line-buffered -E "Test Case .*(passed|failed)|Executed [0-9]+ test|error:|\*\* TEST" \
    | sed 's/^/    /'
  status=${PIPESTATUS[0]}
  set -e
  if [ "$status" -eq 0 ]; then
    ok "App und Oberflächentests" "$(( $(date +%s) - began ))"
  else
    bad "App und Oberflächentests" "$(( $(date +%s) - began ))"
    APP_OK=0
    printf "\n  %sGefallene Prüfungen, mit Begründung%s\n" "$YELLOW" "$RESET"
    # `-A 12`, weil eine Begründung mehrzeilig sein darf. Ohne das kam nur die
    # erste Zeile an — und eine Prüfung, die bei einem Fehlschlag den halben
    # Zugänglichkeitsbaum ausgibt, war damit genau dort stumm, wo sie helfen
    # sollte. Die Aufstellung ließ sich nur noch aus dem Artefakt der CI holen.
    grep -A 12 -E "error:|Assertion Failure|XCTAssert|Failing tests:" "$LOG" \
      | tail -45 | sed 's/^/    /'
  fi
fi

# ------------------------------------------------------------ 5. Die Bilder

# **Auch bei einem gefallenen Lauf.** Bis 0.32.7 hing dieser Abschnitt an
# `APP_OK`, und damit unterdrückte eine einzige rote Prüfung alle sechzehn
# Bilder. Genau verkehrt herum: Wenn etwas nicht stimmt, will man die Bilder
# *mehr* als sonst — sieben der bisher gefundenen Darstellungsfehler hat kein
# Test gefunden, sondern der Blick auf ein Bild. Ein ganzer Nachmittag ist so
# blind vergangen, weil eine Prüfung rot war und deshalb nichts zu sehen gab.
#
# Voraussetzung bleibt ein fertig gebautes Programm: Ist schon die Übersetzung
# gescheitert, gibt es nichts zu fotografieren, und ein zweiter Bauversuch
# kostet nur Minuten.
GEBAUT=$(find "${PULSE_DERIVED_DATA:-build/DerivedData}/Build/Products" \
           -name "PulseMeter.app" -maxdepth 3 2>/dev/null | head -1 || true)
if [ "$SHOTS" = "1" ] && [ "$APPLE" = "1" ] && [ -n "$GEBAUT" ] \
   && { [ "$SCOPE" = "alles" ] || [ "$SCOPE" = "bilder" ]; }; then
  step "Screenshots"
  note "Verwendet den vorhandenen Build weiter — es wird nicht neu übersetzt."
  [ "$APP_OK" = "1" ] || note "Der Lauf ist gefallen — die Bilder entstehen trotzdem."
  run "Bilder in build/" scripts/run.sh build || true
  SHOTS_RAN=1
  # Der Zweig soll sagen, aus welchem Zustand die Bilder stammen. Bilder eines
  # roten Laufs sind nützlich, aber sie sind keine Aussage über einen Stand,
  # der durchgelaufen wäre.
  [ "$APP_OK" = "1" ] && export PULSE_LAUF="grün" || export PULSE_LAUF="rot"
  # Mit `--melden` gehen die Bilder auch in den Zweig `screenshots`. Ohne das
  # war die CI der einzige Weg, wie eine Sitzung ohne Zugriff auf diesen Mac
  # sie je zu sehen bekam — und damit war sie das Nadelöhr für eine Prüfung,
  # die hier längst fertig in `build/` liegt.
  if [ "$REPORT" = "1" ]; then
    run "Bilder in den Zweig screenshots" scripts/publish-shots.sh build || true
  fi
fi

# ------------------------------------------------- 6. Auf den Entwurf warten

if [ -n "$PROTO_PID" ]; then
  step "Klick-Dummy"
  if wait "$PROTO_PID"; then
    GRUEN=$(grep -c '  ok   ' "$PROTO_LOG" || true)
    GESAMT=$(grep -cE '  (ok|FEHL) ' "$PROTO_LOG" || true)
    ok "$GRUEN von $GESAMT Prüfungen, hell und dunkel" "—"
  else
    bad "Klick-Dummy" "—"
    grep "FEHL" "$PROTO_LOG" | sed 's/^/    /'
  fi
fi

if [ -n "$WEB_PID" ]; then
  step "Website"
  if wait "$WEB_PID"; then
    GRUEN=$(grep -c '  ok   ' "$WEB_LOG" || true)
    ok "$GRUEN Prüfungen, hell und dunkel, 320 bis 1280 Pixel" "—"
    grep '  offen ' "$WEB_LOG" | sed 's/^  offen /    noch offen: /' || true
  else
    bad "Website" "—"
    grep "FEHL" "$WEB_LOG" | sed 's/^/    /'
  fi
fi

# ------------------------------------------------------------------- Ergebnis

DAUER=$(( $(date +%s) - START ))
printf "\n"
if [ ${#FAILED[@]} -eq 0 ]; then
  printf "%sAlles durchgelaufen — %ss.%s\n" "$GREEN" "$DAUER" "$RESET"
  [ "$SHOTS_RAN" = "1" ] && note "Bilder in build/ — hell und dunkel."
  [ "$REPORT" = "1" ] && scripts/melden.sh "grün" "$DAUER" "$SCOPE" || true
  exit 0
fi
printf "%s%s Schritt(e) gefallen: %s — nach %ss.%s\n" "$RED" "${#FAILED[@]}" "${FAILED[*]}" "$DAUER" "$RESET"
printf "%sVollständige Protokolle: build/xcodebuild-test.log, %s, %s%s\n" "$DIM" "$PROTO_LOG" "$WEB_LOG" "$RESET"
# Auch ein Fehlschlag wird gemeldet. Ein Zweig, in dem nur die grünen Läufe
# stehen, sagt genau das Falsche: Er sieht aus wie eine lückenlose Erfolgsreihe.
[ "$REPORT" = "1" ] && scripts/melden.sh "gefallen" "$DAUER" "$SCOPE" "${FAILED[*]}" || true
exit 1
