#!/usr/bin/env python3
"""Aufrufe und Ladungen aus App Store Connect — gelesen, nicht geschätzt.

**Das Wichtigste zuerst: Apple sammelt diese Zahlen erst, wenn man sie
anfordert.** Ein Bericht mit `accessType: ONGOING` fängt am Tag der Anforderung
an; was davor war, ist für ihn nicht vorhanden. Wer eine Woche wartet, hat eine
Woche verloren. Deshalb ist `--anfordern` der erste Aufruf, den es hier gibt,
und er läuft, sobald die App im Laden steht — nicht, wenn jemand die erste Zahl
sehen will.

Ein `ONE_TIME_SNAPSHOT` reicht bis zu 365 Tage zurück, ist aber ein eigener
Vorgang, der bei Apple erst erzeugt werden muss. Beide Wege stehen hier: Der
laufende Bericht ist der Dauerauftrag, der Schnappschuss holt Vergangenes nach.

Was die Zahlen bedeuten, in Apples Sprache:

  Impressions          Wie oft die App irgendwo im Store auftauchte —
                       Suchtreffer, Empfehlungen, Ranglisten
  Product Page Views   Wie oft jemand die Produktseite wirklich geöffnet hat
  Total Downloads      Ladungen insgesamt, einschließlich erneuter
  First-Time Downloads Erstinstallationen — die Zahl, die „neue Nutzer" meint

**Die Verzögerung ist echt und kein Fehler.** Apple stellt einen Tagesbericht
frühestens am Folgetag bereit, oft später. Am Tag der Veröffentlichung gibt es
nichts zu sehen, und das ist kein Grund, das Skript für kaputt zu halten —
deshalb sagt es in dem Fall ausdrücklich, dass **noch keine** Daten da sind, und
nicht „0 Ladungen". Eine Null ist eine Aussage; „noch nichts" ist eine andere.

Aufrufe:

    python3 scripts/asc-zahlen.py --anfordern    # einmalig, startet die Sammlung
    python3 scripts/asc-zahlen.py                # die neuesten Zahlen zeigen
    python3 scripts/asc-zahlen.py --rueckwirkend # zusätzlich Vergangenes anfordern
"""

import csv
import gzip
import io
import os
import sys
import time

import jwt
import requests

BASIS = "https://api.appstoreconnect.apple.com"
BUNDLE = "de.karjoth.pulsemeter"

# Die Berichte, die die beiden Fragen beantworten: „wie oft gesehen" und „wie
# oft geladen". Apple benennt sie nicht stabil — mal mit, mal ohne Zusatz
# „Standard" —, deshalb wird auf Teilzeichenketten geprüft und nicht auf
# Gleichheit. Was nicht dabei ist, wird trotzdem aufgezählt: Ein Bericht, den
# Apple neu dazustellt, soll sichtbar sein und nicht stillschweigend fehlen.
GESUCHT = {
    "Aufrufe": "app store discovery and engagement",
    "Ladungen": "app downloads",
}

# Spalten, die uns interessieren, in der Schreibweise der CSV. Auch hier wird
# unscharf verglichen: Apple wechselt zwischen „Impressions" und
# „Impressions Unique Device".
SPALTEN = ["impressions", "product page views", "total downloads",
           "first-time downloads", "redownloads", "counts"]


def token() -> str:
    jetzt = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": jetzt,
                       "exp": jetzt + 600, "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256",
                      headers={"kid": os.environ["ASC_KEY_ID"]})


