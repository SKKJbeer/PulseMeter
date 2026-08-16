#!/usr/bin/env bash
# Baut PulseMeter für ein angestecktes iPhone, signiert es und installiert es.
#
# **Warum es dieses Skript gibt.** `project.yml` steht auf
# `CODE_SIGNING_ALLOWED: NO` — für den Simulator und die CI genau richtig, für
# ein echtes Gerät ein Riegel. In der Xcode-Oberfläche ließe er sich umlegen,
# aber `PulseMeter.xcodeproj` wird erzeugt: Beim nächsten `xcodegen generate`
# wäre die Einstellung weg, und niemand wüsste, warum es plötzlich nicht mehr
# geht. Hier steht sie stattdessen auf der Kommandozeile — Vorrang vor dem
# Projekt, ohne es anzufassen. Die CI baut weiter unsigniert.
#
# Aufruf:
#   scripts/aufs-handy.sh               Team automatisch suchen, Gerät suchen
#   PULSE_TEAM=ABCDE12345 scripts/aufs-handy.sh
#   scripts/aufs-handy.sh --geraet <UDID>
#
# Ohne Apple Developer Program geht das auch: Eine gewöhnliche Apple-ID in
# Xcode unter Einstellungen › Accounts genügt. Der Preis dafür steht am Ende
# der Ausgabe — sieben Tage, dann läuft die App ab.
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVED="${PULSE_DERIVED_DATA:-build/DerivedData-geraet}"
UDID="${PULSE_GERAET:-}"
TEAM="${PULSE_TEAM:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --geraet) UDID="${2:-}"; shift 2 ;;
    --team) TEAM="${2:-}"; shift 2 ;;
    -h|--hilfe|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unbekannter Schalter: $1" >&2; exit 2 ;;
  esac
done

command -v xcodebuild >/dev/null 2>&1 || {
  echo "xcodebuild fehlt — das hier braucht einen Mac mit Xcode." >&2; exit 1; }

# Das Team, mit dem signiert wird.
#
# Es steht in jedem Entwicklerzertifikat im Schlüsselbund, in Klammern hinter
# dem Namen. Wer noch keins hat, bekommt es beim ersten Bauen von Xcode selbst
# angelegt — dann läuft dieser Aufruf einmal ins Leere und beim zweiten Mal
# durch. Erraten wird hier nichts: Ein falsches Team führt zu einer
# Fehlermeldung über Berechtigungen, die mit dem Fehler nichts zu tun hat.
if [ -z "$TEAM" ]; then
  TEAM=$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"Apple Development: .*(\([A-Z0-9]\{10\}\))".*/\1/p' | head -1)
fi
if [ -z "$TEAM" ]; then
  cat >&2 <<'ENDE'
Kein Signierschlüssel gefunden.

So kommt einer zustande, einmalig:
  1. Xcode öffnen, Einstellungen › Accounts, Apple-ID hinzufügen.
  2. xcodegen generate && open PulseMeter.xcodeproj
  3. Ziel „PulseMeter" wählen, Reiter „Signing & Capabilities",
     „Automatically manage signing" ankreuzen und das Team wählen.
  4. Dieses Skript noch einmal aufrufen.

Oder das Team direkt mitgeben:  PULSE_TEAM=ABCDE12345 scripts/aufs-handy.sh
ENDE
  exit 1
fi

# Das Gerät.
#
# **Warum `xctrace` und nicht `devicectl`.** Beide listen Geräte, aber unter
# verschiedenen Kennungen: `devicectl` führt eine eigene UUID, `xcodebuild
# -destination "id=…"` will die Kennung der Hardware. Wer die eine für die
# andere hält, bekommt „Unable to find a device matching the provided
# destination" und sucht den Fehler beim Kabel. `xctrace` nennt die richtige,
# und `devicectl` versteht sie beim Installieren ebenfalls.
if [ -z "$UDID" ]; then
  UDID=$(xcrun xctrace list devices 2>/dev/null \
    | sed -n '/== Devices ==/,/== Simulators ==/p' \
    | grep -E '\([0-9]+\.[0-9]+(\.[0-9]+)?\) \(' \
    | head -1 | sed -E 's/.*\(([-0-9A-Fa-f]+)\)[[:space:]]*$/\1/')
