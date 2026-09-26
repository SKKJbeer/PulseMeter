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
  iphone|ipad|iphone-klein|ipad-klein) ;;
  *) echo "Unbekannt: $FAMILIE — erlaubt sind iphone, ipad, iphone-klein und ipad-klein." >&2; exit 1 ;;
esac

# **Kleine und ältere Geräte, seit 0.117.2.** Vom Gründer am 26. September:
# prüfen, „ob das überall perfekt dargestellt wird, auch für ältere Modelle
# und nicht nur die neuesten". Bis dahin fotografierte die CI nur das größte
# iPhone und das größte iPad mit dem neuesten iOS.
#
# `iphone-klein` ist ein iPhone SE, 4,7 Zoll mit Home-Taste: der kleinste
# Schirm, auf dem die App läuft. `ipad-klein` ist ein iPad mini. Beide mit dem
# **ältesten** iOS ab 18, das der Rechner mitbringt, weil die App ab iOS 18
# läuft und ein älteres Gerät oft auf einem älteren System bleibt. Fehlt das
# Gerät, wird es angelegt: Ein Läufer bringt die Gerätetypen mit, aber nicht
# für jeden eine fertige Instanz.
if [ -z "${PULSE_SIMULATOR:-}" ] && [ "${FAMILIE%-klein}" != "$FAMILIE" ]; then
  DEVICE=$(PULSE_FAMILIE="$FAMILIE" python3 - <<'PY_KLEIN'
import json, os, re, subprocess, sys
familie = os.environ["PULSE_FAMILIE"]
wunsch = ["iPhone SE (3rd generation)", "iPhone SE (2nd generation)"] if familie == "iphone-klein" \
    else ["iPad mini (A17 Pro)", "iPad mini (6th generation)"]
def lade(*args):
    return json.loads(subprocess.check_output(["xcrun", "simctl", "list", *args, "-j"]))
laufzeiten = [r for r in lade("runtimes")["runtimes"]
              if r.get("isAvailable") and r.get("platform", "iOS") == "iOS"
              and tuple(int(x) for x in r["version"].split(".")[:2]) >= (18, 0)]
laufzeiten.sort(key=lambda r: tuple(int(x) for x in r["version"].split(".")))
typen = {t["name"]: t["identifier"] for t in lade("devicetypes")["devicetypes"]}
geraete = lade("devices", "available")["devices"]
for laufzeit in laufzeiten:
    unterstuetzt = {t["name"] for t in laufzeit.get("supportedDeviceTypes", [])}
    for name in wunsch:
        if unterstuetzt and name not in unterstuetzt:
            continue
        for g in geraete.get(laufzeit["identifier"], []):
            if g["name"] == name:
                print(g["udid"]); print(f"{name}, iOS {laufzeit['version']}", file=sys.stderr); sys.exit(0)
        if name in typen:
            udid = subprocess.check_output(["xcrun", "simctl", "create", f"{name} (Zählora)",
                                            typen[name], laufzeit["identifier"]]).decode().strip()
            print(udid); print(f"{name}, iOS {laufzeit['version']}, neu angelegt", file=sys.stderr); sys.exit(0)
sys.exit(f"Kein Gerät für {familie}: weder {', '.join(wunsch)} mit iOS ab 18")
PY_KLEIN
)
  echo "$DEVICE"
  exit 0
fi

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
