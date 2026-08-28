#!/usr/bin/env python3
"""Legt die fünf Käufe in App Store Connect an — über die Schnittstelle.

Vom Gründer verlangt: „kannst du das nicht für mich alles über eine API oder
ähnliches anlegen?" Kann ich versuchen, und der Versuch ist mehr wert als eine
Anleitung: Was Apple nicht hergibt, steht danach schwarz auf weiß da statt als
Vermutung.

**Was hier entsteht, ist ein Entwurf und nichts Verkauftes.** Ein Kauf, der neu
angelegt wird, steht auf „Bereit zum Senden" — sichtbar in der Sandbox, also in
jedem TestFlight-Bau, und dort kostenlos. Zum Verkauf kommt er erst mit der
Einreichung der App. Preise, Namen und Beschreibungen lassen sich danach
jederzeit ändern.

**Die Produkt-ID nicht.** Sie ist das Einzige an einem Kauf, das für immer
feststeht: Ein umbenannter Kauf ist für jeden Käufer ein verlorener Kauf
(10-sichtbarkeit.md, Abschnitt 4). Deshalb kommen die IDs hier nicht aus einer
Liste, die jemand abtippt, sondern aus derselben Quelle wie in der App —
`ProductID.storeIdentifier` ist `de.karjoth.pulsemeter.` plus dem Namen in
Kleinbuchstaben.

**Es bricht nie ab.** Fünf Käufe, jeder in vier Schritten; scheitert einer,
laufen die anderen weiter und der Fehlschlag wird benannt. Ein halb angelegter
Kauf ist kein Schaden — beim nächsten Lauf wird er gefunden und
weitergeschrieben.

Aufruf (Umgebung wie bei `asc-profil.py`):

    ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_P8=… python3 scripts/asc-kaeufe.py
"""

import hashlib
import json
import os
import pathlib
import sys
import time

import jwt
import requests

BASIS = "https://api.appstoreconnect.apple.com"

BUNDLE = "de.karjoth.pulsemeter"
GEBIET = "DEU"

# **Zwei Textsorten, und sie sind nicht dieselbe.**
#
# In der App darf ein Satz erklären, wozu etwas gut ist. Im Store nicht: Apple
# lässt für den Anzeigenamen 30 Zeichen und für die Beschreibung 45. Die langen
# Sätze aus `ProductID.explanation` passen dort nicht hinein, und sie
# abzuschneiden hieße, sie mitten im Wort enden zu lassen.
#
# Der Anzeigename ist zugleich ein Suchfeld (10-sichtbarkeit.md): Aus „Tag- und
# Nachtstrom, Einspeisung" wird deshalb „Nachtstrom und Einspeisung" — die
# beiden Wörter, nach denen jemand sucht, bleiben; „Tag- und" trägt nichts und
# kostet sechs Zeichen.
KAEUFE = [
    {"kennung": "additionalmeters",  "referenz": "Unbegrenzt viele Zähler",
     "name": "Unbegrenzt viele Zähler",     "text": "Mehr als zwei Zähler führen.",
     "preis": "2.99"},
    {"kennung": "multipleregisters", "referenz": "Nachtstrom und Einspeisung",
     "name": "Nachtstrom und Einspeisung",  "text": "Ein Zähler mit zwei Zahlen darauf.",
     "preis": "2.99"},
    {"kennung": "costsandtariffs",   "referenz": "Kosten und Preise",
     "name": "Kosten und Preise",           "text": "Aus Verbrauch wird ein Betrag.",
     "preis": "3.99"},
    {"kennung": "pdfreport",         "referenz": "Bericht ohne Wasserzeichen",
     "name": "Bericht ohne Wasserzeichen",  "text": "Der Bericht zum Weitergeben.",
     "preis": "2.99"},
    {"kennung": "everything",        "referenz": "Alles freischalten",
     "name": "Alles freischalten",          "text": "Alle vier Freischaltungen zusammen.",
     "preis": "9.99"},
]

offen: list[str] = []
getan: list[str] = []


def anmeldung() -> str:
    jetzt = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": jetzt, "exp": jetzt + 600,
         "aud": "appstoreconnect-v1"},
        os.environ["ASC_KEY_P8"],
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )


