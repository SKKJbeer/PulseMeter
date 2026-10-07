#!/usr/bin/env python3
"""Misst, an welcher Stelle Zählora in der Suche des App Store steht.

Ohne Konto und ohne Schlüssel: Apples öffentliche Suche liefert dieselbe Liste,
die ein Telefon in Deutschland zeigt, bis Platz 50. Gemessen wird gegen die
App-Kennung, nicht gegen den Namen — der ändert sich, die Kennung nicht.

**Über curl, nicht über urllib.** Am 7. Oktober antwortete der Proxy der
Cloud-Sitzung auf Pythons eigenen Abruf mit 403 und auf curl mit 200. Und Apple
sperrt nach etwa zehn Suchen hintereinander für eine Weile; deshalb die Pause
je Begriff und bis zu drei Versuche. Ein Begriff ohne Antwort wird als
„nicht gemessen" ausgegeben, nie als „nicht gefunden" — das wären zwei
verschiedene Aussagen.

Aufruf:  scripts/store-rang.py                 # die Begriffe unten
         scripts/store-rang.py "zählerstand"   # einzelne Begriffe
"""
import json
import subprocess
import sys
import time
import urllib.parse

APP = 6802262743

# Die Wörter aus Name, Untertitel und Schlagwortfeld (`docs/09-appstore.md`)
# und die Suchen, die jemand am Zähler tatsächlich tippt.
BEGRIFFE = [
    "zählerstand", "zählerstände", "zählerstand app", "zählerstand ablesen",
    "zähler ablesen", "strom ablesen", "gas ablesen", "wasser ablesen",
    "stromzähler", "stromzähler ablesen", "gaszähler", "wasserzähler",
    "stromverbrauch", "gasverbrauch", "verbrauch", "nebenkosten",
]


def suche(begriff: str) -> list | None:
    adresse = ("https://itunes.apple.com/search?country=de&entity=software&limit=50&term="
               + urllib.parse.quote(begriff))
    for versuch in range(3):
        antwort = subprocess.run(["curl", "-sS", "--max-time", "20", adresse],
                                 capture_output=True, text=True).stdout
        try:
            return json.loads(antwort)["results"]
        except (ValueError, KeyError):
            time.sleep(20 * (versuch + 1))
    return None


def main() -> int:
    begriffe = sys.argv[1:] or BEGRIFFE
    fehlend = 0
    print(f"{'Suche':24} {'Rang':>5}  Erste drei (Bewertungen)")
    for nummer, begriff in enumerate(begriffe):
        if nummer:
            time.sleep(8)
        treffer = suche(begriff)
        if treffer is None:
            fehlend += 1
            print(f"{begriff:24} {'—':>5}  nicht gemessen, Apple hat gesperrt")
            continue
        kennungen = [t["trackId"] for t in treffer]
        rang = str(kennungen.index(APP) + 1) if APP in kennungen else "> 50"
        erste = ", ".join(f'{t["trackName"][:24]} ({t.get("userRatingCount", 0)})'
                          for t in treffer[:3])
        print(f"{begriff:24} {rang:>5}  {erste}", flush=True)
    return 1 if fehlend else 0


if __name__ == "__main__":
    sys.exit(main())
