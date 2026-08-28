#!/usr/bin/env python3
"""Sagt, was App Store Connect für die Einreichung noch verlangt — gemessen.

**Warum das existiert.** Die Liste „was vor dem Einreichen noch fehlt" stand
bisher in `docs/09-appstore.md` und wurde von Hand gepflegt. Sie war beim
Nachsehen falsch: StoreKit stand dort als offen, obwohl die fünf Käufe seit
Tagen bereit sind. Eine Liste, die nachgeführt werden muss, ist am Tag nach
dem Nachführen wieder veraltet.

Dieses Skript fragt stattdessen Apple. Was hier steht, ist der Zustand von
heute — nicht die Erinnerung von vorgestern.

**Es schreibt nichts.** Ohne `--fuellen` liest es nur. Das ist Absicht: Der
erste Durchgang soll die Lage zeigen, nicht sie verändern. Mit `--fuellen`
trägt es ein, was aus dem Repository kommt (Texte, Kategorien, Altersfreigabe)
— und lässt alles aus, was jemandem gehört, der gefragt werden muss.

Aufruf (Umgebung wie bei `asc-profil.py`):

    ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_P8=… python3 scripts/asc-einreichung.py
"""

import json
import os
import re
import sys
import time

import jwt
import requests

BASIS = "https://api.appstoreconnect.apple.com"
BUNDLE = "de.karjoth.pulsemeter"
SPRACHE = "de-DE"

# Was gezählt wird: erledigt, offen, und was nur der Gründer liefern kann.
erledigt: list[str] = []
offen: list[str] = []
gehoert_ihm: list[str] = []
getan: list[str] = []


def token() -> str:
    schluessel = os.environ.get("ASC_KEY_P8", "")
    kid = os.environ.get("ASC_KEY_ID", "")
    iss = os.environ.get("ASC_ISSUER_ID", "")
    if not (schluessel and kid and iss):
        print("::error::ASC_KEY_ID, ASC_ISSUER_ID und ASC_KEY_P8 müssen gesetzt sein.")
        sys.exit(1)
    jetzt = int(time.time())
    return jwt.encode({"iss": iss, "iat": jetzt, "exp": jetzt + 1200,
                       "aud": "appstoreconnect-v1"},
                      schluessel, algorithm="ES256", headers={"kid": kid})


class Apple:
    def __init__(self) -> None:
        self.kopf = {"Authorization": f"Bearer {token()}",
                     "Content-Type": "application/json"}

    def holen(self, pfad: str, **werte):
        antwort = requests.get(f"{BASIS}/{pfad}", headers=self.kopf,
                               params=werte, timeout=30)
        return antwort.status_code, antwort

    def anlegen(self, pfad: str, koerper: dict):
        antwort = requests.post(f"{BASIS}/{pfad}", headers=self.kopf,
                                data=json.dumps(koerper), timeout=60)
        return antwort.status_code, antwort

    def aendern(self, pfad: str, koerper: dict):
        antwort = requests.patch(f"{BASIS}/{pfad}", headers=self.kopf,
                                 data=json.dumps(koerper), timeout=60)
        return antwort.status_code, antwort


def kurz(antwort) -> str:
    try:
        fehler = antwort.json().get("errors", [])
        if fehler:
            erster = fehler[0]
            return f"{erster.get('title', '')} — {erster.get('detail', '')}"[:200]
    except ValueError:
        pass
    return antwort.text[:200]


def erste(apple: Apple, pfad: str, **werte):
    """Ein einzelner Datensatz oder der erste einer Liste — oder None.

    **Ohne `limit` bei Einzelressourcen.** `appPriceSchedule` und Verwandte
    antworten sonst mit 400, und im Protokoll liest sich das wie Apples
    Ablehnung, obwohl es die eigene Anfrage war. Das hat einmal einen halben
    Tag gekostet (Baukasten, Abschnitt 5).
    """
    stand, antwort = apple.holen(pfad, **werte)
    if stand != 200:
        return stand, None
    daten = antwort.json().get("data")
    if isinstance(daten, list):
        return stand, daten[0] if daten else None
    return stand, daten


def feld(eintrag, name: str):
    return (eintrag or {}).get("attributes", {}).get(name)


def pruefe(bedingung: bool, satz: str, wem: list[str] | None = None) -> None:
    if bedingung:
        erledigt.append(satz)
    else:
        (wem if wem is not None else offen).append(satz)