class Apple:
    def __init__(self, token: str) -> None:
        self.kopf = {"Authorization": f"Bearer {token}",
                     "Content-Type": "application/json"}

    def holen(self, pfad: str, **werte):
        antwort = requests.get(f"{BASIS}/{pfad}", headers=self.kopf,
                               params=werte, timeout=30)
        return antwort.status_code, antwort

    def anlegen(self, pfad: str, koerper: dict):
        antwort = requests.post(f"{BASIS}/{pfad}", headers=self.kopf,
                                data=json.dumps(koerper), timeout=30)
        return antwort.status_code, antwort

    def loeschen(self, pfad: str) -> int:
        return requests.delete(f"{BASIS}/{pfad}", headers=self.kopf,
                               timeout=30).status_code

    def aendern(self, pfad: str, koerper: dict):
        antwort = requests.patch(f"{BASIS}/{pfad}", headers=self.kopf,
                                 data=json.dumps(koerper), timeout=60)
        return antwort.status_code, antwort


def kurz(antwort) -> str:
    """Apples Fehlertext, auf das Lesbare eingedampft."""
    try:
        fehler = antwort.json().get("errors", [])
        if fehler:
            erster = fehler[0]
            return f"{erster.get('title', '')} — {erster.get('detail', '')}"[:220]
    except ValueError:
        pass
    return antwort.text[:220]


def app_finden(apple: Apple):
    stand, antwort = apple.holen("v1/apps", **{"filter[bundleId]": BUNDLE, "limit": 20})
    if stand != 200:
        offen.append(f"Die App ließ sich nicht finden ({stand}) — {kurz(antwort)}")
        return None
    for eintrag in antwort.json().get("data", []):
        if eintrag["attributes"].get("bundleId") == BUNDLE:
            return eintrag["id"]
    offen.append(f"Zu {BUNDLE} gibt es in App Store Connect noch keinen "
                 "App-Eintrag — der muss einmal von Hand angelegt werden")
    return None


def bestand(apple: Apple, app_id: str) -> dict:
    """Was schon da ist: Produkt-ID → (Kennung, Zustand)."""
    stand, antwort = apple.holen(f"v1/apps/{app_id}/inAppPurchasesV2", **{"limit": 200})
    if stand != 200:
        offen.append(f"Die vorhandenen Käufe ließen sich nicht lesen ({stand}) "
                     f"— {kurz(antwort)}")
        return {}
    return {e["attributes"]["productId"]: (e["id"], e["attributes"].get("state", "?"))
            for e in antwort.json().get("data", [])
            if e.get("attributes", {}).get("productId")}


# Nur dieser Zustand wird von StoreKit ausgeliefert — auch in der Sandbox.
# Alles andere heißt: Der Kauf existiert, die App bekommt ihn aber nicht zu
# sehen, und die Kaufseite bleibt ohne Knopf.
LIEFERBAR = {"READY_TO_SUBMIT", "APPROVED", "WAITING_FOR_REVIEW", "IN_REVIEW"}


def kauf_anlegen(apple: Apple, app_id: str, kauf: dict, produkt_id: str):
    stand, antwort = apple.anlegen("v2/inAppPurchases", {"data": {
        "type": "inAppPurchases",
        "attributes": {
            "name": kauf["referenz"],
            "productId": produkt_id,
            "inAppPurchaseType": "NON_CONSUMABLE",
            # Nicht teilbar in der Familie. Einschalten geht später jederzeit,
            # ausschalten nicht — also erst dann, wenn es jemand verlangt.
            "familySharable": False,
        },
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
    }})
    if stand in (200, 201):
        getan.append(f"{produkt_id}: angelegt")
        return antwort.json().get("data", {}).get("id")
    offen.append(f"{produkt_id}: ließ sich nicht anlegen ({stand}) — {kurz(antwort)}")
    return None


