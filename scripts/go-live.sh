#!/usr/bin/env bash
# Der Weg zum ersten Gerätelauf, in einem Befehl.
#
# **Was dieses Skript ist.** Die Schritte aus `docs/07-v1-plan.md`, Abschnitt 5,
# so weit sie sich ausführen lassen — in der richtigen Reihenfolge, jeder
# einzeln geprüft. Es hält beim ersten echten Problem an und sagt, was ein
# Mensch tun muss, statt weiterzulaufen und am Ende etwas Halbes abzuliefern.
#
# **Was es nicht ist: eine Abkürzung um Apple herum.** Drei Dinge kann kein
# Skript, und sie stehen am Ende noch einmal ausdrücklich da: das Programm
# kaufen, die Produkte in App Store Connect anlegen und die App zwei Wochen
# benutzen. Alles andere passiert hier.
#
#   scripts/go-live.sh            # alles der Reihe nach
#   scripts/go-live.sh --pruefen  # nur nachsehen, nichts bauen und nichts installieren
#
# Braucht einen Mac mit Xcode. Unter Linux macht es, was ohne Xcode geht, und
# benennt, was es überspringt — dieselbe Machart wie `scripts/pruefen.sh`.
set -uo pipefail
cd "$(dirname "$0")/.."

GRUEN=$'\033[32m'; ROT=$'\033[31m'; GELB=$'\033[33m'; FETT=$'\033[1m'; MATT=$'\033[2m'; AUS=$'\033[0m'
NUR_PRUEFEN=0
[ "${1:-}" = "--pruefen" ] && NUR_PRUEFEN=1