# ---------------------------------------------------------------- Füllen

# **Die Texte stehen in `docs/09-appstore.md` und nirgends sonst.** Sie hier
# noch einmal hinzuschreiben hieße, zwei Fassungen zu führen — und die laufen
# auseinander, das ist heute dreimal passiert. Gelesen wird der Block hinter
# der jeweiligen Überschrift.
def store_text(ueberschrift: str) -> str:
    pfad = os.path.join(os.path.dirname(__file__), "..", "docs", "09-appstore.md")
    try:
        with open(pfad, encoding="utf-8") as datei:
            inhalt = datei.read()
    except OSError:
        return ""
    stelle = inhalt.find("### " + ueberschrift)
    if stelle < 0:
        return ""
    treffer = re.search(r"```\n(.*?)```", inhalt[stelle:], re.S)
    return treffer.group(1).strip() if treffer else ""


# Aus derselben Datei, Abschnitt 2 „Einordnung".
KATEGORIE_HAUPT = "UTILITIES"
KATEGORIE_ZWEIT = "FINANCE"

WEBSITE = "https://pulsemeter.pages.dev"
DATENSCHUTZ = f"{WEBSITE}/datenschutz"
SUPPORT = f"{WEBSITE}/hilfe"


# In Apples Fehlertexten steht das Feld in einfachen Anführungszeichen.
FELD_IM_FEHLER = re.compile(r"attribute '([A-Za-z]+)'")


def setzen(apple: Apple, pfad: str, typ: str, kennung: str,
           werte: dict, was: str) -> bool:
    """Ein PATCH, der auf Apples Einwand eingeht, statt ihn zu melden.

    **Warum das nötig war.** Der erste Lauf brachte zwei 409er, und beide
    nannten das Feld, an dem es lag:

        Unexpected json type provided for attribute 'messagingAndChat'.
        Expected a BOOLEAN but got STRING

        Attribute 'whatsNew' cannot be edited at this time

    Beides ließe sich mit einer abgetippten Liste erschlagen — welche Felder
    Wahrheitswerte sind, und dass die erste Fassung keine Versionshinweise
    annimmt. Solche Listen veralten still. Apple sagt es ohnehin in jedem
    Einwand; also wird gelesen statt geraten: Falscher Typ → umdrehen. Nicht
    änderbar → weglassen und den Rest trotzdem eintragen.
    """
    bleibt = {k: v for k, v in werte.items() if v not in (None, "")}
    if not bleibt:
        offen.append(f"{was}: nichts einzutragen — der Text fehlt im Dokument")
        return False

    weggelassen: list[str] = []
    for _ in range(len(bleibt) + 2):
        stand, antwort = apple.aendern(f"{pfad}/{kennung}",
                                       {"data": {"type": typ, "id": kennung,
                                                 "attributes": bleibt}})
        if stand in (200, 204):
            satz = f"{was}: {', '.join(bleibt)}"
            if weggelassen:
                satz += f" (ohne {', '.join(weggelassen)} — Apple lässt es hier nicht zu)"
            getan.append(satz)
            return True

        text = kurz(antwort)
        treffer = FELD_IM_FEHLER.search(text)
        if stand != 409 or not treffer or treffer.group(1) not in bleibt:
            offen.append(f"{was}: ging nicht ({stand}) — {text}")
            return False

        name = treffer.group(1)
        if "BOOLEAN" in text:
            bleibt[name] = False
        else:
            del bleibt[name]
            weggelassen.append(name)
        if not bleibt:
            offen.append(f"{was}: Apple lässt hier gerade nichts ändern — {text}")
            return False

    offen.append(f"{was}: gibt nach mehreren Versuchen keine Ruhe")
    return False


