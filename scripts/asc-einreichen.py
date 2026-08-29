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
# **`READY_FOR_REVIEW` gehört nicht dazu**, und das war die zweite Hälfte des
# Fehlers. Es heißt „angelegt und bereit zum Abschicken", nicht „bei der
# Prüfung". Wer es hier einträgt, meldet bei jedem zweiten Lauf „steht schon
# bei der Prüfung" — und schickt nie etwas ab.
UNTERWEGS = {"WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES"}


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


def alle(apple: Apple, app_id: str) -> list:
    """Alle Einreichungen der App.

    **Ohne `sort`, und das ist der Kern eines teuren Fehlers.** Hier stand
    `sort=-submittedDate`. Eine Einreichung, die noch nicht abgeschickt wurde,
    **hat kein Absendedatum** — genau die also, nach denen hier gesucht wird.
    Apple lieferte sie damit nicht aus, das Skript hielt die Bahn für frei,
    legte eine zweite an, und Apple lehnte den Eintrag ab, weil die Fassung
    schon in der ersten hing. Die Meldung sprach dann von der Fassung und nicht
    von der Einreichung — der Grund stand eine Ebene daneben.

    > Nie nach einem Feld sortieren, das bei den gesuchten Datensätzen leer
    > ist. Der Filter versteckt dann genau das, wonach gesucht wird.
    """
    stand, antwort = apple.holen("v1/reviewSubmissions", **{
        "filter[app]": app_id, "limit": 50})
    return antwort.json().get("data", []) if stand == 200 else []


def laufende(apple: Apple, app_id: str):
    """Eine Einreichung, die schon abgeschickt ist — oder None."""
    for eintrag in alle(apple, app_id):
        if feld(eintrag, "state") in UNTERWEGS:
            return eintrag
    return None


def vorbereitete(apple: Apple, app_id: str):
    """Die vorbereitete Einreichung mit den **meisten** Einträgen — oder None.

    `READY_FOR_REVIEW` heißt **nicht** „bei der Prüfung", sondern „bereit zum
    Abschicken". Eine solche wiederzuverwenden ist der richtige Weg: Die
    Fassung darf nur in einer Einreichung hängen.

    **Und es zählt, welche.** Der erste Anlauf nahm die erstbeste — das war
    eine leere aus einem eigenen Fehlschlag, während daneben eine mit fünf
    Einträgen stand, die alles enthielt. Zwei Läufe sind daran gescheitert.
    Genommen wird deshalb die mit den meisten Einträgen: Eine leere ist ein
    Überbleibsel, eine gefüllte ist die Arbeit.
    """
    kandidaten = []
    for eintrag in alle(apple, app_id):
        if feld(eintrag, "state") != "READY_FOR_REVIEW":
            continue
        stand, teile = apple.holen(f"v1/reviewSubmissions/{eintrag['id']}/items",
                                   **{"limit": 20})
        anzahl = len(teile.json().get("data", [])) if stand == 200 else 0
        kandidaten.append((anzahl, eintrag))
    if not kandidaten:
        return None
    kandidaten.sort(key=lambda x: x[0], reverse=True)
    return kandidaten[0][1]


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

    # **Eine vorbereitete wiederverwenden statt eine zweite anzulegen.** Die
    # Fassung darf nur in einer Einreichung hängen; eine zweite anzulegen
    # führte genau zu dem 409, der nach einem Problem mit der Fassung aussah.
    vorbereitet = vorbereitete(apple, app_id)
    if vorbereitet is not None:
        einreichung = vorbereitet["id"]
        neu_angelegt = False
        print(f"  ✓ Vorbereitete Einreichung gefunden ({einreichung[:8]})")
    else:
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
        neu_angelegt = True
        print(f"  ✓ Einreichung angelegt ({einreichung[:8]})")

    # **„Hat Einträge" heißt nicht „hat die Fassung".** Genau das hat der
    # vorige Lauf geschlossen und ist damit abgestürzt: Die gefundene
    # Einreichung führte fünf Einträge — die fünf Käufe — und keine Fassung.
    # Apple sagte es dann deutlich:
    #
    #     must have an approved appStoreVersions for platform IOS, or an
    #     appStoreVersions must be included in this review submission
    #
    # Gezählt wird also nicht, sondern nachgesehen, **was** darin liegt.
    stand, teile = apple.holen(f"v1/reviewSubmissions/{einreichung}/items",
                               **{"limit": 50})
    eintraege = teile.json().get("data", []) if stand == 200 else []
    mit_fassung = [e for e in eintraege
                   if (e.get("relationships", {}).get("appStoreVersion", {})
                        .get("data"))]
    print(f"  · Die Einreichung führt {len(eintraege)} Eintrag/Einträge, "
          f"davon {len(mit_fassung)} mit Fassung")
    if mit_fassung:
        return absenden(apple, einreichung)

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
        if neu_angelegt:
            weg = apple.loeschen(f"v1/reviewSubmissions/{einreichung}")
            print(f"  · leere Einreichung wieder entfernt (Antwort {weg})")
        return 1
    print("  ✓ Fassung 1.0 der Einreichung hinzugefügt")
    return absenden(apple, einreichung)