class Apple:
    """Ein dünner Mantel um `requests`, der jede Antwort mitschreibt.

    Aus derselben Erfahrung wie in `asc-warum.py`: Ein Fehlschlag, der nur als
    leere Liste zurückkommt, wird später zu einer Aussage über die Welt. Hier
    steht jeder Statuscode im Protokoll.
    """

    def __init__(self) -> None:
        self.kopf = {"Authorization": f"Bearer {token()}"}

    def holen(self, pfad: str, **params):
        antwort = requests.get(f"{BASIS}/{pfad}", headers=self.kopf,
                               params=params or None, timeout=60)
        print(f"   {pfad}  →  {antwort.status_code}")
        if antwort.status_code != 200:
            print(f"   ✗ {antwort.text[:300]}")
            return None
        return antwort.json()

    def anlegen(self, pfad: str, koerper: dict):
        antwort = requests.post(f"{BASIS}/{pfad}", headers=self.kopf,
                                json=koerper, timeout=60)
        print(f"   POST {pfad}  →  {antwort.status_code}")
        if antwort.status_code not in (200, 201):
            print(f"   ✗ {antwort.text[:300]}")
            return None
        return antwort.json()


def app_finden(apple: Apple) -> str | None:
    daten = apple.holen("v1/apps", **{"filter[bundleId]": BUNDLE, "limit": 20})
    if not daten:
        return None
    for eintrag in daten.get("data", []):
        if eintrag["attributes"].get("bundleId") == BUNDLE:
            return eintrag["id"]
    print(f"   ✗ Kein App-Eintrag zu {BUNDLE}")
    return None


def anfragen(apple: Apple, app_id: str) -> list[dict]:
    daten = apple.holen(f"v1/apps/{app_id}/analyticsReportRequests", limit=50)
    return daten.get("data", []) if daten else []


