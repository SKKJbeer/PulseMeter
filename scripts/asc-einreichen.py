#!/usr/bin/env python3
"""Reicht die Fassung bei der Prüfung ein — und zieht sie auf Wunsch zurück.

**Warum das ein Skript ist und kein Klick.** Nicht aus Bequemlichkeit: Der Weg
über die Schnittstelle hängt drei Dinge hintereinander, die in der Oberfläche
unsichtbar sind — der Bau muss an der Fassung hängen, die Einreichung braucht
einen Eintrag, und erst ein zweiter Aufruf schickt sie los. Wer das klickt,
sieht nur einen Knopf und merkt nicht, wenn der erste Schritt fehlt.

**Es ist umkehrbar, solange die Prüfung nicht durch ist.** `--zurueckziehen`
nimmt die Einreichung zurück; danach lässt sich alles ändern und erneut
einreichen. Nach der Freigabe geht das nicht mehr — dann ist die App im Laden.

    ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_P8=… python3 scripts/asc-einreichen.py
    …                                                                 --einreichen
    …                                                                 --zurueckziehen
"""

import json
import os
import sys
import time

import jwt
import requests

BASIS = "https://api.appstoreconnect.apple.com"
BUNDLE = "de.karjoth.pulsemeter"

# Die Zustände, in denen eine Einreichung schon unterwegs ist. Eine zweite
# anzulegen, während eine läuft, lehnt Apple ab — und zwar mit einer Meldung,
# die nach einem Fehler klingt statt nach „steht schon".
UNTERWEGS = {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW",
             "UNRESOLVED_ISSUES"}


def token() -> str:
    fehlt = [n for n in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_P8")
             if not os.environ.get(n)]
    if fehlt:
        print(f"::error::Es fehlen: {', '.join(fehlt)}")
        sys.exit(1)
    jetzt = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": jetzt,
                       "exp": jetzt + 1200, "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256",
                      headers={"kid": os.environ["ASC_KEY_ID"]})


class Apple:
    def __init__(self) -> None:
        self.kopf = {"Authorization": f"Bearer {token()}",
                     "Content-Type": "application/json"}

    def holen(self, pfad: str, **werte):
        a = requests.get(f"{BASIS}/{pfad}", headers=self.kopf, params=werte,
                         timeout=30)
        return a.status_code, a

    def anlegen(self, pfad: str, koerper: dict):
        a = requests.post(f"{BASIS}/{pfad}", headers=self.kopf,
                          data=json.dumps(koerper), timeout=60)
        return a.status_code, a

    def aendern(self, pfad: str, koerper: dict):
        a = requests.patch(f"{BASIS}/{pfad}", headers=self.kopf,
                           data=json.dumps(koerper), timeout=60)
        return a.status_code, a

    def loeschen(self, pfad: str) -> int:
        return requests.delete(f"{BASIS}/{pfad}", headers=self.kopf,
                               timeout=30).status_code


def kurz(antwort) -> str:
    try:
        fehler = antwort.json().get("errors", [])
        if fehler:
            e = fehler[0]
            return f"{e.get('title', '')} — {e.get('detail', '')}"[:300]
    except ValueError:
        pass
    return antwort.text[:300]


def feld(eintrag, name: str):
    return (eintrag or {}).get("attributes", {}).get(name)


def app_finden(apple: Apple) -> str:
    stand, antwort = apple.holen("v1/apps", **{"filter[bundleId]": BUNDLE,
                                               "limit": 20})
    for eintrag in (antwort.json().get("data", []) if stand == 200 else []):
        if eintrag["attributes"].get("bundleId") == BUNDLE:
            return eintrag["id"]
    print(f"::error::Zu {BUNDLE} gibt es keinen App-Eintrag ({stand}).")
    sys.exit(1)


def fassung_finden(apple: Apple, app_id: str):
    stand, antwort = apple.holen(f"v1/apps/{app_id}/appStoreVersions",
                                 **{"limit": 5, "filter[platform]": "IOS"})
    daten = antwort.json().get("data", []) if stand == 200 else []
    if not daten:
        print(f"::error::Keine Fassung lesbar ({stand}).")
        sys.exit(1)
    return daten[0]


def bau_anhaengen(apple: Apple, app_id: str, fassung_id: str) -> bool:
    """Der Bau muss an der Fassung hängen, sonst gibt es nichts zu prüfen.

    **Das ist der Schritt, den man in der Oberfläche vergisst.** Dort steht der
    Bau in einer Liste daneben, und ohne Auswahl bleibt die Fassung leer — die
    Einreichung scheitert dann an einer Meldung, die den Bau nicht erwähnt.
    """
    stand, antwort = apple.holen(f"v1/appStoreVersions/{fassung_id}/build")
    if stand == 200 and (antwort.json().get("data") or None):
        vorhanden = antwort.json()["data"]
        stand, b = apple.holen(f"v1/builds/{vorhanden['id']}")
        nummer = feld(b.json().get("data") if stand == 200 else None, "version")
        print(f"  ✓ Bau {nummer or vorhanden['id']} hängt schon an der Fassung")
        return True

    stand, antwort = apple.holen("v1/builds", **{
        "filter[app]": app_id, "limit": 20, "sort": "-version"})
    if stand != 200:
        print(f"  ✗ Die Bauten sind nicht lesbar ({stand}) — {kurz(antwort)}")
        return False

    tauglich = [e for e in antwort.json().get("data", [])
                if feld(e, "processingState") == "VALID"]
    if not tauglich:
        print("  ✗ Kein Bau im Zustand VALID — die Verarbeitung läuft noch.")
        return False

    bau = tauglich[0]
    stand, antwort = apple.aendern(
        f"v1/appStoreVersions/{fassung_id}/relationships/build",
        {"data": {"type": "builds", "id": bau["id"]}})
    if stand in (200, 204):
        print(f"  ✓ Bau {feld(bau, 'version')} an die Fassung gehängt")
        return True
    print(f"  ✗ Bau {feld(bau, 'version')} ließ sich nicht anhängen "
          f"({stand}) — {kurz(antwort)}")
    return False


