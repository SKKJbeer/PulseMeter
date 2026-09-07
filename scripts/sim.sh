#!/usr/bin/env bash
# Wählt einen Simulator aus. Ohne Vorgabe das neueste iPhone.
#
#   scripts/sim.sh              # neuestes iPhone
#   scripts/sim.sh ipad         # neuestes iPad
#   PULSE_SIMULATOR=<udid>      # überstimmt beides
#
# Die Auswahl darf sich nicht auf die alphabetische Reihenfolge der Namen
# verlassen: „iPhone SE" steht dort hinter „iPhone 16 Pro", weil S hinter 1
# kommt. Deshalb wird die Zahl im Namen ausgewertet.
#
# **Warum das seit 0.112.0 zwei Familien kennt.** Die App trägt seit dieser
# Fassung `TARGETED_DEVICE_FAMILY: "1,2"`, und ein iPad-Layout, das nur auf dem
# Telefon geprüft wird, ist keins — es ist eine Vermutung mit Bildern. Apple
# prüft die App auf einem iPad, sobald sie dort läuft.
set -euo pipefail

FAMILIE="${1:-iphone}"
case "$FAMILIE" in
  iphone|ipad) ;;
  *) echo "Unbekannt: $FAMILIE — erlaubt sind „iphone\" und „ipad\"." >&2; exit 1 ;;
esac

DEVICE="${PULSE_SIMULATOR:-}"
if [ -z "$DEVICE" ]; then
  DEVICE=$(xcrun simctl list devices available -j \
    | PULSE_FAMILIE="$FAMILIE" python3 -c "
import json, os, re, sys

familie = os.environ['PULSE_FAMILIE']
praefix = 'iPad' if familie == 'ipad' else 'iPhone'

def rank(name):
    number = re.search(praefix + r' [A-Za-z ]*?(\d+)', name)
    generation = int(number.group(1)) if number else 0   # SE, Air, mini ohne Zahl
    # Beim iPad ist „Pro\" das größte Gerät und damit das, dessen Bilder Apple
    # für den Store verlangt. Beim iPhone dieselbe Ordnung aus demselben Grund.
    variant = 2 if 'Pro Max' in name or ('Pro' in name and familie == 'ipad') \
        else 1 if 'Pro' in name else 0
    return (generation, variant)

data = json.load(sys.stdin)['devices']
best = None
for runtime, devices in data.items():
    if 'iOS' not in runtime:
        continue
    version = tuple(int(x) for x in re.findall(r'\d+', runtime.split('iOS')[-1]) or [0])
    for device in devices:
        if not device.get('isAvailable') or not device['name'].startswith(praefix):
            continue
        key = (version, rank(device['name']))
        if best is None or key > best[0]:
            best = (key, device)
if best:
    print(best[1]['udid'])
    print(best[1]['name'], file=sys.stderr)
")
fi
[ -n "$DEVICE" ] || {
  echo "Kein ${FAMILIE}-Simulator gefunden. Xcode → Settings → Components → iOS Simulator installieren." >&2
  exit 1
}
echo "$DEVICE"