def anfordern(apple: Apple, app_id: str, art: str) -> bool:
    """Legt eine Berichtsanforderung an — und nur, wenn es sie nicht gibt.

    Zweimal dieselbe Anforderung wäre kein Schaden, aber auch kein Nutzen;
    schlimmer ist der umgekehrte Fall, in dem eine vorhandene übersehen und
    die Sammlung für neu gehalten wird.
    """
    vorhanden = [a for a in anfragen(apple, app_id)
                 if a["attributes"].get("accessType") == art
                 and not a["attributes"].get("stoppedDueToInactivity")]
    if vorhanden:
        print(f"   Es gibt schon eine Anforderung ({art}) — nichts zu tun.")
        return True

    ergebnis = apple.anlegen("v1/analyticsReportRequests", {
        "data": {
            "type": "analyticsReportRequests",
            "attributes": {"accessType": art},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    })
    if ergebnis:
        print(f"   ✓ Anforderung angelegt ({art}). Apple fängt jetzt an zu "
              f"sammeln; die ersten Zahlen kommen frühestens morgen.")
        return True
    return False


def segment_lesen(url: str) -> list[dict]:
    """Holt ein Segment und packt es aus.

    Die Adresse ist bereits unterschrieben — der eigene `Authorization`-Kopf
    gehört **nicht** daran, sonst antwortet der Ablageort mit 400.
    """
    antwort = requests.get(url, timeout=120)
    if antwort.status_code != 200:
        print(f"   ✗ Segment nicht ladbar ({antwort.status_code})")
        return []
    roh = antwort.content
    if roh[:2] == b"\x1f\x8b":
        roh = gzip.decompress(roh)
    text = roh.decode("utf-8", errors="replace")
    # Apple liefert Tabulatoren, nicht Kommas — trotz der Endung `.csv`.
    trenner = "\t" if "\t" in text.split("\n")[0] else ","
    return list(csv.DictReader(io.StringIO(text), delimiter=trenner))


def zusammenfassen(zeilen: list[dict]) -> dict[str, int]:
    """Zählt die Spalten zusammen, die eine Menge beschreiben.

    Nicht jede Zahl in so einem Bericht ist eine Summe — es stehen auch Datum,
    Gerät und Land darin. Summiert wird deshalb nur, was namentlich als Menge
    erkannt ist, und alles andere bleibt liegen.
    """
    summen: dict[str, int] = {}
    for zeile in zeilen:
        for spalte, wert in zeile.items():
            if not spalte:
                continue
            if not any(s in spalte.lower() for s in SPALTEN):
                continue
            try:
                summen[spalte] = summen.get(spalte, 0) + int(float(wert))
            except (TypeError, ValueError):
                continue
    return summen


def berichte_zeigen(apple: Apple, anfrage_id: str) -> bool:
    """Gibt die neuesten Tageszahlen aus. Rückgabe: ob etwas dastand."""
    daten = apple.holen(f"v1/analyticsReportRequests/{anfrage_id}/reports",
                        limit=200)
    if not daten:
        return False

    berichte = daten.get("data", [])
    print(f"   {len(berichte)} Berichte verfügbar")

    etwas_gefunden = False
    for bericht in berichte:
        name = bericht["attributes"].get("name", "")
        passt = [k for k, teil in GESUCHT.items() if teil in name.lower()]
        if not passt:
            continue

        instanzen = apple.holen(f"v1/analyticsReports/{bericht['id']}/instances",
                                **{"filter[granularity]": "DAILY", "limit": 10})
        eintraege = sorted(
            (instanzen or {}).get("data", []),
            key=lambda e: e["attributes"].get("processingDate", ""),
            reverse=True)
        if not eintraege:
            print(f"\n── {passt[0]} ({name})")
            print("   Noch keine Tagesdaten. Apple stellt sie frühestens am "
                  "Folgetag bereit.")
            continue

        neueste = eintraege[0]
        tag = neueste["attributes"].get("processingDate", "?")
        segmente = apple.holen(
            f"v1/analyticsReportInstances/{neueste['id']}/segments", limit=10)

        zeilen: list[dict] = []
        for segment in (segmente or {}).get("data", []):
            url = segment["attributes"].get("url")
            if url:
                zeilen.extend(segment_lesen(url))

        print(f"\n── {passt[0]} — {name}, Stand {tag}")
        if not zeilen:
            print("   Der Bericht ist da, aber leer.")
            continue
        summen = zusammenfassen(zeilen)
        if not summen:
            print(f"   {len(zeilen)} Zeilen, aber keine Mengenspalte erkannt. "
                  f"Spalten: {', '.join(list(zeilen[0])[:12])}")
            continue
        for spalte, wert in sorted(summen.items(), key=lambda p: -p[1]):
            print(f"   {spalte:38} {wert:>8}")
        etwas_gefunden = True

    return etwas_gefunden


def main() -> int:
    fehlend = [n for n in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_P8")
               if not os.environ.get(n)]
    if fehlend:
        print(f"Es fehlen: {', '.join(fehlend)}. "
              f"Dieses Skript läuft nur im Ablauf, nicht auf dem Rechner.")
        return 1

    apple = Apple()
    print("── Die App")
    app_id = app_finden(apple)
    if not app_id:
        return 1

    print("\n── Was schon angefordert ist")
    bestehend = anfragen(apple, app_id)
    for anfrage in bestehend:
        merkmale = anfrage["attributes"]
        gestoppt = merkmale.get("stoppedDueToInactivity")
        print(f"   · {merkmale.get('accessType')}"
              f"{' — GESTOPPT (zu lange nicht abgerufen)' if gestoppt else ''}")
    if not bestehend:
        print("   keine")

    if "--anfordern" in sys.argv or not bestehend:
        print("\n── Laufenden Bericht anfordern")
        anfordern(apple, app_id, "ONGOING")
    if "--rueckwirkend" in sys.argv:
        print("\n── Rückwirkenden Bericht anfordern")
        anfordern(apple, app_id, "ONE_TIME_SNAPSHOT")

    etwas = False
    for anfrage in anfragen(apple, app_id):
        art = anfrage["attributes"].get("accessType")
        print(f"\n── Zahlen aus der Anforderung {art}")
        if berichte_zeigen(apple, anfrage["id"]):
            etwas = True

    if not etwas:
        print("\nNoch keine Zahlen. Das ist erwartbar, solange der Bericht "
              "jünger als ein Tag ist — Apple stellt Tagesdaten frühestens am "
              "Folgetag bereit. Kein Grund, hier etwas zu reparieren.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
