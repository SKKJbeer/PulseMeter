#!/usr/bin/env bash
# Gemeinsame Simulator-Auswahl für die anderen Skripte.
# Nimmt das neueste verfügbare iPhone, damit nichts fest verdrahtet ist und
# eine neue Xcode-Fassung die Skripte nicht bricht.
set -euo pipefail
DEVICE="${PULSE_SIMULATOR:-}"
if [ -z "$DEVICE" ]; then
  DEVICE=$(xcrun simctl list devices available -j \
    | python3 -c "
import json,sys,re
data=json.load(sys.stdin)['devices']
best=None
for runtime, devices in data.items():
    if 'iOS' not in runtime: continue
    version=tuple(int(x) for x in re.findall(r'\d+', runtime.split('iOS')[-1]) or [0])
    for d in devices:
        if not d.get('isAvailable'): continue
        if not d['name'].startswith('iPhone'): continue
        key=(version, d['name'])
        if best is None or key > best[0]: best=(key, d)
print(best[1]['udid'] if best else '')
")
fi
[ -n "$DEVICE" ] || { echo "Kein iPhone-Simulator gefunden. Xcode → Settings → Components → iOS Simulator installieren." >&2; exit 1; }
echo "$DEVICE"
