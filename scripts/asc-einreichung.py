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

    beziehungen = info.get("relationships", {})
    for name, was in (("primaryCategory", "Hauptkategorie"),
                      ("secondaryCategory", "Zweitkategorie")):
        gesetzt = (beziehungen.get(name) or {}).get("data")
        pruefe(bool(gesetzt), f"{was}: {(gesetzt or {}).get('id', '—')}")

    stand, alter = erste(apple, f"v1/appInfos/{info['id']}/ageRatingDeclaration")
    if alter is None:
        offen.append(f"Altersfreigabe: nicht lesbar ({stand})")
    else:
        gesetzt = [k for k, v in (alter.get("attributes") or {}).items()
                   if v not in (None, "", False, "NONE")]
        pruefe(bool(alter.get("attributes")),
               f"Altersfreigabe beantwortet ({len(gesetzt)} Angaben von null verschieden)")


def fassung_pruefen(apple: Apple, app_id: str) -> None:
    """Die Fassung selbst: Zustand, Texte, Bilder, Prüfangaben."""
    stand, fassung = erste(apple, f"v1/apps/{app_id}/appStoreVersions",
                           **{"limit": 5, "sort": "-versionString"})
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
