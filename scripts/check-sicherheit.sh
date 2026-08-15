#!/usr/bin/env bash
# Hält die Angriffsfläche klein — der billige Teil von `docs/11-sicherheit.md`.
#
# **Warum als Prüfung und nicht als Notiz.** Die Sicherheit dieser App beruht
# fast vollständig darauf, dass es Dinge **nicht** gibt: keinen Netzverkehr,
# keine fremden Pakete, keine Protokollausgabe mit Zählerständen. So etwas
# schleicht sich nicht durch einen Angriff ein, sondern durch eine bequeme
# Zeile an einem Dienstagnachmittag. Die fällt hier auf.
#
# Läuft überall, braucht kein Xcode. Aufruf: scripts/check-sicherheit.sh
set -uo pipefail
cd "$(dirname "$0")/.."

GRUEN=$'\033[32m'; ROT=$'\033[31m'; AUS=$'\033[0m'; MATT=$'\033[2m'
FEHLER=0
QUELLEN=(App Widget Shared Packages/PulseCore/Sources Packages/PulseData/Sources Packages/PulseUI/Sources)

pruefe() {           # pruefe "Name" "Muster" [zusätzliche grep-Schalter]
  local name="$1" muster="$2"; shift 2
  local treffer
  treffer=$(grep -rnE "$muster" --include=*.swift "$@" "${QUELLEN[@]}" 2>/dev/null \
            | grep -v "^\S*: *//" | grep -v "^\S*: *///" || true)
  if [ -z "$treffer" ]; then
    printf "  %s✓%s %s\n" "$GRUEN" "$AUS" "$name"
  else
    printf "  %s✗%s %s\n" "$ROT" "$AUS" "$name"
    printf "%s\n" "$treffer" | sed 's/^/      /' | head -5
    FEHLER=$((FEHLER + 1))
  fi
}

printf "\033[1mAngriffsfläche\033[0m\n"

pruefe "Kein Netzverkehr"            'URLSession|URLRequest|https?://[a-z]'
pruefe "Keine Zwischenablage"        'UIPasteboard'
pruefe "Keine Protokollausgabe"      '(^|[^a-zA-Z])(print|NSLog|os_log)\(|Logger\('
# `Startschalter.swift` ist die eine erlaubte Stelle: Sie schaltet die
# Startargumente im Auslieferungsbau ab. Überall sonst wären sie wieder scharf.
pruefe "Startschalter nur an einer Stelle" 'processInfo\.arguments' --exclude=Startschalter.swift

fremd=$(grep -rn '\.package(' Packages/*/Package.swift 2>/dev/null | grep -v 'path: "\.\.' || true)
if [ -z "$fremd" ]; then
  printf "  %s✓%s Keine fremden Pakete\n" "$GRUEN" "$AUS"
else
  printf "  %s✗%s Fremdes Paket:\n%s\n" "$ROT" "$AUS" "$fremd"; FEHLER=$((FEHLER + 1))
fi

# Eine Berechtigung, die niemand braucht, ist ein Ablehnungsgrund und ein
# Datenschutzversprechen weniger.
rechte=$(grep -oE 'NS[A-Za-z]+UsageDescription|NSAllowsArbitraryLoads|CFBundleURLSchemes' \
         App/Info.plist Widget/Info.plist 2>/dev/null || true)
if [ -z "$rechte" ]; then
  printf "  %s✓%s Keine unbenutzten Berechtigungen in Info.plist\n" "$GRUEN" "$AUS"
else
  printf "  %s✗%s In Info.plist steht:\n%s\n" "$ROT" "$AUS" "$rechte"; FEHLER=$((FEHLER + 1))
fi

printf "\n"
if [ "$FEHLER" -eq 0 ]; then
  printf "%sDie Fläche ist so klein wie in docs/11-sicherheit.md beschrieben.%s\n" "$MATT" "$AUS"
else
  printf "%s%d Abweichung(en). Entweder zurücknehmen oder in docs/11-sicherheit.md begründen.%s\n" \
    "$ROT" "$FEHLER" "$AUS"
fi
exit "$FEHLER"
