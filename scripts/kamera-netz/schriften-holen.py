#!/usr/bin/env python3
"""Holt die Siebensegment-Schriften DSEG (SIL Open Font License 1.1, Keshikan) für den Generator.

Die Schriften dienen nur dem Training: Das Netz lernt an ihnen, wie echte Anzeigen aussehen
(Segmentform, Schrägen, unbeleuchtete Geistersegmente, Buchstaben in 14 Segmenten). In der App
läuft das Netz, nicht die Schrift. Die Dateien gehören nicht ins Repository (`dseg/` steht in .gitignore).

    python3 schriften-holen.py
"""
import json, pathlib, urllib.request

ZIEL = pathlib.Path(__file__).resolve().parent / "dseg"
VERSION = "0.46.0"
ZIEL.mkdir(exist_ok=True)
liste = json.load(urllib.request.urlopen(f"https://data.jsdelivr.com/v1/package/npm/dseg@{VERSION}/flat"))["files"]
for f in liste:
    if f["name"].endswith(".ttf"):
        ziel = ZIEL / f["name"].rsplit("/", 1)[-1]
        if not ziel.exists():
            ziel.write_bytes(urllib.request.urlopen(f"https://cdn.jsdelivr.net/npm/dseg@{VERSION}{f['name']}").read())
print(len(list(ZIEL.glob("*.ttf"))), "Schriften in", ZIEL)
