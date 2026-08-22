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

# Auch dann neu erzeugen, wenn `project.yml` jünger ist: Ein liegengebliebenes
# Projekt kennt eine Änderung daran nicht, und die Bilder zeigen dann einen
# Stand, den es so nicht gibt.
if [ ! -d PulseMeter.xcodeproj ] || [ project.yml -nt PulseMeter.xcodeproj ]; then
  xcodegen generate
fi
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
#
# `PULSE_WARTEN` setzt die Wartezeit für einen einzelnen Schuss hoch. Vier
# Sekunden genügen für jeden Bildschirm, den SwiftUI selbst zeichnet — nicht
# aber für ein Blatt, das erst gesetzt werden muss. Das erste Bild des
# PDF-Berichts, das je jemand gesehen hat, zeigte sechs **leere** Seitenrahmen.
# Ob die Vorschau nur noch nicht fertig war oder der Bericht wirklich leer
# rendert, war daran nicht zu unterscheiden — deshalb bekommt er hier deutlich
# mehr Zeit. Bleibt er auch dann leer, ist die Frage beantwortet.
shoot() {
  local mode="$1" name="$2"
  shift 2
  xcrun simctl ui "$DEVICE" appearance "$mode" >/dev/null 2>&1 || true
  xcrun simctl terminate "$DEVICE" de.karjoth.pulsemeter >/dev/null 2>&1 || true
  # `-pulse-pro` gehört zum Ausgangszustand wie `-pulse-reset`: Die
  # Beispieldaten führen vier Zähler mit Preisen, Abschlag und Einspeisung —
  # also lauter Dinge, die seit 0.35.0 Pro sind. Ohne den Schalter zeigten
  # sämtliche Bilder eine App voller Schlösser und wären als Beleg wertlos.
  # Der Zustand *vor* dem Kauf bekommt eigene Bilder, weiter unten.
  xcrun simctl launch "$DEVICE" de.karjoth.pulsemeter -pulse-reset -pulse-pro "$@" >/dev/null
  sleep "${PULSE_WARTEN:-4}"
  xcrun simctl io "$DEVICE" screenshot "$OUTDIR/$name.png"
  echo "Screenshot: $OUTDIR/$name.png (nach ${PULSE_WARTEN:-4}s)"
}

shoot light screenshot-light
shoot dark  screenshot-dark
shoot light screenshot-capture-light -pulse-capture
shoot dark  screenshot-capture-dark  -pulse-capture
shoot light screenshot-pv-light -pulse-capture-pv
shoot dark  screenshot-pv-dark  -pulse-capture-pv
shoot light screenshot-zurueck-light -pulse-capture-step2
shoot dark  screenshot-zurueck-dark  -pulse-capture-step2
shoot light screenshot-verlauf-light -pulse-verlauf
shoot dark  screenshot-verlauf-dark  -pulse-verlauf
# Derselbe Schirm am zuletzt abgelesenen Zähler. Die beiden Bilder darüber
# zeigen den Gaszähler, der in den Beispieldaten absichtlich überfällig ist —
# an ihm ist nichts hochzurechnen, und die Vorschau für den laufenden Monat war
# damit auf keinem Bild zu sehen.
shoot light screenshot-vorschau-light -pulse-verlauf -pulse-verlauf-vorschau
shoot dark  screenshot-vorschau-dark  -pulse-verlauf -pulse-verlauf-vorschau
PULSE_WARTEN=15 shoot light screenshot-bericht-light -pulse-bericht
PULSE_WARTEN=15 shoot dark  screenshot-bericht-dark  -pulse-bericht
shoot light screenshot-leer-light -pulse-empty
shoot dark  screenshot-leer-dark  -pulse-empty
shoot light screenshot-zaehler-light -pulse-zaehler
shoot dark  screenshot-zaehler-dark  -pulse-zaehler

# Der Zustand vor dem Kauf.
#
# `-pulse-frei` überstimmt das `-pulse-pro` von oben — die Reihenfolge der
# Schalter ist egal, `Purchase` liest `-pulse-pro` zuerst und `-pulse-frei`
# danach. Zwei Bilder, die es vorher nicht geben konnte: die Grenze am
# Zähler-Schirm und die Kaufseite selbst. Beide gehen in den App Store, und
# beide sind die einzige Stelle, an der sich sehen lässt, ob eine Sperre
# einladend wirkt oder nach Erpressung aussieht.
shoot light screenshot-grenze-light -pulse-zaehler -pulse-frei
shoot dark  screenshot-grenze-dark  -pulse-zaehler -pulse-frei
shoot light screenshot-pro-light -pulse-kaufen -pulse-frei
shoot dark  screenshot-pro-dark  -pulse-kaufen -pulse-frei

# Größte Schriftgröße, die iOS anbietet.
#
# In `00-produktstrategie.md` steht „Dynamic Type bis zur größten Stufe" als
# nicht verhandelbar — geprüft wurde es bis 0.27.0 nie. Ein Bild davon kostet
# zwei Sekunden und zeigt sofort, was abgeschnitten wird oder aus der Karte
# läuft. Ohne Bild ist die Zusage eine Behauptung.
xcrun simctl ui "$DEVICE" content_size accessibility-extra-extra-extra-large >/dev/null 2>&1 || true
shoot light screenshot-grossschrift-light
shoot dark  screenshot-grossschrift-dark
# Zurückstellen, damit ein wiederverwendeter Simulator nicht dauerhaft auf der
# größten Stufe steht und alle künftigen Bilder verfälscht.
xcrun simctl ui "$DEVICE" content_size medium >/dev/null 2>&1 || true
