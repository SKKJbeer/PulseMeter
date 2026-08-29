#!/usr/bin/env python3
"""Sagt, ob die App im Laden steht — und sonst nichts.

Eine Zeile Auskunft für `live-schalten.yml`: `live=ja` oder `live=nein` in
`$GITHUB_OUTPUT`, dazu ein Satz ins Protokoll.

**Warum ein eigenes Skript und keine Zeile im Ablauf.** Die Frage ist heikler
als sie aussieht: `READY_FOR_SALE` steht an der Fassung, nicht an der App, und
eine Fassung in Arbeit steht direkt daneben mit einem anderen Zustand. Wer die
erstbeste nimmt, bekommt bei der zweiten Fassung eine falsche Antwort — und der
Knopf auf der Website schlägt um, während die neue Fassung noch geprüft wird.

Gefragt wird deshalb nach **irgendeiner** Fassung im Verkaufszustand, nicht nach
der neuesten.
"""

import os
import sys
import time

import jwt
import requests

BASIS = "https://api.appstoreconnect.apple.com"
BUNDLE = "de.karjoth.pulsemeter"

# Beide heißen „steht im Laden". `READY_FOR_SALE` ist der Normalfall;
# `PENDING_DEVELOPER_RELEASE` heißt, Apple hat freigegeben und wartet auf einen
# Knopfdruck — dann steht die App noch **nicht** drin, und der Knopf bleibt aus.
IM_LADEN = {"READY_FOR_SALE"}


def token() -> str:
    jetzt = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": jetzt,
                       "exp": jetzt + 600, "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256",
                      headers={"kid": os.environ["ASC_KEY_ID"]})


def melden(live: bool, satz: str) -> int:
    print(f"::notice::{satz}")
    ausgabe = os.environ.get("GITHUB_OUTPUT")
    if ausgabe:
        with open(ausgabe, "a", encoding="utf-8") as datei:
            datei.write(f"live={'ja' if live else 'nein'}\n")
    return 0


def main() -> int:
    kopf = {"Authorization": f"Bearer {token()}"}

    antwort = requests.get(f"{BASIS}/v1/apps", headers=kopf, timeout=30,
                           params={"filter[bundleId]": BUNDLE, "limit": 20})
    if antwort.status_code != 200:
        # **Ein Fehlschlag ist kein „nein".** Er sagt nur, dass wir es nicht
        # wissen — und der Knopf bleibt, wie er ist. Genau diese Verwechslung
        # hat heute schon einmal „verkäuflich in 0 Ländern" gemeldet.
        return melden(False, f"Apple nicht erreichbar ({antwort.status_code}) "
                             f"— der Knopf bleibt unverändert.")
    treffer = [e for e in antwort.json().get("data", [])
               if e["attributes"].get("bundleId") == BUNDLE]
    if not treffer:
        return melden(False, "Kein App-Eintrag gefunden.")

    antwort = requests.get(f"{BASIS}/v1/apps/{treffer[0]['id']}/appStoreVersions",
                           headers=kopf, timeout=30,
                           params={"limit": 20, "filter[platform]": "IOS"})
    if antwort.status_code != 200:
        return melden(False, f"Die Fassungen sind nicht lesbar "
                             f"({antwort.status_code}) — der Knopf bleibt.")

    zustaende = {}
    for eintrag in antwort.json().get("data", []):
        merkmale = eintrag.get("attributes", {})
        zustaende[merkmale.get("versionString", "?")] = (
            merkmale.get("appStoreState") or merkmale.get("appVersionState"))

    verkauft = [v for v, z in zustaende.items() if z in IM_LADEN]
    uebersicht = ", ".join(f"{v}: {z}" for v, z in sorted(zustaende.items()))

    if verkauft:
        return melden(True, f"Im Laden: Fassung {', '.join(sorted(verkauft))} "
                            f"({uebersicht})")
    return melden(False, f"Noch nicht im Laden ({uebersicht or 'keine Fassung'})")


if __name__ == "__main__":
    sys.exit(main())