SCHRITT=0
ok()      { printf "  ${GRUEN}✓${AUS} %s\n" "$1"; }
hinweis() { printf "  ${MATT}·${AUS} %s\n" "$1"; }
offen()   { printf "  ${GELB}○${AUS} %s\n" "$1"; }
titel()   { SCHRITT=$((SCHRITT + 1)); printf "\n${FETT}%d. %s${AUS}\n" "$SCHRITT" "$1"; }
abbruch() {
  printf "\n  ${ROT}✗${AUS} %s\n\n" "$1"
  [ $# -gt 1 ] && printf "%s\n\n" "$2"
  exit 1
}

printf "${FETT}PulseMeter — auf das Telefon und weiter${AUS}\n"
[ "$NUR_PRUEFEN" = 1 ] && printf "${MATT}Nur nachsehen. Es wird nichts gebaut und nichts installiert.${AUS}\n"

# ---------------------------------------------------------------- 1. Der Stand

titel "Der Stand ist der, den du glaubst"

# **Warum das zuerst kommt.** Ein Arbeitsverzeichnis auf einem veralteten Zweig
# sieht vollständig aus. Eine Sitzung hat so 0.30.1 geprüft und für den
# aktuellen Stand gehalten (CLAUDE.md, Regel 3).
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  offen "Es liegen ungesicherte Änderungen. Das ist erlaubt, aber dann ist der Bau nicht der committete Stand."
else
  ok "Arbeitsverzeichnis sauber"
fi
printf "  ${MATT}Zweig %s, Stand %s${AUS}\n" \
  "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')" \
  "$(git rev-parse --short HEAD 2>/dev/null || echo '?')"

# ------------------------------------------------------ 2. Was ohne Xcode geht

titel "Was ohne Xcode prüfbar ist"

scripts/check-sicherheit.sh >/dev/null 2>&1 \
  && ok "Angriffsfläche und Privacy-Manifeste" \
  || abbruch "scripts/check-sicherheit.sh schlägt an." "Erst das in Ordnung bringen — hier hängt das Datenschutzversprechen dran.
Einzeln ansehen:  scripts/check-sicherheit.sh"

for datei in App/PulseMeter.entitlements Widget/PulseWidget.entitlements \
             App/PrivacyInfo.xcprivacy Widget/PrivacyInfo.xcprivacy; do
  [ -f "$datei" ] || abbruch "$datei fehlt."
done
ok "Berechtigungen und Privacy-Manifeste liegen bereit"

# Die App-Gruppe steht an drei Stellen und muss überall gleich lauten. Läuft
# eine davon weg, bleibt das Widget leer — ohne Fehlermeldung, ohne Absturz.
GRUPPE=$(grep -oE 'group\.[a-z.]+' Shared/WidgetBridge.swift | head -1)
for datei in App/PulseMeter.entitlements Widget/PulseWidget.entitlements; do
  grep -q "$GRUPPE" "$datei" \
    || abbruch "$datei nennt nicht dieselbe App-Gruppe wie WidgetBridge.swift ($GRUPPE)." \
"Genau daran bleibt ein Widget dauerhaft leer, ohne dass irgendwo ein Fehler steht."
done
ok "App-Gruppe überall gleich: $GRUPPE"

# --------------------------------------------------------- 3. Ab hier Xcode

if ! command -v xcodebuild >/dev/null 2>&1; then
  printf "\n${GELB}Ohne Xcode ist hier Schluss.${AUS}\n"
  printf "Alles Weitere — bauen, signieren, installieren — braucht einen Mac.\n"
  printf "Was dort zu tun ist, steht in ${FETT}docs/07-v1-plan.md${AUS}, Abschnitt 5.\n\n"
  exit 0
fi

titel "Team und Gerät"

TEAM="${PULSE_TEAM:-}"
if [ -z "$TEAM" ]; then
  TEAM=$(security find-identity -v -p codesigning 2>/dev/null \
         | sed -n 's/.*(\([A-Z0-9]\{10\}\)).*/\1/p' | head -1)
fi
[ -n "$TEAM" ] || abbruch "Kein Signaturteam gefunden." \
"Xcode öffnen › Einstellungen › Accounts › Apple-ID hinzufügen. Danach hier weiter.
Oder direkt mitgeben:  PULSE_TEAM=ABCDE12345 scripts/go-live.sh"
ok "Team $TEAM"

UDID=$(xcrun xctrace list devices 2>/dev/null \
       | sed -n 's/^\(.*\) (\([0-9.]*\)) (\([0-9A-Fa-f-]\{25,\}\))$/\3/p' | head -1)
if [ -n "$UDID" ]; then
  ok "Gerät $UDID"
else
  offen "Kein Telefon angesteckt — der Gerätebau wird übersprungen."
fi

# ------------------------------------------------------------- 4. Vollprüfung

titel "Die volle Prüfung"

if [ "$NUR_PRUEFEN" = 1 ]; then
  hinweis "übersprungen (--pruefen)"
else
  scripts/pruefen.sh --melden \
    || abbruch "Die Prüfung ist rot." \
"Nicht daran vorbeibauen. Was gefallen ist, steht oben; einzeln wiederholen mit
  scripts/pruefen.sh --nur <name>"
  ok "Alles grün, Ergebnis und Bilder liegen in den Zweigen"
fi

# ------------------------------------------------------------ 5. Aufs Telefon

titel "Auf das Telefon"

if [ -z "$UDID" ]; then
  offen "Kein Gerät. Telefon anstecken, entsperren, „Diesem Computer vertrauen“, dann noch einmal."
elif [ "$NUR_PRUEFEN" = 1 ]; then
  hinweis "übersprungen (--pruefen)"
else
  # Beim ersten Lauf legt Xcode hier App-ID, App-Gruppe und iCloud-Container
  # im Portal an. Das dauert und sieht aus, als hinge es.
  printf "  ${MATT}Beim ersten Mal legt Xcode dabei die Kennungen im Portal an. Das dauert.${AUS}\n"
  if PULSE_TEAM="$TEAM" scripts/aufs-handy.sh --geraet "$UDID"; then
    ok "Installiert"
  else
    printf "\n  ${GELB}○${AUS} Der Bau mit Berechtigungen ist gescheitert.\n\n"
    cat <<'ENDE'
Das ist der häufigste Punkt, an dem es hakt, und meistens liegt es daran, dass
das Programm noch nicht vollständig freigeschaltet ist — dann darf Xcode die
App-Gruppe und den iCloud-Container nicht anlegen.

Zwei Wege, und der erste ist der bessere:

  1. Eine Stunde warten und noch einmal starten. Die Freischaltung braucht
     gelegentlich länger, als die Bestätigungsmail vermuten lässt.

  2. Ohne Berechtigungen aufs Telefon — die App läuft, das Widget bleibt leer,
     iCloud ist aus:

         PULSE_OHNE_BERECHTIGUNGEN=1 scripts/aufs-handy.sh

     Das ist kein Rückschritt. Die zwei Wochen Eigennutzung sind wichtiger als
     der Abgleich, und sie können sofort anfangen (docs/07-v1-plan.md).
ENDE
    exit 1
  fi

  # **Nachsehen, dass das Privacy-Manifest wirklich im Bündel liegt.** XcodeGen
  # nimmt es als Ressource mit; geprüft war das bis 0.56.0 nirgends, und ein
  # fehlendes Manifest lehnt Apple erst beim Hochladen ab.
  APP=$(find build/geraet/Build/Products -name "PulseMeter.app" -maxdepth 3 2>/dev/null | head -1)
  if [ -n "$APP" ] && [ -f "$APP/PrivacyInfo.xcprivacy" ]; then
    ok "PrivacyInfo.xcprivacy liegt im gebauten Bündel"
  elif [ -n "$APP" ]; then
    abbruch "PrivacyInfo.xcprivacy fehlt im gebauten Bündel." \
"Apple lehnt das beim Hochladen ab. In project.yml gehört dann eine ausdrückliche
resources-Angabe für App/PrivacyInfo.xcprivacy und Widget/PrivacyInfo.xcprivacy."
  fi
fi

# ------------------------------------------------------------- 6. Der Rest

titel "Was jetzt noch bei dir liegt"

CLOUD=$(grep -c "container(cloudKit: true)" App/PulseMeterApp.swift 2>/dev/null || echo 0)
[ "$CLOUD" -gt 0 ] && ok "iCloud wird versucht, mit Rückfall auf lokal" \
                  || offen "iCloud ist aus — App/PulseMeterApp.swift, PulseStore.container(cloudKit:)"

grep -q "struct StoreKitGateway" App/*.swift 2>/dev/null \
  && ok "StoreKitGateway steht" \
  || offen "StoreKitGateway fehlt — fünf Produkte in App Store Connect anlegen, Kennungen aus ProductID"

cat <<'ENDE'

Drei Dinge kann kein Skript, und sie sind der eigentliche Weg:

  · Die fünf Käufe in App Store Connect anlegen. Die Kennungen stehen in
    Packages/PulseCore/.../Access/Entitlement.swift und dürfen sich nie ändern —
    ein umbenanntes Produkt ist für jeden Käufer ein verlorener Kauf.

  · Die Website veröffentlichen. Cloudflare Pages auf dieses Repo,
    Ausgabeordner docs/website. Die Datenschutz-URL ist ein Pflichtfeld bei der
    Einreichung; ohne sie geht nichts.

  · Die App zwei Wochen benutzen, mit den eigenen Zählerständen. Das ist der
    Punkt, der bisher am meisten gefunden hat, und der einzige, der sich nicht
    abkürzen lässt.

ENDE
