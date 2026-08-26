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


def verfuegbar(apple: Apple, kauf_id: str, produkt_id: str, wo: list[dict]) -> None:
    stand, antwort = apple.holen(f"v2/inAppPurchases/{kauf_id}/iapAvailability")
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


def bild_vorbereiten(quelle: str, ziel: str) -> str | None:
    """Das Bildschirmfoto der Kaufseite auf Apples Mindestmaß bringen.

    **Gepolstert, nicht hochskaliert.** Der Simulator liefert 460 × 1000,
    Apple verlangt mindestens 640 × 920. Hochrechnen macht die Schrift
    unscharf; ein breiterer Rand lässt das Bild, wie es ist. Die Randfarbe
    kommt aus dem Bild selbst — sonst stünde ein heller Schirm in einem
    schwarzen Rahmen.
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

    breite, hoehe = bild.size
    ziel_breite, ziel_hoehe = max(breite, 640), max(hoehe, 920)
    if (ziel_breite, ziel_hoehe) != (breite, hoehe):
        grund = bild.getpixel((0, 0))
        leinwand = Image.new("RGB", (ziel_breite, ziel_hoehe), grund)
        leinwand.paste(bild, ((ziel_breite - breite) // 2,
                              (ziel_hoehe - hoehe) // 2))
        bild = leinwand
    bild.save(ziel, "JPEG", quality=92)
    print(f"Prüfbild: {breite}×{hoehe} → {bild.size[0]}×{bild.size[1]}")
    return ziel


def pruefbild(apple: Apple, kauf_id: str, pfad: str, produkt_id: str) -> None:
    """Das Bildschirmfoto, das Apple zu jedem Kauf sehen will.

    **Es ist das, was zwischen `MISSING_METADATA` und `READY_TO_SUBMIT`
    steht.** Ohne diesen Zustand liefert StoreKit den Kauf nicht aus — auch
    nicht in der Sandbox, auch nicht bei sonst vollständigen Angaben. Vom
    Gerät gemeldet: „ne kann nichts kaufen im TestFlight."

    Hochgeladen wird in drei Zügen, wie Apple es verlangt: Platz reservieren,
    Bytes an die genannte Adresse schicken, Vollzug melden. Die Prüfsumme im
    letzten Zug ist Apples Gegenprobe, dass unterwegs nichts verloren ging.
    """
    stand, antwort = apple.holen(
        f"v2/inAppPurchases/{kauf_id}/appStoreReviewScreenshot")
    if stand == 200 and antwort.json().get("data"):
        getan.append(f"{produkt_id}: Prüfbild stand schon")
        return

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
        offen.append(f"{produkt_id}: Prüfbild nicht angemeldet ({stand}) "
                     f"— {kurz(antwort)}")
        return

    inhalt = antwort.json().get("data", {})
    bild_id = inhalt.get("id")
    for zug in inhalt.get("attributes", {}).get("uploadOperations", []):
        teil = daten[zug["offset"]:zug["offset"] + zug["length"]]
        kopf = {k["name"]: k["value"] for k in zug.get("requestHeaders", [])}
        antwort = requests.request(zug["method"], zug["url"], headers=kopf,
                                   data=teil, timeout=120)
        if antwort.status_code >= 300:
            offen.append(f"{produkt_id}: Prüfbild nicht übertragen "
                         f"({antwort.status_code})")
            return

    stand, antwort = apple.aendern(
        f"v1/inAppPurchaseAppStoreReviewScreenshots/{bild_id}", {
            "data": {
                "type": "inAppPurchaseAppStoreReviewScreenshots",
                "id": bild_id,
                "attributes": {"uploaded": True,
                               "sourceFileChecksum": hashlib.md5(daten).hexdigest()},
            },
        })
    if stand in (200, 201):
        getan.append(f"{produkt_id}: Prüfbild hochgeladen")
        return
    offen.append(f"{produkt_id}: Prüfbild nicht bestätigt ({stand}) "
                 f"— {kurz(antwort)}")


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

    # Dasselbe Bild für alle fünf: Die Kaufseite zeigt sie gemeinsam, und
    # Apple will sehen, wo im Programm der Kauf vorkommt.
    quelle = os.environ.get("PULSE_KAUFBILD", "")
    bild = bild_vorbereiten(quelle, "/tmp/kaufseite.jpg") if quelle else None
    if not bild:
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
        if bild:
            pruefbild(apple, kauf_id, bild, produkt_id)

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

    melden()


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
                 "iapAvailability", "appStoreReviewScreenshot",
                 "promotedPurchase", "images", "content"):
        stand, antwort = apple.holen(f"v2/inAppPurchases/{kauf_id}/{name}")
        if stand != 200:
            print(f"      {name}: nicht lesbar ({stand})")
            continue
        inhalt = antwort.json().get("data")
        anzahl = len(inhalt) if isinstance(inhalt, list) else (1 if inhalt else 0)
        print(f"      {name}: {anzahl}")


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
