#!/usr/bin/env python3
"""Beantragt ein Verteilzertifikat bei Apple — über die Schnittstelle, nicht
über die Website.

**Warum das hier steht und nicht im Ablauf.** In einem YAML-Feld lässt sich
Python schreiben, aber nicht prüfen. Als Datei ist es lesbar, und die
Fehlermeldungen dürfen ganze Sätze sein.

Gebraucht wird das genau **einmal**: `testflight.yml` legte bis 0.59.0 bei
jedem Lauf ein neues Zertifikat an, weil ein frischer Rechner keins hat — und
nach dem dritten war die Grenze erreicht. Ein Zertifikat, das dauerhaft
abgelegt ist, macht die Grenze bedeutungslos.

Erwartet im Ordner:  antrag.csr
Schreibt:            zertifikat.cer   (DER, wie Apple es liefert)
Aus der Umgebung:    ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8
"""
import base64
import datetime
import json
import os
import sys
import time

import jwt
import requests

BASIS = "https://api.appstoreconnect.apple.com/v1"

# Apple kennt mehrere Sorten. `DISTRIBUTION` ist „Apple Distribution" und gilt
# für iOS **und** macOS; die älteren `IOS_DISTRIBUTION` sind auf eine Plattform
# festgelegt und werden für neue Konten nicht mehr ausgegeben.
SORTE = "DISTRIBUTION"


def abbruch(text: str, rat: str = "") -> None:
    print(f"::error::{text}")
    if rat:
        print(rat)
    sys.exit(1)


def anmeldung() -> str:
    """Ein kurzlebiges Token. Apple lässt höchstens zwanzig Minuten zu."""
    schluessel_id = os.environ["ASC_KEY_ID"]
    aussteller = os.environ["ASC_ISSUER_ID"]
    geheim = os.environ["ASC_KEY_P8"]

    jetzt = int(time.time())
    try:
        return jwt.encode(
            {"iss": aussteller, "iat": jetzt, "exp": jetzt + 600,
             "aud": "appstoreconnect-v1"},
            geheim,
            algorithm="ES256",
            headers={"kid": schluessel_id, "typ": "JWT"},
        )
    except Exception as fehler:  # noqa: BLE001 — die Ursache gehört in die Meldung
        abbruch(
            f"Der Schlüssel ließ sich nicht lesen: {fehler}",
            "ASC_KEY_P8 muss der **ganze** Inhalt der .p8-Datei sein, "
            "einschließlich der Zeilen -----BEGIN PRIVATE KEY----- und "
            "-----END PRIVATE KEY-----.",
        )
    return ""  # unerreichbar, beruhigt aber die Typprüfung


def kopf(token: str) -> dict:
    return {"Authorization": f"Bearer {token}",
            "Content-Type": "application/json"}


def bestand(token: str) -> list:
    antwort = requests.get(f"{BASIS}/certificates",
                           headers=kopf(token),
                           params={"filter[certificateType]": SORTE, "limit": 200},
                           timeout=30)
    if antwort.status_code != 200:
        abbruch(f"Der Bestand ließ sich nicht lesen ({antwort.status_code}): {antwort.text[:400]}")
    return antwort.json().get("data", [])


def main() -> None:
    token = anmeldung()

    vorhanden = bestand(token)
    print(f"Vorhandene Verteilzertifikate: {len(vorhanden)}")
    for eintrag in vorhanden:
        a = eintrag.get("attributes", {})
        print(f"  · {a.get('name')} — läuft ab {a.get('expirationDate')}")

    # **Warnen, nicht abbrechen.** Drei sind die übliche Grenze; ob sie hier
    # gilt, hängt an der Art der Mitgliedschaft, und das lässt sich von außen
    # nicht sicher sagen. Apple lehnt den vierten von selbst ab, und die
    # Meldung dazu ist eindeutiger als eine geratene Regel.
    if len(vorhanden) >= 3:
        print("::warning::Es liegen bereits drei Zertifikate. Wenn Apple gleich "
              "ablehnt, im Entwicklerportal unter Certificates die alten "
              "widerrufen — sie werden nach diesem Lauf nicht mehr gebraucht.")

    with open("antrag.csr", "r", encoding="utf-8") as datei:
        antrag = datei.read()

    antwort = requests.post(
        f"{BASIS}/certificates",
        headers=kopf(token),
        data=json.dumps({"data": {
            "type": "certificates",
            "attributes": {"certificateType": SORTE, "csrContent": antrag},
        }}),
        timeout=30,
    )

    if antwort.status_code != 201:
        text = antwort.text[:600]
        rat = ""
        if "MAXIMUM_NUMBER_OF_CERTIFICATES" in text or antwort.status_code == 409:
            rat = ("Die Grenze ist erreicht. Im Entwicklerportal unter "
                   "Certificates ein altes widerrufen und diesen Ablauf noch "
                   "einmal starten. Nach diesem Lauf passiert das nie wieder — "
                   "das neue Zertifikat bleibt ein Jahr im Repository liegen.")
        elif antwort.status_code in (401, 403):
            rat = ("Der Schlüssel darf das nicht. In App Store Connect unter "
                   "Users and Access › Integrations muss die Rolle **Admin** "
                   "oder **App Manager** eingetragen sein; App Manager genügt.")
        abbruch(f"Apple hat abgelehnt ({antwort.status_code}): {text}", rat)

    inhalt = antwort.json()["data"]["attributes"]["certificateContent"]
    with open("zertifikat.cer", "wb") as datei:
        datei.write(base64.b64decode(inhalt))

    merkmale = antwort.json()["data"]["attributes"]
    ablauf = merkmale.get("expirationDate", "?")
    print(f"Zertifikat angelegt: {merkmale.get('name')}")
    print(f"Läuft ab: {ablauf}")

    zusammenfassung = os.environ.get("GITHUB_STEP_SUMMARY")
    if zusammenfassung:
        with open(zusammenfassung, "a", encoding="utf-8") as datei:
            datei.write(f"\n**Zertifikat läuft ab am {ablauf}.** "
                        "Dann diesen Ablauf noch einmal starten.\n")


if __name__ == "__main__":
    main()
