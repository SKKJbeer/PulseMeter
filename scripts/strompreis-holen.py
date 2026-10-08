#!/usr/bin/env python3
"""Holt die Strompreise für Haushalte bei Eurostat und schreibt sie in die Seite.

Quelle: Eurostat, Datensatz `nrg_pc_204` (DOI 10.2908/NRG_PC_204), Haushalte
mit 2.500 bis 4.999 kWh im Jahr (Band DC), alle Steuern und Abgaben, Euro je
kWh, je Halbjahr. Deutschland und der Durchschnitt der EU-27.

**Warum ein Skript und keine abgeschriebene Tabelle.** Eurostat ergänzt zweimal
im Jahr ein Halbjahr und korrigiert gelegentlich ältere Werte. Abgeschrieben
wäre die Seite nach dem nächsten Mal falsch, ohne dass es jemand merkt. So
steht der Stand des Abrufs in der Seite, und `check-website.mjs` hält die
Sätze im Text an diesen Zahlen fest.

**Warum Eurostat.** Die Daten dürfen mit Quellenangabe auch kommerziell genutzt
werden; Änderungen (hier: Euro in Cent, Übersetzung) sind kenntlich zu machen.
Das steht auf der Seite unter der Grafik.

Aufruf: scripts/strompreis-holen.py
"""
import datetime
import json
import pathlib
import re
import subprocess
import sys

SEITE = pathlib.Path(__file__).resolve().parent.parent / "docs/website/strompreis-entwicklung.html"
ADRESSE = ("https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/nrg_pc_204"
           "?format=JSON&lang=EN&geo={geo}&nrg_cons=KWH2500-4999&currency=EUR&tax=I_TAX&unit=KWH")


def reihe(geo: str) -> dict[str, float]:
    # curl statt urllib: Der Proxy der Cloud-Sitzung lehnt urllib ab (Baukasten).
    roh = subprocess.run(["curl", "-sS", "-L", "--max-time", "60", ADRESSE.format(geo=geo)],
                         capture_output=True, text=True, check=True).stdout
    daten = json.loads(roh)
    zeiten = {i: k for k, i in daten["dimension"]["time"]["category"]["index"].items()}
    return {zeiten[int(i)]: w for i, w in daten["value"].items() if w is not None}


def main() -> int:
    de, eu = reihe("DE"), reihe("EU27_2020")
    halbjahre = sorted(de)
    zeilen = [f'      ["{h}", {round(de[h] * 100, 2)}, {round(eu[h] * 100, 2) if h in eu else "null"}]'
              for h in halbjahre]
    block = ("/* DATEN-ANFANG, geschrieben von scripts/strompreis-holen.py */\n"
             f'    var ABGERUFEN = "{datetime.date.today().isoformat()}";\n'
             "    // [Halbjahr, Deutschland, EU-27] in Cent je kWh\n"
             "    var PREISE = [\n" + ",\n".join(zeilen) + "\n    ];\n"
             "    /* DATEN-ENDE */")
    seite = SEITE.read_text(encoding="utf-8")
    neu, n = re.subn(r"/\* DATEN-ANFANG.*?/\* DATEN-ENDE \*/", lambda _: block, seite, flags=re.S)
    if n != 1:
        print("Markierung DATEN-ANFANG/DATEN-ENDE nicht gefunden", file=sys.stderr)
        return 1
    SEITE.write_text(neu, encoding="utf-8")
    print(f"{len(halbjahre)} Halbjahre, {halbjahre[0]} bis {halbjahre[-1]}; "
          f"zuletzt Deutschland {de[halbjahre[-1]] * 100:.2f} ct")
    return 0


if __name__ == "__main__":
    sys.exit(main())
