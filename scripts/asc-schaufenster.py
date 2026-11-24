#!/usr/bin/env python3
"""Das Ereignis „Winter-Check“ und die eigene Produktseite „Wärmepumpe“ bei Apple.

Hebel 4 aus dem Reichweiten-Konzept vom 11. November: der App Store als zweite
Suche. Ein **Ereignis** erscheint in der Suche und auf der Store-Seite, auch bei
Leuten, die die App nicht haben. Eine **eigene Produktseite** hat eigene Bilder
und eine eigene Adresse, auf die die Wärmepumpen-Seiten der Website zeigen.

Drei Arten, das Skript zu rufen:

    asc-schaufenster.py --pruefen     ohne Netz: Texte da, Längen in Apples
                                      Grenzen, Bilder (wenn gebaut) im Maß
    asc-schaufenster.py stand         fragt Apple, was liegt, und ändert nichts
    asc-schaufenster.py anlegen       legt beides als Entwurf an oder bringt den
                                      Entwurf auf den Stand des Repositorys
    asc-schaufenster.py einreichen    reicht beides zur Prüfung ein

**Ein Entwurf ist unsichtbar**, er lässt sich ändern und löschen. Sichtbar wird
erst, was eingereicht und freigegeben ist. Deshalb ist `anlegen` jederzeit
erlaubt und `einreichen` eine eigene Stufe, die der Ablauf nur mit einem
getippten Wort ausführt. Das Einreichen bleibt eine Freigabe des Gründers
(CLAUDE.md, Regel 4a).

**Die Texte stehen nicht hier**, sondern in `docs/09-appstore.md` unter „Wärmepumpe
im Laden“. Dort prüft `check-store-texte.py` sie wie jeden anderen Store-Text.
Hier stehen nur Werte, die keine Prosa sind: Zeitraum, Länder, Kennzeichnung.
"""

import importlib.util
import os
import pathlib
import re
import sys

import requests

WURZEL = pathlib.Path(__file__).resolve().parent.parent
DOKUMENT = WURZEL / "docs" / "09-appstore.md"
SPRACHE = "de-DE"

# **Wiederverwendet statt abgeschrieben**: Anmeldung, Zugang, Hochladen und die
# Kurzfassung von Apples Fehlern stehen in `asc-einreichung.py`. Eine zweite
# Fassung davon wäre die Fehlerklasse aus dem Baukasten: zwei Wege, die dasselbe
# tun sollen und es irgendwann nicht mehr tun.
_spec = importlib.util.spec_from_file_location(
    "asc_einreichung", WURZEL / "scripts" / "asc-einreichung.py")
einreichung = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(einreichung)
Apple, kurz, bild_hochladen = einreichung.Apple, einreichung.kurz, einreichung.bild_hochladen
BUNDLE = einreichung.BUNDLE

# ---------------------------------------------------------------- Ereignis

REFERENZ = "Winter-Check Heizung Dezember 2026"

# **Höchstens 31 Tage** lässt Apple ein Ereignis laufen. Vom 1. bis 31. Dezember,
# deutsche Zeit, also in UTC eine Stunde früher. Angekündigt wird es drei Tage
# vorher („Bald verfügbar“); kommt die Freigabe später, erscheint es mit ihr.
ZEITPLAN = {
    "territories": ["DEU", "AUT", "CHE"],
    "publishStart": "2026-11-27T23:00:00Z",
    "eventStart": "2026-11-30T23:00:00Z",
    "eventEnd": "2026-12-31T22:59:00Z",
}

# „Großes Update“: Der Vergleich vorher und nachher kam mit 1.8 und ist das,
# worum es geht. „Kauf nötig“, weil er am Kauf „Wärmepumpe“ hängt
# (`Entitlement.canCompareHeating`); ein Ereignis, das „kostenlos“ sagt und
# dann ein Kaufblatt zeigt, wäre genau die Enttäuschung, die Bewertungen kostet.
EREIGNIS = {
    "referenceName": REFERENZ,
    "badge": "MAJOR_UPDATE",
    "purchaseRequirement": "IN_APP_PURCHASE",
    "primaryLocale": SPRACHE,
    "priority": "NORMAL",
    "purpose": "ATTRACT_NEW_USERS",
    "territorySchedules": [ZEITPLAN],
}

# Apples Grenzen, nachgeschlagen in App Store Connect beim Anlegen von Hand.
GRENZEN = {"name": 30, "shortDescription": 50, "longDescription": 120,
           "promotionalText": 170}

