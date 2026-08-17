#!/usr/bin/env python3
"""Legt Verteilprofile an und installiert sie — damit der Bau ohne Gerät geht.

**Warum das nötig wurde.** `xcodebuild archive` mit `CODE_SIGN_STYLE=Automatic`
besorgt sich ein **Development**-Profil und signiert erst beim Ausführen auf
Verteilung um. Ein Development-Profil verlangt aber mindestens ein registriertes
Gerät, und ein Konto ohne Gerät bekommt keins:

    Communication with Apple failed: Your team has no devices from which to
    generate a provisioning profile.

Genau daran sind die Läufe 1 und 2 gescheitert — beim zweiten war die Kennung
schon in Ordnung, die Meldung blieb. `-configuration Release` half nicht, weil
die Profilart nicht an der Konfiguration hängt.

Der Ausweg ist **manuelle** Signierung: ein App-Store-Profil, hier über die
Schnittstelle angelegt und in den Ordner gelegt, den `xcodebuild` liest. Kein
Gerät, kein Anmeldefenster, kein Klick im Portal.

Schreibt die Profilnamen nach `$GITHUB_ENV`, damit der Bauschritt sie als
`PROVISIONING_PROFILE_SPECIFIER` je Ziel übergeben kann.

Aus der Umgebung: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, PULSE_BUNDLE_IDS
"""
import base64
import json
import os
import pathlib
import sys
import time

import jwt
import requests

BASIS = "https://api.appstoreconnect.apple.com/v1"
ART = "IOS_APP_STORE"
ORDNER = pathlib.Path.home() / "Library/MobileDevice/Provisioning Profiles"


def abbruch(text: str, rat: str = "") -> None:
    print(f"::error::{text}")
    if rat:
        print(rat)
    sys.exit(1)


def anmeldung() -> str:
    jetzt = int(time.time())
    try:
        return jwt.encode(
            {"iss": os.environ["ASC_ISSUER_ID"], "iat": jetzt, "exp": jetzt + 600,
             "aud": "appstoreconnect-v1"},
            os.environ["ASC_KEY_P8"],
            algorithm="ES256",
            headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
        )
    except Exception as fehler:  # noqa: BLE001
        abbruch(f"Der Schlüssel ließ sich nicht lesen: {fehler}")
    return ""


class Apple:
    def __init__(self, token: str) -> None:
        self.kopf = {"Authorization": f"Bearer {token}",
                     "Content-Type": "application/json"}

    def holen(self, pfad: str, **werte) -> dict:
        antwort = requests.get(f"{BASIS}/{pfad}", headers=self.kopf,
                               params=werte, timeout=30)
        if antwort.status_code != 200:
            abbruch(f"GET {pfad} scheiterte ({antwort.status_code}): {antwort.text[:300]}")
        return antwort.json()

    def anlegen(self, pfad: str, koerper: dict):
        return requests.post(f"{BASIS}/{pfad}", headers=self.kopf,
                             data=json.dumps(koerper), timeout=30)

    def loeschen(self, pfad: str) -> None:
        requests.delete(f"{BASIS}/{pfad}", headers=self.kopf, timeout=30)


def kennung_finden(apple: Apple, bezeichner: str) -> str:
    daten = apple.holen("bundleIds", **{"filter[identifier]": bezeichner,
                                        "limit": 200}).get("data", [])
    # **Genau vergleichen, nicht auf den Filter verlassen.** Apple filtert hier
    # als Präfix: Die Abfrage nach `de.karjoth.pulsemeter` liefert auch
    # `de.karjoth.pulsemeter.widget` mit, und wer das erste Ergebnis nimmt,
    # signiert die App mit dem Profil des Widgets.
    for eintrag in daten:
        if eintrag["attributes"]["identifier"] == bezeichner:
            return eintrag["id"]
    abbruch(
        f"Die Kennung {bezeichner} ist bei Apple nicht registriert.",
        "Sie entsteht normalerweise beim ersten Bau mit "
        "`-allowProvisioningUpdates`. Fehlt sie, im Entwicklerportal unter "
        "Identifiers eine App-ID mit genau diesem Bezeichner anlegen.",
    )
    return ""


def zertifikate(apple: Apple) -> list:
    daten = apple.holen("certificates",
                        **{"filter[certificateType]": "DISTRIBUTION",
                           "limit": 200}).get("data", [])
    if not daten:
        abbruch("Kein Verteilzertifikat im Konto.",
                "Erst den Ablauf „Zertifikat anlegen“ starten.")
    # Alle mitnehmen: Welcher private Schlüssel auf dem Läufer liegt, weiß nur
    # der Schlüsselbund. Ein Profil mit mehreren Zertifikaten passt in jedem
    # Fall — eines mit dem falschen passt in keinem.
    return [{"type": "certificates", "id": e["id"]} for e in daten]


def profil(apple: Apple, bezeichner: str, certs: list) -> str:
    name = f"PulseMeter {bezeichner} App Store"

    # Ein Profil mit diesem Namen kann aus einem früheren Lauf stammen und
    # dann ein Zertifikat führen, das es nicht mehr gibt. Wegwerfen und neu
    # anlegen ist billiger als prüfen, ob es noch passt.
    for alt in apple.holen("profiles", **{"filter[name]": name,
                                          "limit": 200}).get("data", []):
        if alt["attributes"]["name"] == name:
            apple.loeschen(f"profiles/{alt['id']}")
            print(f"  altes Profil „{name}“ verworfen")

    antwort = apple.anlegen("profiles", {"data": {
        "type": "profiles",
        "attributes": {"name": name, "profileType": ART},
        "relationships": {
            "bundleId": {"data": {"type": "bundleIds",
                                  "id": kennung_finden(apple, bezeichner)}},
            "certificates": {"data": certs},
        },
    }})

    if antwort.status_code != 201:
        rat = ""
        if antwort.status_code == 409:
            rat = ("Meist fehlt der App-ID eine Berechtigung, die die "
                   "Berechtigungsdatei verlangt — App-Gruppe, iCloud oder "
                   "Push. Im Entwicklerportal unter Identifiers die App-ID "
                   "öffnen und die Häkchen setzen.")
        abbruch(f"Profil für {bezeichner} abgelehnt "
                f"({antwort.status_code}): {antwort.text[:400]}", rat)

    merkmale = antwort.json()["data"]["attributes"]
    ORDNER.mkdir(parents=True, exist_ok=True)
    ziel = ORDNER / f"{merkmale['uuid']}.mobileprovision"
    ziel.write_bytes(base64.b64decode(merkmale["profileContent"]))
    print(f"  {bezeichner} → „{name}“ ({merkmale['uuid']}), "
          f"läuft ab {merkmale.get('expirationDate', '?')}")
    return name


def main() -> None:
    bezeichner = os.environ["PULSE_BUNDLE_IDS"].split()
    apple = Apple(anmeldung())
    certs = zertifikate(apple)
    print(f"{len(certs)} Verteilzertifikat(e) im Konto")

    namen = [profil(apple, b, certs) for b in bezeichner]

    umgebung = os.environ.get("GITHUB_ENV")
    if umgebung:
        with open(umgebung, "a", encoding="utf-8") as datei:
            for schluessel, wert in zip(("PULSE_PROFILE_APP",
                                         "PULSE_PROFILE_WIDGET"), namen):
                datei.write(f"{schluessel}={wert}\n")


if __name__ == "__main__":
    main()