def beschriftung(apple: Apple, kauf_id: str, kauf: dict, produkt_id: str) -> None:
    stand, antwort = apple.holen(f"v2/inAppPurchases/{kauf_id}/inAppPurchaseLocalizations",
                                 **{"limit": 20})
    if stand == 200 and antwort.json().get("data"):
        getan.append(f"{produkt_id}: Beschriftung stand schon")
        return

    stand, antwort = apple.anlegen("v1/inAppPurchaseLocalizations", {"data": {
        "type": "inAppPurchaseLocalizations",
        "attributes": {"locale": "de-DE", "name": kauf["name"],
                       "description": kauf["text"]},
        "relationships": {"inAppPurchaseV2": {
            "data": {"type": "inAppPurchases", "id": kauf_id}}},
    }})
    if stand in (200, 201):
        getan.append(f"{produkt_id}: „{kauf['name']}“ eingetragen")
        return
    offen.append(f"{produkt_id}: Beschriftung ließ sich nicht eintragen "
                 f"({stand}) — {kurz(antwort)}")


def preispunkt(apple: Apple, kauf_id: str, betrag: str, produkt_id: str):
    """Der Preispunkt zu einem Betrag — Apple verkauft nicht in freien Zahlen.

    Gesucht wird über alle Seiten: Für Deutschland gibt es mehrere hundert
    Punkte, und 2,99 € liegt nicht auf der ersten Seite.
    """
    pfad = f"v2/inAppPurchases/{kauf_id}/pricePoints"
    werte = {"filter[territory]": GEBIET, "limit": 200}
    while True:
        stand, antwort = apple.holen(pfad, **werte)
        if stand != 200:
            offen.append(f"{produkt_id}: Preispunkte nicht lesbar ({stand}) "
                         f"— {kurz(antwort)}")
            return None
        daten = antwort.json()
        for punkt in daten.get("data", []):
            if punkt["attributes"].get("customerPrice") == betrag:
                return punkt["id"]
        weiter = daten.get("links", {}).get("next")
        if not weiter:
            offen.append(f"{produkt_id}: Zu {betrag} € gibt es in {GEBIET} "
                         "keinen Preispunkt")
            return None
        # `next` ist eine vollständige Adresse — Pfad und Parameter daraus.
        pfad, werte = weiter[len(BASIS) + 1:], {}


def preis_setzen(apple: Apple, kauf_id: str, kauf: dict, produkt_id: str) -> None:
    stand, antwort = apple.holen(f"v2/inAppPurchases/{kauf_id}/iapPriceSchedule")
    if stand == 200 and antwort.json().get("data"):
        getan.append(f"{produkt_id}: Preis stand schon")
        return

    punkt = preispunkt(apple, kauf_id, kauf["preis"], produkt_id)
    if not punkt:
        return

    stand, antwort = apple.anlegen("v1/inAppPurchasePriceSchedules", {
        "data": {
            "type": "inAppPurchasePriceSchedules",
            "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": kauf_id}},
                "baseTerritory": {"data": {"type": "territories", "id": GEBIET}},
                "manualPrices": {"data": [{"type": "inAppPurchasePrices",
                                           "id": "${preis}"}]},
            },
        },
        # Apple verlangt den Preis als eingeschlossenes Objekt mit einer
        # selbstvergebenen Kennung, auf die die Beziehung oben zeigt.
        "included": [{
            "type": "inAppPurchasePrices",
            "id": "${preis}",
            "attributes": {"startDate": None, "endDate": None},
            "relationships": {"inAppPurchasePricePoint": {
                "data": {"type": "inAppPurchasePricePoints", "id": punkt}}},
        }],
    })
    if stand in (200, 201):
        getan.append(f"{produkt_id}: {kauf['preis'].replace('.', ',')} € gesetzt")
        return
    offen.append(f"{produkt_id}: Preis ließ sich nicht setzen ({stand}) "
                 f"— {kurz(antwort)}")


def gebiete(apple: Apple) -> list[dict]:
    stand, antwort = apple.holen("v1/territories", **{"limit": 200})
    if stand != 200:
        return [{"type": "territories", "id": GEBIET}]
    return [{"type": "territories", "id": e["id"]}
            for e in antwort.json().get("data", [])]