# Die Bilder kommen aus `ereignis-bilder.mjs`, Maß und Art stehen dort auch.
EREIGNIS_BILDER = [("karte.jpg", "EVENT_CARD", 1920, 1080),
                   ("seite.jpg", "EVENT_DETAILS_PAGE", 1080, 1920)]

# ---------------------------------------------------------------- Produktseite

SEITENNAME = "Wärmepumpe"
ABSCHNITT_BILDER = "Überschriften der Produktseite Wärmepumpe"

# Dieselben zwei Bildschirme wie die Store-Seite, dieselben Kennungen und
# Maße (siehe `asc-einreichung.py`, BILDSCHIRM und BILDSCHIRME).
BILDSCHIRME = [("APP_IPHONE_67", "", 1320, 2868),
               ("APP_IPAD_PRO_3GEN_129", "ipad-", 2064, 2752)]


def block(ueberschrift: str) -> str:
    """Der Text im ersten ```-Block unter `### ueberschrift`."""
    text = DOKUMENT.read_text(encoding="utf-8")
    teile = text.split(f"### {ueberschrift}\n", 1)
    if len(teile) < 2:
        sys.exit(f"09-appstore.md: Abschnitt „{ueberschrift}“ fehlt")
    treffer = re.search(r"```\n(.*?)```", teile[1], re.S)
    if not treffer:
        sys.exit(f"09-appstore.md: kein Textblock unter „{ueberschrift}“")
    return treffer.group(1).strip()


def texte() -> dict[str, str]:
    return {
        "name": block("Ereignis: Name"),
        "shortDescription": block("Ereignis: Kurzbeschreibung"),
        "longDescription": block("Ereignis: Beschreibung"),
        "promotionalText": block("Produktseite Wärmepumpe: Werbetext"),
    }


def seitenbilder(ordner: pathlib.Path, praefix: str) -> list[pathlib.Path]:
    """Die gesetzten Bilder in der Reihenfolge aus `09-appstore.md`."""
    zeilen = block(ABSCHNITT_BILDER).splitlines()
    return [ordner / f"{praefix}{nummer:02d}-{zeile.split('|')[0].strip()}.jpg"
            for nummer, zeile in enumerate(zeilen, start=1)]


def bildmass(pfad: pathlib.Path) -> tuple[int, int]:
    """Breite und Höhe einer JPEG-Datei, ohne Bibliothek: Der Ablauf hat
    nur `requests` und `jwt`, und eine Abhängigkeit für zwei Zahlen lohnt nicht."""
    daten = pfad.read_bytes()
    i = 2
    while i < len(daten):
        if daten[i] != 0xFF:
            i += 1
            continue
        marke = daten[i + 1]
        laenge = int.from_bytes(daten[i + 2:i + 4], "big")
        if marke in (0xC0, 0xC1, 0xC2):
            return (int.from_bytes(daten[i + 7:i + 9], "big"),
                    int.from_bytes(daten[i + 5:i + 7], "big"))
        i += 2 + laenge
    return (0, 0)


def pruefen(bilder: pathlib.Path, ereignis: pathlib.Path) -> int:
    fehler = []
    for feld, text in texte().items():
        if not text:
            fehler.append(f"{feld} ist leer")
        elif len(text) > GRENZEN[feld]:
            fehler.append(f"{feld} hat {len(text)} Zeichen, Apple nimmt {GRENZEN[feld]}: {text}")
    zeilen = block(ABSCHNITT_BILDER).splitlines()
    if not 1 <= len(zeilen) <= 10:
        fehler.append(f"Produktseite: {len(zeilen)} Bilder, Apple nimmt 1 bis 10")
    # Die Bilder gibt es nur nach einem Lauf mit Simulator. Fehlen sie, ist
    # das hier kein Fehler; `anlegen` bricht dann ab.
    for _, praefix, w, h in BILDSCHIRME:
        for pfad in seitenbilder(bilder, praefix):
            if pfad.exists() and bildmass(pfad) != (w, h):
                fehler.append(f"{pfad.name}: {bildmass(pfad)}, verlangt {(w, h)}")
    for datei, _, w, h in EREIGNIS_BILDER:
        pfad = ereignis / datei
        if pfad.exists() and bildmass(pfad) != (w, h):
            fehler.append(f"{datei}: {bildmass(pfad)}, verlangt {(w, h)}")
    for zeile in fehler:
        print(f"  ✗ {zeile}")
    if not fehler:
        print("Ereignis und Produktseite: Texte in Apples Grenzen, Bilder im Maß.")
    return 1 if fehler else 0


# ---------------------------------------------------------------- Apple