def absenden(apple: Apple, einreichung: str) -> int:
    """Erst dieser Aufruf schickt los. Bis hierher liegt alles nur bereit."""
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


def aufraeumen(apple: Apple, app_id: str) -> int:
    """Löscht Einreichungen, die nie eine wurden.

    **Der Fehlschlag hinterlässt eine Leiche.** Eine angelegte Einreichung, der
    das Hinzufügen der Fassung misslungen ist, steht als `READY_FOR_REVIEW` da
    und hat nichts darin. Der nächste Lauf hält sie für eine laufende
    Einreichung und tut nichts — die Sperre gegen ein Versehen wird dann selbst
    zur Sperre.

    Erkannt wird sie daran, dass sie **keine Einträge** hat. Eine echte
    Einreichung hat immer mindestens einen.
    """
    stand, antwort = apple.holen("v1/reviewSubmissions", **{
        "filter[app]": app_id, "limit": 50})
    if stand != 200:
        print(f"::error::Die Einreichungen sind nicht lesbar ({stand}).")
        return 1

    weg = 0
    for eintrag in antwort.json().get("data", []):
        if feld(eintrag, "state") not in ("READY_FOR_REVIEW",):
            continue
        stand, teile = apple.holen(
            f"v1/reviewSubmissions/{eintrag['id']}/items", **{"limit": 5})
        anzahl = len(teile.json().get("data", [])) if stand == 200 else -1
        if anzahl != 0:
            print(f"  · {eintrag['id'][:8]}: {anzahl} Eintrag/Einträge — bleibt")
            continue
        code = apple.loeschen(f"v1/reviewSubmissions/{eintrag['id']}")
        # **Der Rückgabewert stand da und wurde nicht angesehen.** Der erste
        # Lauf meldete „leer, entfernt (Antwort 403)" und zählte mit — 403
        # heißt, dass nichts entfernt wurde. Ein Erfolgssatz mit dem
        # Fehlercode darin ist schlimmer als eine Fehlermeldung: Er liest sich
        # wie Erfolg und trägt den Widerspruch im eigenen Klammerzusatz.
        if code in (200, 204):
            print(f"  ✓ {eintrag['id'][:8]}: leer, entfernt")
            weg += 1
        else:
            print(f"  ✗ {eintrag['id'][:8]}: leer, ließ sich nicht entfernen "
                  f"(Antwort {code}) — bleibt stehen")

    print(f"::notice::{weg} leere Einreichung(en) entfernt.")
    return 0


def main() -> int:
    apple = Apple()
    app_id = app_finden(apple)
    fassung = fassung_finden(apple, app_id)

    if "--aufraeumen" in sys.argv:
        return aufraeumen(apple, app_id)

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
