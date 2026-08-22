#!/usr/bin/env python3
"""Schreibt „Was ist neu" an den frisch hochgeladenen Bau — und meldet, wann er
bei den Testern steht.

**Warum es das gibt.** Der Ablauf `testflight.yml` fragt seit dem ersten Tag
nach einem Hinweis: „Was ist neu? Steht später bei den Testern." Der Text wurde
entgegengenommen und dann nirgends verwendet. Zehn Bauten lang stand bei den
Testern nichts — ein Versprechen, das die Oberfläche gibt und der Ablauf nicht
hält. Genau das verbietet dieses Projekt sich selbst (`docs/09-appstore.md`).

`altool --upload-app` lädt nur hoch. Die Testhinweise hängen nicht am Paket,
sondern am Bau in App Store Connect, und dorthin führt nur die Schnittstelle.
Sie sind erst erreichbar, wenn Apple den Bau verarbeitet hat — deshalb wird
gewartet.

**Was dieses Skript nicht tut:** Es gibt nichts für externe Tester frei. Das
verlangt eine Beta-Prüfung durch Apple und ist eine Entscheidung, keine
Automatisierung. Für die interne Gruppe — den Gründer auf seinem eigenen Gerät —
ist der Bau nach der Verarbeitung sofort da.

Aus der Umgebung:
  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8   Zugang, wie bei `asc-profil.py`
  PULSE_BUNDLE_ID                         Bezeichner der App
  PULSE_BUILD                             Buildnummer (die Laufnummer)
  PULSE_HINWEIS                           Der Text für die Tester
"""
import json
import os
import sys
import time

import jwt
import requests

BASIS = "https://api.appstoreconnect.apple.com/v1"
SPRACHE = "de-DE"

# Apple braucht für einen Bau meist zwei bis zehn Minuten. Zwanzig sind
# großzügig; länger zu warten kostet nur Läuferzeit, denn der Bau kommt
# ohnehin an — das Skript wäre dann nur nicht mehr dabei.
GEDULD_SEKUNDEN = 20 * 60
ABSTAND_SEKUNDEN = 30


def hinweis(text: str) -> None:
    print(f"::notice::{text}")


def abbruch(text: str, rat: str = "") -> None:
    print(f"::error::{text}")
    if rat:
        print(rat)
    sys.exit(1)


def anmeldung() -> str:
    jetzt = int(time.time())
    try:
        return jwt.encode(
            {"iss": os.environ["ASC_ISSUER_ID"], "iat": jetzt, "exp": jetzt + 900,
             "aud": "appstoreconnect-v1"},
            os.environ["ASC_KEY_P8"],
            algorithm="ES256",
            headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
        )
    except Exception as fehler:  # noqa: BLE001
        abbruch(f"Der Schlüssel ließ sich nicht lesen: {fehler}")
    return ""


class Apple:
    def __init__(self) -> None:
        self.kopf = {"Authorization": f"Bearer {anmeldung()}",
                     "Content-Type": "application/json"}

    def holen(self, pfad: str, **werte) -> dict:
        antwort = requests.get(f"{BASIS}/{pfad}", headers=self.kopf,
                               params=werte, timeout=30)
        if antwort.status_code != 200:
            abbruch(f"GET {pfad} scheiterte ({antwort.status_code}): "
                    f"{antwort.text[:300]}")
        return antwort.json()

    def schreiben(self, verb: str, pfad: str, koerper: dict):
        return requests.request(verb, f"{BASIS}/{pfad}", headers=self.kopf,
                                data=json.dumps(koerper), timeout=30)


def app_finden(apple: Apple, bezeichner: str) -> str:
    for eintrag in apple.holen("apps", **{"filter[bundleId]": bezeichner,
                                          "limit": 200}).get("data", []):
        # Genau vergleichen: Apple filtert Bezeichner als Präfix, und
        # `de.karjoth.pulsemeter` liefert auch das Widget mit. Dieselbe Falle
        # wie in `asc-profil.py`.
        if eintrag["attributes"]["bundleId"] == bezeichner:
            return eintrag["id"]
    abbruch(f"Zu {bezeichner} gibt es in App Store Connect keine App.",
            "In App Store Connect unter „Apps“ eine App mit genau diesem "
            "Bezeichner anlegen.")
    return ""