def alle(apple: Apple, pfad: str, **werte) -> list[dict]:
    stand, antwort = apple.holen(pfad, **werte)
    if stand != 200:
        print(f"::warning::{pfad}: {stand} — {kurz(antwort)}")
        return []
    return antwort.json().get("data", [])


def pflicht(stand: int, antwort, was: str) -> dict:
    if stand not in (200, 201):
        print(f"::error::{was}: {stand} — {kurz(antwort)}")
        sys.exit(1)
    return antwort.json().get("data", {})


def app_kennung(apple: Apple) -> str:
    daten = alle(apple, "v1/apps", **{"filter[bundleId]": BUNDLE, "limit": 5})
    if not daten:
        sys.exit("Die App ist bei Apple nicht zu finden.")
    return daten[0]["id"]


def unser_ereignis(apple: Apple, app_id: str) -> dict | None:
    for e in alle(apple, f"v1/apps/{app_id}/appEvents", limit=50):
        if e["attributes"].get("referenceName") == REFERENZ:
            return e
    return None


def unsere_seite(apple: Apple, app_id: str) -> dict | None:
    for s in alle(apple, f"v1/apps/{app_id}/appCustomProductPages", limit=50):
        if s["attributes"].get("name") == SEITENNAME:
            return s
    return None


def seiten_fassung(apple: Apple, seite_id: str) -> dict | None:
    """Die Fassung, an der sich noch etwas ändern lässt, sonst die jüngste."""
    fassungen = alle(apple, f"v1/appCustomProductPages/{seite_id}/appCustomProductPageVersions",
                     limit=20)
    offen = [f for f in fassungen if f["attributes"].get("state") in
             ("PREPARE_FOR_SUBMISSION", "REJECTED", None)]
    return (offen or fassungen or [None])[-1]


def stand(apple: Apple) -> int:
    app_id = app_kennung(apple)
    e = unser_ereignis(apple, app_id)
    if e:
        a = e["attributes"]
        print(f"Ereignis „{a.get('referenceName')}“: {a.get('eventState')}")
        for s in a.get("territorySchedules") or []:
            print(f"  {','.join(s.get('territories', []))}: sichtbar ab {s.get('publishStart')}, "
                  f"{s.get('eventStart')} bis {s.get('eventEnd')}")
    else:
        print(f"Ereignis „{REFERENZ}“: noch nicht angelegt")
    s = unsere_seite(apple, app_id)
    if s:
        f = seiten_fassung(apple, s["id"])
        print(f"Produktseite „{SEITENNAME}“: {s['attributes'].get('url') or '(noch ohne Adresse)'}, "
              f"Fassung {f['attributes'].get('state') if f else '–'}, "
              f"{'sichtbar' if s['attributes'].get('visible') else 'nicht sichtbar'}")
    else:
        print(f"Produktseite „{SEITENNAME}“: noch nicht angelegt")
    return 0