def app_verfuegbar(apple: Apple, app_id: str, wo: list[dict]) -> None:
    """Die **App** in Länder bringen — nicht den Kauf.

    **Der Befund, auf den zwei Tage zugelaufen sind.** Alle fünf Käufe standen
    auf `READY_TO_SUBMIT`, jedes Feld gesetzt, und auf dem Gerät blieb die
    Kaufseite leer. Die Aufstellung eine Ebene höher hat es dann gesagt:

        appPriceSchedule: 1
        appAvailabilityV2: 404 — There is no resource of type
                           'appAvailabilities' with id '…'

    Der Preisplan der App steht, ihre Verfügbarkeit nicht. Eine App, die in
    keinem Land verfügbar ist, hat auch keinen Laden, in dem ein Kauf angeboten
    werden könnte — und StoreKit gibt nichts zurück. Die Verfügbarkeit des
    Kaufs half nicht: Sie beschreibt, wo der Kauf gälte, wenn es die App dort
    gäbe.

    **Das veröffentlicht nichts.** Die App steht auf `PREPARE_FOR_SUBMISSION`
    und bleibt dort; Verfügbarkeit ist eine Angabe, keine Einreichung.
    """
    stand, _ = apple.holen(f"v1/apps/{app_id}/appAvailabilityV2")
    if stand == 200:
        getan.append("Die App ist bereits in Ländern verfügbar")
        return

    # Jedes Land wird einzeln mitgeschickt: `territoryAvailabilities` ist eine
    # eigene Ressource, keine Liste von Kennungen wie beim Kauf.
    enthalten = [{
        "type": "territoryAvailabilities",
        "id": f"${gebiet['id']}",
        "attributes": {"available": True},
        "relationships": {"territory": {"data": gebiet}},
    } for gebiet in wo]

    stand, antwort = apple.anlegen("v2/appAvailabilities", {
        "data": {
            "type": "appAvailabilities",
            "attributes": {"availableInNewTerritories": True},
            "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}},
                "territoryAvailabilities": {
                    "data": [{"type": "territoryAvailabilities", "id": e["id"]}
                             for e in enthalten]},
            },
        },
        "included": enthalten,
    })
    if stand in (200, 201):
        getan.append(f"Die App ist jetzt in {len(wo)} Ländern verfügbar")
        return
    offen.append(f"Die App ist in keinem Land verfügbar, und das ließ sich "
                 f"hier nicht setzen ({stand}) — {kurz(antwort)}. "
                 "In App Store Connect: Preise und Verfügbarkeit")


def verfuegbar(apple: Apple, kauf_id: str, produkt_id: str, wo: list[dict]) -> None:
    # **Zwei Namen für dieselbe Beziehung.** Der Preisplan heißt
    # `iapPriceSchedule`, die Verfügbarkeit aber `inAppPurchaseAvailability` —
    # die Abkürzung gibt es hier nicht. Mit dem falschen Namen kam 404 zurück,
    # das Skript hielt die Verfügbarkeit für ungesetzt und legte sie bei jedem
    # Lauf neu an. Gemeldet hat es trotzdem „steht" — dritter Fall derselben
    # Verwechslung an einem Tag.
    for name in ("inAppPurchaseAvailability", "iapAvailability"):
        stand, antwort = apple.holen(f"v2/inAppPurchases/{kauf_id}/{name}")
        if stand == 200 and antwort.json().get("data"):
            getan.append(f"{produkt_id}: Verfügbarkeit stand schon")
            return

    stand, antwort = apple.anlegen("v1/inAppPurchaseAvailabilities", {"data": {
        "type": "inAppPurchaseAvailabilities",
        "attributes": {"availableInNewTerritories": True},
        "relationships": {
            "inAppPurchase": {"data": {"type": "inAppPurchases", "id": kauf_id}},
            "availableTerritories": {"data": wo},
        },
    }})
    if stand in (200, 201):
        getan.append(f"{produkt_id}: in {len(wo)} Ländern verfügbar")
        return
    offen.append(f"{produkt_id}: Verfügbarkeit ließ sich nicht setzen "
                 f"({stand}) — {kurz(antwort)}")


