#!/usr/bin/env bash
# Wählt einen Simulator aus. Ohne Vorgabe das neueste iPhone.
#
# Die Auswahl darf sich nicht auf die alphabetische Reihenfolge der Namen
# verlassen: „iPhone SE" steht dort hinter „iPhone 16 Pro", weil S hinter 1
# kommt. Deshalb wird die Zahl im Namen ausgewertet.
set -euo pipefail
DEVICE="${PULSE_SIMULATOR:-}"
if [ -z "$DEVICE" ]; then
  DEVICE=$(xcrun simctl list devices available -j \
    | python3 -c "
import json, re, sys

def rank(name):
    number = re.search(r'iPhone (\d+)', name)
    generation = int(number.group(1)) if number else 0   # SE und Ältere ohne Zahl
    variant = 2 if 'Pro Max' in name else 1 if 'Pro' in name else 0
    return (generation, variant)

data = json.load(sys.stdin)['devices']
best = None
for runtime, devices in data.items():
    if 'iOS' not in runtime:
        continue
    version = tuple(int(x) for x in re.findall(r'\d+', runtime.split('iOS')[-1]) or [0])
    for device in devices:
        if not device.get('isAvailable') or not device['name'].startswith('iPhone'):
            continue
        key = (version, rank(device['name']))
        if best is None or key > best[0]:
            best = (key, device)
if best:
    print(best[1]['udid'])
    print(best[1]['name'], file=sys.stderr)
")
fi
[ -n "$DEVICE" ] || { echo "Kein iPhone-Simulator gefunden. Xcode → Settings → Components → iOS Simulator installieren." >&2; exit 1; }
echo "$DEVICE"