def ereignis_anlegen(apple: Apple, app_id: str, t: dict, ordner: pathlib.Path) -> None:
    e = unser_ereignis(apple, app_id)
    if e is None:
        e = pflicht(*apple.anlegen("v1/appEvents", {"data": {
            "type": "appEvents", "attributes": EREIGNIS,
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}}),
            "Ereignis anlegen")
        print(f"  ✓ Ereignis angelegt ({e['id']})")
    elif e["attributes"].get("eventState") in ("DRAFT", "REJECTED"):
        pflicht(*apple.aendern(f"v1/appEvents/{e['id']}", {"data": {
            "type": "appEvents", "id": e["id"],
            "attributes": {k: v for k, v in EREIGNIS.items() if k != "primaryLocale"}}}),
            "Ereignis ändern")
        print("  ✓ Ereignis auf dem Stand des Repositorys")
    else:
        print(f"  · Ereignis steht auf {e['attributes'].get('eventState')}, wird nicht mehr geändert")
        return

    felder = {k: t[k] for k in ("name", "shortDescription", "longDescription")}
    sprachen = alle(apple, f"v1/appEvents/{e['id']}/localizations", limit=10)
    sprache = next((s for s in sprachen if s["attributes"].get("locale") == SPRACHE), None)
    if sprache is None:
        sprache = pflicht(*apple.anlegen("v1/appEventLocalizations", {"data": {
            "type": "appEventLocalizations", "attributes": {"locale": SPRACHE, **felder},
            "relationships": {"appEvent": {"data": {"type": "appEvents", "id": e["id"]}}}}}),
            "Ereignis beschriften")
    else:
        pflicht(*apple.aendern(f"v1/appEventLocalizations/{sprache['id']}", {"data": {
            "type": "appEventLocalizations", "id": sprache["id"], "attributes": felder}}),
            "Ereignis beschriften")
    print(f"  ✓ Ereignis beschriftet: {t['name']}")

    # Bilder: was liegt, wird ersetzt. Ein Ereignis hat je Art genau eines.
    liegen = alle(apple, f"v1/appEventLocalizations/{sprache['id']}/appEventScreenshots", limit=10)
    for datei, art, _, _ in EREIGNIS_BILDER:
        pfad = ordner / datei
        if not pfad.exists():
            sys.exit(f"Fehlt: {pfad} (node scripts/ereignis-bilder.mjs)")
        for alt in liegen:
            if alt["attributes"].get("appEventAssetType") == art:
                apple.loeschen(f"v1/appEventScreenshots/{alt['id']}")
        daten = pfad.read_bytes()
        neu = pflicht(*apple.anlegen("v1/appEventScreenshots", {"data": {
            "type": "appEventScreenshots",
            "attributes": {"fileSize": len(daten), "fileName": datei, "appEventAssetType": art},
            "relationships": {"appEventLocalization": {
                "data": {"type": "appEventLocalizations", "id": sprache["id"]}}}}}),
            f"Bild {datei} anmelden")
        for zug in neu.get("attributes", {}).get("uploadOperations", []):
            teil = daten[zug["offset"]:zug["offset"] + zug["length"]]
            kopf = {k["name"]: k["value"] for k in zug.get("requestHeaders", [])}
            gesendet = requests.request(zug["method"], zug["url"], headers=kopf, data=teil, timeout=120)
            if gesendet.status_code >= 300:
                sys.exit(f"Bild {datei} nicht übertragen ({gesendet.status_code})")
        pflicht(*apple.aendern(f"v1/appEventScreenshots/{neu['id']}", {"data": {
            "type": "appEventScreenshots", "id": neu["id"], "attributes": {"uploaded": True}}}),
            f"Bild {datei} bestätigen")
        print(f"  ✓ Bild {datei} ({art})")


def seite_anlegen(apple: Apple, app_id: str, t: dict, ordner: pathlib.Path) -> None:
    for _, praefix, _, _ in BILDSCHIRME:
        for pfad in seitenbilder(ordner, praefix):
            if not pfad.exists():
                sys.exit(f"Fehlt: {pfad} (node scripts/store-shots.mjs … \"{ABSCHNITT_BILDER}\")")

    s = unsere_seite(apple, app_id)
    if s is None:
        # Seite, Fassung und Sprache in einem Zug: Apple legt eine Seite nur
        # mit ihrer ersten Fassung an.
        s = pflicht(*apple.anlegen("v1/appCustomProductPages", {
            "data": {"type": "appCustomProductPages", "attributes": {"name": SEITENNAME},
                     "relationships": {
                         "app": {"data": {"type": "apps", "id": app_id}},
                         "appCustomProductPageVersions": {"data": [
                             {"type": "appCustomProductPageVersions", "id": "${fassung}"}]}}},
            "included": [
                {"type": "appCustomProductPageVersions", "id": "${fassung}",
                 "relationships": {"appCustomProductPageLocalizations": {"data": [
                     {"type": "appCustomProductPageLocalizations", "id": "${sprache}"}]}}},
                {"type": "appCustomProductPageLocalizations", "id": "${sprache}",
                 "attributes": {"locale": SPRACHE, "promotionalText": t["promotionalText"]}},
            ]}), "Produktseite anlegen")
        print(f"  ✓ Produktseite „{SEITENNAME}“ angelegt ({s['id']})")

    fassung = seiten_fassung(apple, s["id"])
    if fassung is None or fassung["attributes"].get("state") not in ("PREPARE_FOR_SUBMISSION", "REJECTED"):
        print(f"  · Produktseite steht auf "
              f"{fassung['attributes'].get('state') if fassung else '–'}, wird nicht mehr geändert")
        return
    sprachen = alle(apple, f"v1/appCustomProductPageVersions/{fassung['id']}"
                           "/appCustomProductPageLocalizations", limit=10)
    sprache = next((x for x in sprachen if x["attributes"].get("locale") == SPRACHE), None)
    if sprache is None:
        sprache = pflicht(*apple.anlegen("v1/appCustomProductPageLocalizations", {"data": {
            "type": "appCustomProductPageLocalizations",
            "attributes": {"locale": SPRACHE, "promotionalText": t["promotionalText"]},
            "relationships": {"appCustomProductPageVersion": {
                "data": {"type": "appCustomProductPageVersions", "id": fassung["id"]}}}}}),
            "Produktseite beschriften")
    else:
        pflicht(*apple.aendern(f"v1/appCustomProductPageLocalizations/{sprache['id']}", {"data": {
            "type": "appCustomProductPageLocalizations", "id": sprache["id"],
            "attributes": {"promotionalText": t["promotionalText"]}}}), "Werbetext eintragen")
    print("  ✓ Werbetext eingetragen")

    saetze = alle(apple, f"v1/appCustomProductPageLocalizations/{sprache['id']}/appScreenshotSets",
                  limit=20)
    for kennung, praefix, _, _ in BILDSCHIRME:
        satz = next((x for x in saetze if x["attributes"].get("screenshotDisplayType") == kennung), None)
        if satz is None:
            satz = pflicht(*apple.anlegen("v1/appScreenshotSets", {"data": {
                "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": kennung},
                "relationships": {"appCustomProductPageLocalization": {
                    "data": {"type": "appCustomProductPageLocalizations", "id": sprache["id"]}}}}}),
                f"Bildersatz {kennung} anlegen")
        # Ersetzen statt ergänzen: Ein zweiter Lauf soll denselben Satz
        # ergeben, nicht einen doppelt so langen.
        for alt in alle(apple, f"v1/appScreenshotSets/{satz['id']}/appScreenshots", limit=20):
            apple.loeschen(f"v1/appScreenshots/{alt['id']}")
        for nummer, pfad in enumerate(seitenbilder(ordner, praefix), start=1):
            fehler = bild_hochladen(apple, satz["id"], str(pfad), nummer)
            if fehler:
                sys.exit(f"{pfad.name}: {fehler}")
        print(f"  ✓ {kennung}: {len(seitenbilder(ordner, praefix))} Bilder")