def eintrag_fuellen(apple: Apple, app_id: str) -> None:
    """Name, Untertitel, Datenschutz-URL, Kategorien, Altersfreigabe."""
    stand, info = erste(apple, f"v1/apps/{app_id}/appInfos", **{"limit": 10})
    if info is None:
        offen.append(f"Der App-Eintrag ließ sich nicht lesen ({stand})")
        return

    stand, ort = erste(apple, f"v1/appInfos/{info['id']}/appInfoLocalizations",
                       **{"limit": 20, "filter[locale]": SPRACHE})
    if ort is None:
        offen.append("Keine deutsche Beschriftung am App-Eintrag")
    else:
        setzen(apple, "v1/appInfoLocalizations", "appInfoLocalizations",
               ort["id"],
               {"name": store_text("Name (max. 30 Zeichen)"),
                "subtitle": store_text("Untertitel (max. 30 Zeichen)"),
                "privacyPolicyUrl": DATENSCHUTZ},
               "Name, Untertitel und Datenschutz-URL")

    # Kategorien hängen als Beziehung, nicht als Eigenschaft.
    stand, antwort = apple.aendern(f"v1/appInfos/{info['id']}", {"data": {
        "type": "appInfos", "id": info["id"],
        "relationships": {
            "primaryCategory": {"data": {"type": "appCategories",
                                         "id": KATEGORIE_HAUPT}},
            "secondaryCategory": {"data": {"type": "appCategories",
                                           "id": KATEGORIE_ZWEIT}},
        }}})
    if stand in (200, 204):
        getan.append(f"Kategorien: {KATEGORIE_HAUPT}, {KATEGORIE_ZWEIT}")
    else:
        offen.append(f"Kategorien: ging nicht ({stand}) — {kurz(antwort)}")

    # **Altersfreigabe 4+**: keine der Fragen trifft zu. Die Felder heißen bei
    # Apple lang und wechseln gelegentlich; deshalb wird gesetzt, was der
    # Eintrag selbst führt, statt eine Liste zu raten.
    stand, alter = erste(apple, f"v1/appInfos/{info['id']}/ageRatingDeclaration")
    if alter is None:
        offen.append(f"Altersfreigabe nicht lesbar ({stand})")
        return
    # Erst alles als „NONE"; welche davon Wahrheitswerte sind, sagt Apple im
    # Einwand, und `setzen` dreht sie dann um.
    antworten = {name: "NONE" for name in (alter.get("attributes") or {})
                 if name not in ("ageRatingOverride", "kidsAgeBand")}
    setzen(apple, "v1/ageRatingDeclarations", "ageRatingDeclarations",
           alter["id"], antworten, "Altersfreigabe 4+")


def fassung_fuellen(apple: Apple, app_id: str) -> None:
    """Die Fassung 1.0 und ihre Texte."""
    stand, fassung = erste(apple, f"v1/apps/{app_id}/appStoreVersions",
                           **{"limit": 5, "filter[platform]": "IOS"})
    if fassung is None:
        stand, antwort = apple.anlegen("v1/appStoreVersions", {"data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": "1.0"},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }})
        if stand not in (200, 201):
            offen.append(f"Fassung 1.0 ließ sich nicht anlegen ({stand}) "
                         f"— {kurz(antwort)}")
            return
        fassung = antwort.json()["data"]
        getan.append("Fassung 1.0 angelegt")
    else:
        getan.append(f"Fassung {feld(fassung, 'versionString')} stand schon")

    stand, ort = erste(apple,
                       f"v1/appStoreVersions/{fassung['id']}/appStoreVersionLocalizations",
                       **{"limit": 20, "filter[locale]": SPRACHE})
    if ort is None:
        stand, antwort = apple.anlegen("v1/appStoreVersionLocalizations", {"data": {
            "type": "appStoreVersionLocalizations",
            "attributes": {"locale": SPRACHE},
            "relationships": {"appStoreVersion": {
                "data": {"type": "appStoreVersions", "id": fassung["id"]}}},
        }})
        if stand not in (200, 201):
            offen.append(f"Deutsche Texte ließen sich nicht anlegen ({stand}) "
                         f"— {kurz(antwort)}")
            return
        ort = antwort.json()["data"]

    setzen(apple, "v1/appStoreVersionLocalizations",
           "appStoreVersionLocalizations", ort["id"],
           {"description": store_text("Beschreibung (max. 4000 Zeichen)"),
            "keywords": store_text("Schlagworte (max. 100 Zeichen, komma-getrennt, ohne Leerzeichen)"),
            "promotionalText": store_text("Werbetext (max. 170 Zeichen, jederzeit ohne neue Version änderbar)"),
            "whatsNew": store_text("Neue Funktionen (Versionshinweise)"),
            "supportUrl": SUPPORT,
            "marketingUrl": WEBSITE},
           "Beschreibung, Schlagworte, Werbetext, Support-URL")


