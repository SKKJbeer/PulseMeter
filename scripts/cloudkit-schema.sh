#!/usr/bin/env bash
# Legt das CloudKit-Schema von Zählora in der Entwicklungsumgebung an.
#
# Warum: Laden- und TestFlight-Bauten sprechen mit der Produktionsumgebung von
# CloudKit. Dort kennt CloudKit nur Datensatztypen, die jemand aus der
# Entwicklungsumgebung übertragen hat. Fehlen sie, scheitert jeder Abgleich
# still, und das zweite Gerät bleibt leer (0.141.0, Käufermeldung 14.10.).
#
# Ablauf, einmal je Änderung am Datenmodell:
#   1. Dieses Skript am Mac. Es baut die App im Debug-Bau für einen Simulator,
#      startet sie mit -pulse-cloudkit-schema und wartet auf die Rückmeldung.
#      Der Simulator muss mit einer Apple-ID in iCloud angemeldet sein
#      (Einstellungen im Simulator, oben „Anmelden").
#   2. https://icloud.developer.apple.com → Container iCloud.de.karjoth.pulsemeter
#      → Schema → „Deploy Schema Changes…" → Deploy.
#   3. Fertig. Die Bauten im Laden gleichen ab dem nächsten Start ab, ohne
#      neuen Bau.
#
# Aufruf:  scripts/cloudkit-schema.sh [--simulator <UDID>] [--team <TEAMID>]
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVED="${PULSE_DERIVED_DATA:-build/DerivedData-schema}"
UDID="${PULSE_SIMULATOR:-}"
TEAM="${PULSE_TEAM:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --simulator) UDID="${2:-}"; shift 2 ;;
    --team) TEAM="${2:-}"; shift 2 ;;
    -h|--hilfe|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unbekannter Schalter: $1" >&2; exit 2 ;;
  esac
done

command -v xcodebuild >/dev/null 2>&1 || {
  echo "xcodebuild fehlt — das hier braucht einen Mac mit Xcode." >&2; exit 1; }

if [ -z "$TEAM" ]; then
  TEAM=$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"Apple Development: .*(\([A-Z0-9]\{10\}\))".*/\1/p' | head -1)
fi
[ -n "$TEAM" ] || {
  echo "Kein Signierschlüssel gefunden. Xcode › Einstellungen › Accounts, Apple-ID hinzufügen," >&2
  echo "oder:  PULSE_TEAM=ABCDE12345 scripts/cloudkit-schema.sh" >&2
  exit 1; }

# Ein laufender Simulator, sonst der erste iPhone-Simulator.
if [ -z "$UDID" ]; then
  UDID=$(xcrun simctl list devices booted | grep -Eo '[0-9A-F-]{36}' | head -1 || true)
fi
if [ -z "$UDID" ]; then
  UDID=$(xcrun simctl list devices available | grep -E 'iPhone' | grep -Eo '[0-9A-F-]{36}' | head -1)
  xcrun simctl boot "$UDID"
  open -a Simulator
fi
echo "Team $TEAM · Simulator $UDID"

if [ ! -d PulseMeter.xcodeproj ] || [ project.yml -nt PulseMeter.xcodeproj ]; then
  xcodegen generate
fi

# Signiert mit Entwicklungsprofil: nur dann zeigt der Bau auf die
# Entwicklungsumgebung, und nur dort darf das Schema wachsen.
xcodebuild build \
  -project PulseMeter.xcodeproj \
  -scheme PulseMeter \
  -configuration Debug \
  -destination "id=$UDID" \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  -quiet \
  DEVELOPMENT_TEAM="$TEAM" \
  CODE_SIGN_STYLE=Automatic

APP=$(find "$DERIVED/Build/Products" -name "PulseMeter.app" -maxdepth 3 | head -1)
[ -n "$APP" ] || { echo "PulseMeter.app nicht gefunden" >&2; exit 1; }
xcrun simctl install "$UDID" "$APP"

cat <<'ENDE'
Ist der Simulator in iCloud angemeldet? Sonst jetzt: Einstellungen im
Simulator › „Beim iPhone anmelden". Danach Eingabetaste.
ENDE
read -r _

DATEN=$(xcrun simctl get_app_container "$UDID" de.karjoth.pulsemeter data)
AUSGABE="$DATEN/tmp/cloudkit-schema-ergebnis.txt"
rm -f "$AUSGABE"
xcrun simctl launch --terminate-running-process "$UDID" \
  de.karjoth.pulsemeter -pulse-cloudkit-schema >/dev/null

# Die App schreibt ihr Ergebnis in eine Datei und beendet sich. Bis zu zwei
# Minuten warten: Das erste Anlegen in CloudKit dauert.
for _ in $(seq 1 120); do
  [ -s "$AUSGABE" ] && break
  sleep 1
done
[ -s "$AUSGABE" ] || { echo "Nach zwei Minuten kein Ergebnis von der App." >&2; exit 1; }
cat "$AUSGABE"

if grep -q "CLOUDKIT-SCHEMA: angelegt" "$AUSGABE"; then
  cat <<'ENDE'

Schema in der Entwicklungsumgebung angelegt.
Jetzt noch übertragen:
  https://icloud.developer.apple.com
  → iCloud.de.karjoth.pulsemeter → Schema → „Deploy Schema Changes…" → Deploy
ENDE
else
  echo "" >&2
  echo "Nicht angelegt — die Zeile darüber sagt, warum." >&2
  echo "Häufigster Grund: Simulator nicht in iCloud angemeldet." >&2
  exit 1
fi