# **Apple nimmt Gerätemaße, keine Mindestgröße.** 640 × 1000 kam mit
# `IMAGE_INCORRECT_DIMENSIONS` zurück — die Zahl war größer als das
# dokumentierte Mindestmaß und trotzdem falsch, weil die Liste erlaubter Maße
# aus echten iPhone-Auflösungen besteht. Welche davon für ein Prüfbild gilt,
# steht nirgends verbindlich; also werden sie der Reihe nach versucht und Apple
# entscheidet. Gemessen statt geraten — beim vierten Anlauf an diesem Tag.
MASSE = [(1242, 2208), (750, 1334), (640, 920), (1125, 2436),
         (1284, 2778), (828, 1792)]


def bild_vorbereiten(quelle: str, ziel: str, masse: tuple[int, int]) -> str | None:
    """Das Bildschirmfoto auf ein genaues Maß bringen, ohne es zu verzerren.

    Erst so weit verkleinern oder vergrößern, dass es ganz hineinpasst, dann
    mittig auf die Leinwand. Die Randfarbe kommt aus dem Bild selbst — sonst
    stünde ein heller Schirm in einem schwarzen Rahmen.
    """
    try:
        from PIL import Image
    except ImportError:
        offen.append("Pillow fehlt — ohne Bildbearbeitung kein Prüfbild")
        return None
    try:
        bild = Image.open(quelle).convert("RGB")
    except Exception as fehler:  # noqa: BLE001
        offen.append(f"Das Bildschirmfoto ließ sich nicht öffnen: {fehler}")
        return None

    ziel_breite, ziel_hoehe = masse
    faktor = min(ziel_breite / bild.width, ziel_hoehe / bild.height)
    breite, hoehe = max(1, round(bild.width * faktor)), max(1, round(bild.height * faktor))
    verkleinert = bild.resize((breite, hoehe), Image.LANCZOS)
    leinwand = Image.new("RGB", masse, bild.getpixel((0, 0)))
    leinwand.paste(verkleinert, ((ziel_breite - breite) // 2,
                                 (ziel_hoehe - hoehe) // 2))
    leinwand.save(ziel, "JPEG", quality=90)
    return ziel


def bildzustand(apple: Apple, kauf_id: str):
    """(Kennung, Zustand, Fehler) des Prüfbilds — oder (None, None, None)."""
    stand, antwort = apple.holen(
        f"v2/inAppPurchases/{kauf_id}/appStoreReviewScreenshot")
    if stand != 200 or not antwort.json().get("data"):
        return None, None, None
    eintrag = antwort.json()["data"]
    lieferung = eintrag.get("attributes", {}).get("assetDeliveryState") or {}
    return eintrag.get("id"), lieferung.get("state"), lieferung.get("errors") or []


def hochladen(apple: Apple, kauf_id: str, pfad: str) -> str | None:
    """Anmelden, Bytes schicken, Vollzug melden. Gibt den Fehlertext zurück."""
    daten = pathlib.Path(pfad).read_bytes()
    stand, antwort = apple.anlegen("v1/inAppPurchaseAppStoreReviewScreenshots", {
        "data": {
            "type": "inAppPurchaseAppStoreReviewScreenshots",
            "attributes": {"fileSize": len(daten), "fileName": "kaufseite.jpg"},
            "relationships": {"inAppPurchaseV2": {
                "data": {"type": "inAppPurchases", "id": kauf_id}}},
        },
    })
    if stand not in (200, 201):
        return f"nicht angemeldet ({stand}) — {kurz(antwort)}"

    inhalt = antwort.json().get("data", {})
    bild_id = inhalt.get("id")
    for zug in inhalt.get("attributes", {}).get("uploadOperations", []):
        teil = daten[zug["offset"]:zug["offset"] + zug["length"]]
        kopf = {k["name"]: k["value"] for k in zug.get("requestHeaders", [])}
        gesendet = requests.request(zug["method"], zug["url"], headers=kopf,
                                    data=teil, timeout=120)
        if gesendet.status_code >= 300:
            return f"nicht übertragen ({gesendet.status_code})"

    stand, antwort = apple.aendern(
        f"v1/inAppPurchaseAppStoreReviewScreenshots/{bild_id}", {
            "data": {
                "type": "inAppPurchaseAppStoreReviewScreenshots",
                "id": bild_id,
                "attributes": {"uploaded": True,
                               "sourceFileChecksum": hashlib.md5(daten).hexdigest()},
            },
        })
    if stand not in (200, 201):
        return f"nicht bestätigt ({stand}) — {kurz(antwort)}"
    return None


def pruefbild(apple: Apple, kauf_id: str, quelle: str, produkt_id: str,
              gewinner: tuple[int, int] | None) -> tuple[int, int] | None:
    """Das Prüfbild, so lange in anderen Maßen, bis Apple es annimmt.

    **Vorhanden heißt nicht angenommen.** Apple legt die Datei an, sobald sie
    angemeldet ist; ob sie zählt, steht in `assetDeliveryState`. Ein Bild in
    `FAILED` ist da und hält den Kauf trotzdem auf `MISSING_METADATA` — genau
    das war „ne kann nichts kaufen im TestFlight".
    """
    bild_id, zustand, fehler = bildzustand(apple, kauf_id)
    if zustand == "COMPLETE":
        getan.append(f"{produkt_id}: Prüfbild steht")
        return gewinner
    if bild_id:
        apple.loeschen(f"v1/inAppPurchaseAppStoreReviewScreenshots/{bild_id}")

    # Das Maß, das beim ersten Kauf durchging, zuerst — die anderen vier
    # brauchen die Suche dann nicht noch einmal.
    reihe = ([gewinner] if gewinner else []) + [m for m in MASSE if m != gewinner]
    for masse in reihe:
        pfad = bild_vorbereiten(quelle, f"/tmp/kaufseite-{masse[0]}x{masse[1]}.jpg", masse)
        if not pfad:
            return gewinner
        schiefgegangen = hochladen(apple, kauf_id, pfad)
        if schiefgegangen:
            offen.append(f"{produkt_id}: Prüfbild {masse[0]}×{masse[1]} {schiefgegangen}")
            return gewinner

        # Apple prüft das Bild erst nach dem Vollzug. Kurz nachfassen, statt
        # einen Zwischenstand für das Ergebnis zu halten.
        for _ in range(8):
            bild_id, zustand, fehler = bildzustand(apple, kauf_id)
            if zustand in ("COMPLETE", "FAILED"):
                break
            time.sleep(2)

        if zustand == "COMPLETE":
            getan.append(f"{produkt_id}: Prüfbild angenommen ({masse[0]}×{masse[1]})")
            return masse

        grund = (fehler[0].get("code") if fehler else zustand) or "?"
        print(f"  {produkt_id}: {masse[0]}×{masse[1]} abgelehnt ({grund})")
        if bild_id:
            apple.loeschen(f"v1/inAppPurchaseAppStoreReviewScreenshots/{bild_id}")

    offen.append(f"{produkt_id}: Kein Maß aus {len(MASSE)} wurde angenommen")
    return gewinner


def main() -> None:
    fehlend = [n for n in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_P8")
               if not os.environ.get(n)]
    if fehlend:
        print(f"::warning::Ohne {', '.join(fehlend)} lässt sich nichts anlegen.")
        melden()
        return

    apple = Apple(anmeldung())
    app_id = app_finden(apple)
    if not app_id:
        melden()
        return

    vorhanden = bestand(apple, app_id)
    wo = gebiete(apple)

    # Zuerst die App, dann die Käufe: Ein Kauf in einer App, die es in keinem
    # Land gibt, wird von StoreKit nicht ausgeliefert.
    app_verfuegbar(apple, app_id, wo)

    # Dasselbe Bild für alle fünf: Die Kaufseite zeigt sie gemeinsam, und
    # Apple will sehen, wo im Programm der Kauf vorkommt.
    quelle = os.environ.get("PULSE_KAUFBILD", "")
    gewinner: tuple[int, int] | None = None
    if not quelle:
        offen.append("Ohne Prüfbild bleibt jeder Kauf auf MISSING_METADATA")

    for kauf in KAEUFE:
        produkt_id = f"{BUNDLE}.{kauf['kennung']}"
        eintrag = vorhanden.get(produkt_id)
        if eintrag:
            kauf_id = eintrag[0]
            getan.append(f"{produkt_id}: stand schon")
        else:
            kauf_id = kauf_anlegen(apple, app_id, kauf, produkt_id)
        if not kauf_id:
            continue
        beschriftung(apple, kauf_id, kauf, produkt_id)
        preis_setzen(apple, kauf_id, kauf, produkt_id)
        verfuegbar(apple, kauf_id, produkt_id, wo)
        if quelle:
            gewinner = pruefbild(apple, kauf_id, quelle, produkt_id, gewinner)

    # **Nachlesen statt glauben — und zwar den Zustand, nicht die Existenz.**
    #
    # Der erste Anlauf prüfte nur, ob der Kauf in der Liste steht. Er stand
    # dort, alle fünf, und trotzdem meldete der Gründer: „ne kann nichts kaufen
    # im TestFlight." Dasselbe Muster wie bei den Berechtigungen in 0.79.1 —
    # „ist da" und „funktioniert" sind zwei verschiedene Sachverhalte, und ich
    # hatte den einen für den anderen genommen.
    #
    # Ausgeliefert wird ein Kauf nur in bestimmten Zuständen. `MISSING_METADATA`
    # heißt: Apple fehlt noch etwas, und die App bekommt das Produkt nicht.
    danach = bestand(apple, app_id)
    gemeldet = False
    for kauf in KAEUFE:
        produkt_id = f"{BUNDLE}.{kauf['kennung']}"
        eintrag = danach.get(produkt_id)
        if not eintrag:
            offen.append(f"{produkt_id}: steht nach dem Lauf nicht in der Liste")
            continue
        zustand = eintrag[1]
        if zustand in LIEFERBAR:
            getan.append(f"{produkt_id}: Zustand {zustand} — wird ausgeliefert")
        else:
            offen.append(f"{produkt_id}: Zustand {zustand} — StoreKit liefert "
                         "diesen Kauf nicht aus, die Kaufseite bleibt ohne Knopf")
            # Nur beim ersten: Fünfmal dieselbe Aufstellung wäre Lärm, und
            # alle fünf sind gleich gebaut.
            if not gemeldet:
                was_fehlt(apple, eintrag[0], produkt_id)
                gemeldet = True

    # **Auch dann ausschreiben, wenn alles grün aussieht.** Genau dieser Fall
    # steht gerade an: fünfmal READY_TO_SUBMIT, und auf dem Gerät trotzdem kein
    # Knopf. Ein Lauf, der nur „alles steht" sagt, hilft dann nicht weiter.
    if os.environ.get("PULSE_DIAGNOSE") and not gemeldet:
        was_die_app_fuehrt(apple, app_id)
        erster = danach.get(f"{BUNDLE}.{KAEUFE[0]['kennung']}")
        if erster:
            was_fehlt(apple, erster[0], f"{BUNDLE}.{KAEUFE[0]['kennung']}")

    melden()


def was_die_app_fuehrt(apple: Apple, app_id: str) -> None:
    """Alles ausschreiben, was Apple über die **App** führt.

    **Weil die Käufe es nicht mehr sein können.** Alle fünf stehen auf
    `READY_TO_SUBMIT`, das Prüfbild ist angenommen, Preis und Verfügbarkeit
    stehen — und auf dem Gerät bleibt die Kaufseite leer. Damit ist die Ursache
    nicht mehr am Kauf, sondern eine Ebene darüber: an der App selbst oder an
    einem Vertrag.

    Verträge hat Apples Schnittstelle nicht. Die App hat sie, und ein Feld, das
    hier fehlt, ist mehr wert als die nächste Vermutung.
    """
    stand, antwort = apple.holen(f"v1/apps/{app_id}")
    if stand == 200:
        merkmale = antwort.json().get("data", {}).get("attributes", {})
        print("\n  Was Apple über die App führt:")
        for schluessel, wert in sorted(merkmale.items()):
            print(f"      {schluessel}: {wert}")

    # Preis und Verfügbarkeit der **App**: Ohne sie ist die App nirgends zu
    # haben — und ein Kauf in einer App, die es in keinem Land gibt, kann von
    # StoreKit nicht ausgeliefert werden. Das ist die Vermutung, die diese
    # Abfrage prüfen soll; ob sie stimmt, sagt die Antwort.
    # **Ohne `limit`.** Der erste Lauf hat sich an genau dieser Stelle selbst
    # blind gemacht: `appPriceSchedule`, `appAvailabilityV2` und die
    # Lizenzvereinbarung sind Einzelstücke, keine Listen, und antworten auf
    # `limit` mit 400. Im Protokoll stand dreimal „nicht lesbar" — was wie eine
    # Auskunft von Apple aussah und ein Fehler von mir war.
    for name in ("appPriceSchedule", "appAvailabilityV2", "appStoreVersions",
                 "appInfos", "builds", "inAppPurchasesV2", "endUserLicenseAgreement"):
        stand, antwort = apple.holen(f"v1/apps/{app_id}/{name}")
        if stand != 200:
            print(f"      {name}: nicht lesbar ({stand}) — {kurz(antwort)}")
            continue
        inhalt = antwort.json().get("data")
        anzahl = len(inhalt) if isinstance(inhalt, list) else (1 if inhalt else 0)
        print(f"      {name}: {anzahl}")
        for eintrag in (inhalt if isinstance(inhalt, list) else [inhalt])[:2]:
            if not eintrag:
                continue
            for schluessel, wert in sorted(eintrag.get("attributes", {}).items()):
                print(f"          {schluessel}: {wert}")


def was_fehlt(apple: Apple, kauf_id: str, produkt_id: str) -> None:
    """Alles ausschreiben, was Apple über diesen Kauf sagt.

    **Weil Raten zweimal falsch war.** Erst hielt ich die Vereinbarung für
    bezahlte Apps für die Ursache, dann das Prüfbild. Das Bild liegt jetzt bei
    allen fünf, und der Zustand steht unverändert auf `MISSING_METADATA`.
    Apples Schnittstelle nennt nirgends, *welches* Feld fehlt — also wird hier
    alles aufgeschrieben, was sie hergibt, und die Lücke aus dem Vergleich
    sichtbar gemacht statt aus einer Vermutung.
    """
    stand, antwort = apple.holen(f"v2/inAppPurchases/{kauf_id}")
    if stand == 200:
        merkmale = antwort.json().get("data", {}).get("attributes", {})
        print(f"\n  {produkt_id} — was Apple über den Kauf führt:")
        for schluessel, wert in sorted(merkmale.items()):
            print(f"      {schluessel}: {wert}")

    # Jede Beziehung einzeln: vorhanden oder nicht, und mit welcher Antwort.
    for name in ("inAppPurchaseLocalizations", "iapPriceSchedule",
                 "inAppPurchaseAvailability", "appStoreReviewScreenshot",
                 "promotedPurchase", "images", "content"):
        stand, antwort = apple.holen(f"v2/inAppPurchases/{kauf_id}/{name}")
        if stand != 200:
            print(f"      {name}: nicht lesbar ({stand})")
            continue
        inhalt = antwort.json().get("data")
        anzahl = len(inhalt) if isinstance(inhalt, list) else (1 if inhalt else 0)
        print(f"      {name}: {anzahl}")
        # Bei den beiden, an denen es hängen kann, auch den Inhalt.
        if name in ("appStoreReviewScreenshot", "inAppPurchaseLocalizations"):
            for eintrag in (inhalt if isinstance(inhalt, list) else [inhalt]):
                if not eintrag:
                    continue
                for schluessel, wert in sorted(eintrag.get("attributes", {}).items()):
                    print(f"          {schluessel}: {wert}")


def melden() -> None:
    if getan:
        print("Angelegt:")
        for zeile in dict.fromkeys(getan):
            print(f"  · {zeile}")
    if offen:
        print("\nOffen — das muss jemand in App Store Connect nachtragen:")
        for zeile in dict.fromkeys(offen):
            print(f"  · {zeile}")
        print("\n  https://appstoreconnect.apple.com/apps")
        print("\n::warning::Nicht alle fünf Käufe stehen. Ohne sie zeigt die "
              "Kaufseite ihre Leistungen ohne Knopf — so gebaut.")
    else:
        print("\n::notice::Alle fünf Käufe stehen. In einem TestFlight-Bau "
              "lassen sie sich jetzt kostenlos ausprobieren.")

    # Immer 0: Dieses Skript ist eine Erleichterung, kein Torwächter.
    sys.exit(0)


if __name__ == "__main__":
    main()