def app_finden(apple: Apple):
    stand, antwort = apple.holen("v1/apps", **{"filter[bundleId]": BUNDLE,
                                               "limit": 20})
    if stand != 200:
        print(f"::error::Die App ließ sich nicht lesen ({stand}) — {kurz(antwort)}")
        sys.exit(1)
    for eintrag in antwort.json().get("data", []):
        if eintrag["attributes"].get("bundleId") == BUNDLE:
            return eintrag["id"]
    print(f"::error::Zu {BUNDLE} gibt es keinen App-Eintrag.")
    sys.exit(1)


def eintrag_pruefen(apple: Apple, app_id: str) -> None:
    """Name, Untertitel, Kategorien, Altersfreigabe, Datenschutz-URL."""
    stand, info = erste(apple, f"v1/apps/{app_id}/appInfos", **{"limit": 10})
    if info is None:
        offen.append(f"Der App-Eintrag ließ sich nicht lesen ({stand})")
        return

    stand, ort = erste(apple, f"v1/appInfos/{info['id']}/appInfoLocalizations",
                       **{"limit": 20, "filter[locale]": SPRACHE})
    pruefe(bool(feld(ort, "name")), f"Name: {feld(ort, 'name')!r}")
    pruefe(bool(feld(ort, "subtitle")), f"Untertitel: {feld(ort, 'subtitle')!r}")
    pruefe(bool(feld(ort, "privacyPolicyUrl")),
           "Datenschutzerklärung als URL — die Seite muss dafür veröffentlicht sein",
           gehoert_ihm)

    # **Die Listenantwort führt Beziehungen nur als Verweis, nicht als Wert.**
    # Der erste Lauf meldete deshalb „Hauptkategorie: —", obwohl der Eintrag
    # eine Zeile vorher gesetzt worden war. Gefragt wird jetzt einzeln, mit
    # `include`.
    stand, antwort = apple.holen(f"v1/appInfos/{info['id']}",
                                 **{"include": "primaryCategory,secondaryCategory"})
    dabei = {e["id"] for e in (antwort.json().get("included", []) if stand == 200 else [])}
    einzeln = antwort.json().get("data", {}) if stand == 200 else {}
    beziehungen = einzeln.get("relationships", {})
    for name, was in (("primaryCategory", "Hauptkategorie"),
                      ("secondaryCategory", "Zweitkategorie")):
        gesetzt = (beziehungen.get(name) or {}).get("data")
        kennung = (gesetzt or {}).get("id")
        pruefe(bool(kennung), f"{was}: {kennung or '—'}"
               + ("" if not kennung or kennung in dabei else " (nicht auflösbar)"))

    stand, alter = erste(apple, f"v1/appInfos/{info['id']}/ageRatingDeclaration")
    if alter is None:
        offen.append(f"Altersfreigabe: nicht lesbar ({stand})")
    else:
        # **Vorhanden ist nicht beantwortet.** Der erste Lauf meldete
        # „Altersfreigabe beantwortet (0 Angaben)" — die Ressource war da und
        # leer. Dieselbe Fehlerklasse, über die im Baukasten seit heute ein
        # Abschnitt steht, und ich bin beim Schreiben dieses Lesers hineingelaufen.
        # Beantwortet ist sie, wenn Apple die Freigabe berechnet hat.
        stufe = feld(alter, "ageRatingOverride") or feld(alter, "kidsAgeBand")
        angaben = [k for k, v in (alter.get("attributes") or {}).items()
                   if v is not None]
        pruefe(len(angaben) >= 5,
               f"Altersfreigabe: {len(angaben)} Angaben"
               + (f", Stufe {stufe}" if stufe else ""))