fi
if [ -z "$UDID" ]; then
  cat >&2 <<'ENDE'
Kein iPhone gefunden.

  · Kabel anstecken und am Telefon „Vertrauen" bestätigen.
  · Entwicklermodus einschalten: Einstellungen › Datenschutz & Sicherheit ›
    Entwicklermodus. Das Telefon startet dabei neu — ohne diesen Schalter
    lässt sich seit iOS 16 nichts Selbstgebautes starten.
  · Danach:  xcrun devicectl list devices

Oder die Kennung direkt mitgeben:  scripts/aufs-handy.sh --geraet <UDID>
ENDE
  exit 1
fi

if [ ! -d PulseMeter.xcodeproj ] || [ project.yml -nt PulseMeter.xcodeproj ]; then
  xcodegen generate
fi

echo "Team $TEAM · Gerät $UDID"
echo "Wird gebaut und signiert — beim ersten Mal legt Xcode dabei ein Profil an."

# `-allowProvisioningUpdates` ist der Teil, der ohne Xcode-Oberfläche auskommt:
# Es darf das Profil und die App-Kennung selbst anlegen. Ohne den Schalter
# bricht der Lauf mit „no profiles found" ab, und man sucht im Portal nach
# etwas, das es noch gar nicht geben kann.
#
# **Und es legt mehr an als nur das Profil.** Mit einem Bezahlkonto registriert
# derselbe Schalter auch die **App-Gruppe** und den **iCloud-Container** aus den
# Berechtigungsdateien — beim ersten Bau, ohne einen einzigen Klick im
# Entwicklerportal.
#
# Die Berechtigungen stehen je Ziel in `project.yml` und **nicht** hier auf der
# Kommandozeile: Eine Bauvorgabe auf der Kommandozeile gilt für alle Ziele auf
# einmal, und dann bekäme das Widget die iCloud-Berechtigung der App, die seine
# eigene Kennung gar nicht hat.
SIGNIERUNG=()
if [ "${PULSE_OHNE_BERECHTIGUNGEN:-}" = "1" ]; then
  # Notausgang, falls die Berechtigungen den Bau blockieren — dann ist die App
  # auf dem Telefon, das Widget bleibt leer und iCloud aus. Besser als gar
  # keine App: Die zwei Wochen Eigennutzung sind wichtiger als der Abgleich
  # (docs/07-v1-plan.md).
  echo "Ohne Berechtigungen — Widget und iCloud bleiben aus."
  SIGNIERUNG=(CODE_SIGN_ENTITLEMENTS="")
fi

xcodebuild build \
  -project PulseMeter.xcodeproj \
  -scheme PulseMeter \
  -destination "id=$UDID" \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  -quiet \
  DEVELOPMENT_TEAM="$TEAM" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  "${SIGNIERUNG[@]}"

APP=$(find "$DERIVED/Build/Products" -name "PulseMeter.app" -maxdepth 3 | head -1)
[ -n "$APP" ] || { echo "PulseMeter.app nicht gefunden" >&2; exit 1; }

xcrun devicectl device install app --device "$UDID" "$APP"

cat <<'ENDE'

PulseMeter liegt auf dem Telefon.

Beim ersten Start meldet iOS „Nicht vertrauenswürdiger Entwickler". Einmal:
  Einstellungen › Allgemein › VPN & Geräteverwaltung › Entwickler-App › Vertrauen

Was mit einer gewöhnlichen Apple-ID noch nicht geht — und was daran liegt,
dass diese Berechtigungen das Apple Developer Program voraussetzen:

  · Nach sieben Tagen läuft die App ab. Dann dieses Skript erneut aufrufen;
    die Daten bleiben dabei erhalten.
  · Das Widget bleibt leer. Es liest über eine App-Gruppe, und die gibt es
    ohne Programm nicht. Die App selbst merkt davon nichts.
  · iCloud-Abgleich und Käufe sind aus demselben Grund noch nicht zu prüfen.
ENDE