def laufende(apple: Apple, app_id: str):
    """Die Einreichung, die gerade unterwegs ist — oder None."""
    stand, antwort = apple.holen("v1/reviewSubmissions", **{
        "filter[app]": app_id, "limit": 20, "sort": "-submittedDate"})
    if stand != 200:
        return None
    for eintrag in antwort.json().get("data", []):
        if feld(eintrag, "state") in UNTERWEGS:
            return eintrag
    return None


def einreichen(apple: Apple, app_id: str, fassung) -> int:
    zustand = feld(fassung, "appStoreState") or feld(fassung, "appVersionState")
    print(f"::notice::Fassung {feld(fassung, 'versionString')} — {zustand}")

    schon = laufende(apple, app_id)
    if schon is not None:
        # **Kein Fehler.** Zweimal einreichen zu wollen ist der häufigste Fall,
        # wenn jemand nicht sicher ist, ob der erste Versuch durchging.
        print(f"::notice::Steht schon bei der Prüfung — {feld(schon, 'state')}. "
              f"Nichts zu tun.")
        return 0

    if not bau_anhaengen(apple, app_id, fassung["id"]):
        print("::error::Ohne Bau an der Fassung wird nicht eingereicht.")
        return 1

    stand, antwort = apple.anlegen("v1/reviewSubmissions", {"data": {
        "type": "reviewSubmissions",
        "attributes": {"platform": "IOS"},
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
    }})
    if stand not in (200, 201):
        print(f"::error::Die Einreichung ließ sich nicht anlegen ({stand}) "
              f"— {kurz(antwort)}")
        return 1
    einreichung = antwort.json()["data"]["id"]
    print(f"  ✓ Einreichung angelegt ({einreichung})")

    stand, antwort = apple.anlegen("v1/reviewSubmissionItems", {"data": {
        "type": "reviewSubmissionItems",
        "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions",
                                          "id": einreichung}},
            "appStoreVersion": {"data": {"type": "appStoreVersions",
                                         "id": fassung["id"]}},
        },
    }})
    if stand not in (200, 201):
        print(f"::error::Die Fassung ließ sich der Einreichung nicht "
              f"hinzufügen ({stand}) — {kurz(antwort)}")
        # **Aufräumen, sonst blockiert der Fehlschlag den nächsten Versuch.**
        # Die angelegte Einreichung steht danach leer in READY_FOR_REVIEW; der
        # nächste Lauf fände sie, meldete „steht schon bei der Prüfung" und
        # täte nichts — eine Einreichung, die nie eine war, sähe für immer wie
        # eine aus. Erster Anlauf am 29. August hat genau das hinterlassen.
        weg = apple.loeschen(f"v1/reviewSubmissions/{einreichung}")
        print(f"  · leere Einreichung wieder entfernt (Antwort {weg})")
        return 1
    print("  ✓ Fassung 1.0 der Einreichung hinzugefügt")

    # **Erst dieser Aufruf schickt sie los.** Bis hierher liegt alles nur
    # bereit — ein Abbruch davor kostet nichts.
    stand, antwort = apple.aendern(f"v1/reviewSubmissions/{einreichung}", {
        "data": {"type": "reviewSubmissions", "id": einreichung,
                 "attributes": {"submitted": True}}})
    if stand not in (200, 204):
        print(f"::error::Das Absenden ging nicht ({stand}) — {kurz(antwort)}")
        return 1

    stand, antwort = apple.holen(f"v1/reviewSubmissions/{einreichung}")
    jetzt = feld(antwort.json().get("data") if stand == 200 else None, "state")
    print(f"::notice::Eingereicht. Zustand: {jetzt}")
    return 0


def zurueckziehen(apple: Apple, app_id: str) -> int:
    schon = laufende(apple, app_id)
    if schon is None:
        print("::notice::Es ist gerade nichts bei der Prüfung.")
        return 0
    stand, antwort = apple.aendern(f"v1/reviewSubmissions/{schon['id']}", {
        "data": {"type": "reviewSubmissions", "id": schon["id"],
                 "attributes": {"canceled": True}}})
    if stand in (200, 204):
        print("::notice::Zurückgezogen. Die Fassung lässt sich wieder ändern.")
        return 0
    print(f"::error::Zurückziehen ging nicht ({stand}) — {kurz(antwort)}")
    return 1


def main() -> int:
    apple = Apple()
    app_id = app_finden(apple)
    fassung = fassung_finden(apple, app_id)

    if "--zurueckziehen" in sys.argv:
        return zurueckziehen(apple, app_id)

    if "--einreichen" in sys.argv:
        return einreichen(apple, app_id, fassung)

    # **Ohne Schalter wird nur nachgesehen.** Einreichen ist der einzige
    # Schritt in diesem Projekt, den ein Fehlgriff nach außen trägt; er
    # verlangt deshalb, dass man ihn ausdrücklich will.
    zustand = feld(fassung, "appStoreState") or feld(fassung, "appVersionState")
    schon = laufende(apple, app_id)
    print(f"Fassung {feld(fassung, 'versionString')}: {zustand}")
    print(f"Bei der Prüfung: {feld(schon, 'state') if schon else 'nichts'}")
    print("\nZum Einreichen: --einreichen · zum Zurückziehen: --zurueckziehen")
    return 0


if __name__ == "__main__":
    sys.exit(main())