def fassung_pruefen(apple: Apple, app_id: str) -> None:
    """Die Fassung selbst: Zustand, Texte, Bilder, Prüfangaben."""
    # **Dieselbe Abfrage wie im Füller.** Der las mit `filter[platform]` und
    # fand die Fassung; der Leser sortierte mit `sort=-versionString`, bekam
    # nichts Brauchbares zurück und meldete „es gibt noch keine Fassung" —
    # während zwei Zeilen darüber stand, dass sie schon steht.
    stand, fassung = erste(apple, f"v1/apps/{app_id}/appStoreVersions",
                           **{"limit": 5, "filter[platform]": "IOS"})
    if fassung is None:
        offen.append("Es gibt noch keine App-Store-Fassung — sie wird angelegt")
        return
    zustand = feld(fassung, "appStoreState") or feld(fassung, "appVersionState")
    print(f"::notice::Fassung {feld(fassung, 'versionString')} — {zustand}")

    stand, ort = erste(apple,
                       f"v1/appStoreVersions/{fassung['id']}/appStoreVersionLocalizations",
                       **{"limit": 20, "filter[locale]": SPRACHE})
    if ort is None:
        offen.append(f"Die Texte der Fassung sind nicht lesbar ({stand})")
        return

    for name, was, wem in (("description", "Beschreibung", None),
                           ("keywords", "Schlagworte", None),
                           ("promotionalText", "Werbetext", None),
                           ("whatsNew", "Neue Funktionen", None),
                           ("supportUrl", "Support-URL", gehoert_ihm),
                           ("marketingUrl", "Marketing-URL", gehoert_ihm)):
        wert = feld(ort, name) or ""
        pruefe(bool(wert.strip()),
               f"{was} ({len(wert)} Zeichen)" if wert else f"{was} fehlt", wem)

    stand, satz = erste(apple, f"v1/appStoreVersionLocalizations/{ort['id']}"
                               "/appScreenshotSets", **{"limit": 20})
    anzahl = 0
    if satz is not None:
        stand, bilder = apple.holen(f"v1/appScreenshotSets/{satz['id']}/appScreenshots",
                                    **{"limit": 20})
        if stand == 200:
            anzahl = len(bilder.json().get("data", []))
    pruefe(anzahl > 0, f"Bildschirmfotos: {anzahl}")

    stand, pruefung = erste(apple,
                            f"v1/appStoreVersions/{fassung['id']}/appStoreReviewDetail")
    hat_kontakt = bool(feld(pruefung, "contactEmail"))
    pruefe(hat_kontakt,
           "Kontakt für die Prüfung — Name, Telefon, E-Mail des Gründers",
           gehoert_ihm)


def kaeufe_pruefen(apple: Apple, app_id: str) -> None:
    stand, antwort = apple.holen(f"v1/apps/{app_id}/inAppPurchasesV2", **{"limit": 50})
    if stand != 200:
        offen.append(f"Die Käufe sind nicht lesbar ({stand})")
        return
    zustaende = [e["attributes"].get("state", "?")
                 for e in antwort.json().get("data", [])]
    bereit = [z for z in zustaende if z in ("READY_TO_SUBMIT", "APPROVED")]
    pruefe(len(bereit) == 5,
           f"Fünf Käufe bereit ({len(bereit)} von {len(zustaende)}: "
           f"{', '.join(sorted(set(zustaende)))})")


def verfuegbarkeit_pruefen(apple: Apple, app_id: str) -> None:
    stand, plan = erste(apple, f"v1/apps/{app_id}/appPriceSchedule")
    pruefe(plan is not None, f"Preisplan der App (Antwort {stand})")
    stand, wo = erste(apple, f"v1/apps/{app_id}/appAvailabilityV2")
    pruefe(wo is not None, f"Verfügbarkeit in Ländern (Antwort {stand})")


def main() -> None:
    apple = Apple()
    app_id = app_finden(apple)

    if "--fuellen" in sys.argv:
        print("::notice::Trage ein, was aus dem Repository kommt.")
        eintrag_fuellen(apple, app_id)
        fassung_fuellen(apple, app_id)
        print("\n=== Eingetragen ===")
        for zeile in getan:
            print(f"  ✓ {zeile}")
        print("\n=== Ging nicht ===")
        for zeile in offen:
            print(f"  · {zeile}")
        print("\n--- und so sieht es danach aus ---\n")
        getan.clear()
        offen.clear()

    eintrag_pruefen(apple, app_id)
    fassung_pruefen(apple, app_id)
    kaeufe_pruefen(apple, app_id)
    verfuegbarkeit_pruefen(apple, app_id)

    print("\n=== Steht ===")
    for zeile in erledigt:
        print(f"  ✓ {zeile}")
    print("\n=== Fehlt, mache ich ===")
    for zeile in offen:
        print(f"  · {zeile}")
    print("\n=== Fehlt, kann nur der Gründer ===")
    for zeile in gehoert_ihm:
        print(f"  → {zeile}")
    print(f"\n{len(erledigt)} steht, {len(offen)} offen, "
          f"{len(gehoert_ihm)} braucht eine Entscheidung oder eine Angabe.")


if __name__ == "__main__":
    main()