def einreichen(apple: Apple) -> int:
    app_id = app_kennung(apple)
    e = unser_ereignis(apple, app_id)
    s = unsere_seite(apple, app_id)
    fassung = seiten_fassung(apple, s["id"]) if s else None
    if not e or not fassung:
        sys.exit("Erst `anlegen`: Ereignis oder Produktseite fehlen.")
    # Eine offene Einreichung je Plattform. Liegt schon eine, wird sie benutzt.
    offen = [r for r in alle(apple, "v1/reviewSubmissions", **{
        "filter[app]": app_id, "filter[platform]": "IOS", "limit": 20})
        if r["attributes"].get("state") == "READY_FOR_REVIEW"]
    einreichung_ = offen[0] if offen else pflicht(*apple.anlegen("v1/reviewSubmissions", {"data": {
        "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}}), "Einreichung anlegen")
    for beziehung, art, kennung in (("appEvent", "appEvents", e["id"]),
                                    ("appCustomProductPageVersion", "appCustomProductPageVersions",
                                     fassung["id"])):
        stand_, antwort = apple.anlegen("v1/reviewSubmissionItems", {"data": {
            "type": "reviewSubmissionItems", "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": einreichung_["id"]}},
                beziehung: {"data": {"type": art, "id": kennung}}}}})
        # 409 heißt hier meist: liegt schon in dieser Einreichung.
        if stand_ not in (200, 201, 409):
            print(f"::error::{beziehung} beifügen: {stand_} — {kurz(antwort)}")
            return 1
        print(f"  ✓ {beziehung} beigefügt" if stand_ != 409 else f"  · {beziehung}: {kurz(antwort)}")
    pflicht(*apple.aendern(f"v1/reviewSubmissions/{einreichung_['id']}", {"data": {
        "type": "reviewSubmissions", "id": einreichung_["id"], "attributes": {"submitted": True}}}),
        "Einreichen")
    print("::notice::Ereignis und Produktseite sind bei Apple zur Prüfung.")
    return 0


def main() -> int:
    bilder = WURZEL / "build" / "wp-gesetzt"
    ereignis = WURZEL / "build" / "ereignis"
    art = sys.argv[1] if len(sys.argv) > 1 else "--pruefen"
    if art == "--pruefen":
        return pruefen(bilder, ereignis)
    if pruefen(bilder, ereignis):
        return 1
    apple = Apple()
    if art == "stand":
        return stand(apple)
    if art == "anlegen":
        app_id = app_kennung(apple)
        t = texte()
        ereignis_anlegen(apple, app_id, t, ereignis)
        seite_anlegen(apple, app_id, t, bilder)
        return stand(apple)
    if art == "einreichen":
        return einreichen(apple)
    sys.exit(f"Unbekannt: {art} (stand, anlegen, einreichen, --pruefen)")


if __name__ == "__main__":
    sys.exit(main())