def bau_abwarten(apple: Apple, app_id: str, nummer: str) -> str | None:
    """Wartet, bis Apple den Bau verarbeitet hat. Gibt seine ID zurück."""
    ende = time.time() + GEDULD_SEKUNDEN
    zuletzt = ""
    while time.time() < ende:
        treffer = apple.holen("builds", **{"filter[app]": app_id,
                                           "filter[version]": nummer,
                                           "limit": 1}).get("data", [])
        if treffer:
            zustand = treffer[0]["attributes"]["processingState"]
            if zustand != zuletzt:
                hinweis(f"Bau {nummer}: {zustand}")
                zuletzt = zustand
            if zustand == "VALID":
                return treffer[0]["id"]
            if zustand in ("INVALID", "FAILED"):
                abbruch(f"Apple hat Bau {nummer} abgelehnt ({zustand}).",
                        "Der Grund steht in App Store Connect unter TestFlight "
                        "beim Bau selbst.")
        time.sleep(ABSTAND_SEKUNDEN)
    return None


def text_setzen(apple: Apple, bau_id: str, text: str) -> None:
    """Legt die Testhinweise an — oder ändert sie, falls es sie schon gibt."""
    vorhanden = apple.holen(f"builds/{bau_id}/betaBuildLocalizations",
                            **{"limit": 50}).get("data", [])
    for eintrag in vorhanden:
        if eintrag["attributes"]["locale"] == SPRACHE:
            antwort = apple.schreiben(
                "PATCH", f"betaBuildLocalizations/{eintrag['id']}",
                {"data": {"type": "betaBuildLocalizations", "id": eintrag["id"],
                          "attributes": {"whatsNew": text}}})
            if antwort.status_code not in (200, 204):
                abbruch(f"Die Testhinweise ließen sich nicht ändern "
                        f"({antwort.status_code}): {antwort.text[:300]}")
            return

    antwort = apple.schreiben("POST", "betaBuildLocalizations", {
        "data": {
            "type": "betaBuildLocalizations",
            "attributes": {"locale": SPRACHE, "whatsNew": text},
            "relationships": {"build": {"data": {"type": "builds", "id": bau_id}}},
        }
    })
    if antwort.status_code not in (200, 201):
        abbruch(f"Die Testhinweise ließen sich nicht anlegen "
                f"({antwort.status_code}): {antwort.text[:300]}")


def main() -> None:
    nummer = os.environ.get("PULSE_BUILD", "").strip()
    text = os.environ.get("PULSE_HINWEIS", "").strip()
    bezeichner = os.environ.get("PULSE_BUNDLE_ID", "").strip()
    if not (nummer and bezeichner):
        abbruch("PULSE_BUILD und PULSE_BUNDLE_ID müssen gesetzt sein.")
    if not text:
        hinweis("Kein Hinweistext angegeben — es gibt nichts einzutragen.")
        return

    apple = Apple()
    bau = bau_abwarten(apple, app_finden(apple, bezeichner), nummer)
    if bau is None:
        # **Kein Fehlschlag.** Der Bau ist hochgeladen und kommt an; nur die
        # Verarbeitung dauert heute länger als die Geduld dieses Skripts. Den
        # Lauf deswegen rot zu färben würde eine Meldung erzeugen, die auf
        # nichts hinweist, was zu tun wäre.
        hinweis(f"Bau {nummer} ist nach {GEDULD_SEKUNDEN // 60} Minuten noch "
                "in Verarbeitung. Die Testhinweise lassen sich in App Store "
                "Connect nachtragen.")
        return

    text_setzen(apple, bau, text)
    hinweis(f"Bau {nummer} steht bereit, die Testhinweise sind eingetragen.")


if __name__ == "__main__":
    main()
