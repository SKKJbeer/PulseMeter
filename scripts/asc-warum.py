#!/usr/bin/env python3
"""Fragt Apple, warum eine Fassung nicht eingereicht werden kann.

**Der Anlass.** Der erste Einreichungsversuch kam mit 409 zurück:

    appStoreVersions with id '…' is not in valid state.
    This resource cannot be reviewed, please check associated errors to see why.

Apple sagt „sieh dir die zugehörigen Fehler an" und nennt keinen einzigen. In
der Oberfläche stehen sie als rote Punkte neben den Feldern; über die
Schnittstelle gibt es keine Liste davon.

Also wird nicht geraten, sondern abgefragt, was sich abfragen lässt — und roh
ausgegeben. Jede Zeile ist eine Antwort von Apple, keine Vermutung von mir.
Was hier fehlt, fehlt auch dort.

    ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_P8=… python3 scripts/asc-warum.py
"""

import json
import os
import sys
import time

import jwt
import requests

BASIS = "https://api.appstoreconnect.apple.com"
BUNDLE = "de.karjoth.pulsemeter"


def token() -> str:
    jetzt = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": jetzt,
                       "exp": jetzt + 900, "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256",
                      headers={"kid": os.environ["ASC_KEY_ID"]})


KOPF = {"Authorization": ""}


def holen(pfad: str, **werte):
    a = requests.get(f"{BASIS}/{pfad}", headers=KOPF, params=werte, timeout=30)
    return a.status_code, a


def zeigen(titel: str, pfad: str, **werte) -> None:
    """Ein Aufruf, roh berichtet — auch und gerade wenn er scheitert.

    **Ein Fehlschlag ist hier keine Störung, sondern die Auskunft.** Ein 404
    auf eine Datenschutz-Ressource heißt: Es gibt sie nicht, also ist der
    Fragebogen nicht ausgefüllt. Deshalb bricht nichts ab.
    """
    stand, antwort = holen(pfad, **werte)
    print(f"\n── {titel}")
    print(f"   {pfad}  →  {stand}")
    try:
        koerper = antwort.json()
    except ValueError:
        print(f"   {antwort.text[:200]}")
        return

    if "errors" in koerper:
        for fehler in koerper["errors"][:4]:
            print(f"   ✗ {fehler.get('title', '')}: {fehler.get('detail', '')}"[:300])
        return

    daten = koerper.get("data")
    if isinstance(daten, list):
        print(f"   {len(daten)} Einträge")
        for eintrag in daten[:6]:
            merkmale = {k: v for k, v in (eintrag.get("attributes") or {}).items()
                        if v not in (None, "", [], {})}
            print(f"   · {eintrag.get('type')} {eintrag.get('id', '')[:8]} "
                  f"{json.dumps(merkmale, ensure_ascii=False)[:220]}")
    elif isinstance(daten, dict):
        merkmale = {k: v for k, v in (daten.get("attributes") or {}).items()
                    if v not in (None, "", [], {})}
        print(f"   {json.dumps(merkmale, ensure_ascii=False)[:600]}")
    else:
        print("   (leer)")


def main() -> int:
    KOPF["Authorization"] = f"Bearer {token()}"

    stand, antwort = holen("v1/apps", **{"filter[bundleId]": BUNDLE, "limit": 20})
    treffer = [e for e in (antwort.json().get("data", []) if stand == 200 else [])
               if e["attributes"].get("bundleId") == BUNDLE]
    if not treffer:
        print(f"::error::Kein App-Eintrag ({stand}).")
        return 1
    app = treffer[0]["id"]
    print(f"App {app} — {BUNDLE}")

    stand, antwort = holen(f"v1/apps/{app}/appStoreVersions",
                           **{"limit": 5, "filter[platform]": "IOS"})
    fassungen = antwort.json().get("data", []) if stand == 200 else []
    fassung = fassungen[0]["id"] if fassungen else None

    zeigen("Die App selbst", f"v1/apps/{app}")
    zeigen("Der App-Eintrag (hier steht MISSING_METADATA, wenn etwas fehlt)",
           f"v1/apps/{app}/appInfos", **{"limit": 5})
    if fassung:
        zeigen("Die Fassung", f"v1/appStoreVersions/{fassung}")
        zeigen("Der Bau an der Fassung", f"v1/appStoreVersions/{fassung}/build")
        zeigen("Die Angaben zur Prüfung",
               f"v1/appStoreVersions/{fassung}/appStoreReviewDetail")

    # **Der Datenschutz-Fragebogen ist etwas anderes als die Datenschutz-URL.**
    # Die URL steht am App-Eintrag und ist längst gesetzt; der Fragebogen
    # („Welche Daten erfasst die App?") ist eine eigene Ressource und muss
    # veröffentlicht sein, bevor eingereicht werden darf. Er stand auf keiner
    # unserer Listen.
    # **Der Name war beim ersten Anlauf dreimal falsch geraten.** Apple
    # antwortet darauf hilfreich — „The relationship 'x' does not exist" —,
    # und das ist eine Auskunft über meine Anfrage, nicht über die App.
    # Deshalb stehen hier mehrere Schreibweisen: Eine davon trifft, und welche
    # es ist, sagt Apple selbst.
    for pfad in ("appDataUsagesPublishState", "appDataUsagePublishState",
                 "appDataUsages", "dataUsages"):
        zeigen(f"Datenschutz-Fragebogen — {pfad}", f"v1/apps/{app}/{pfad}",
               **{"limit": 10})
    zeigen("Datenschutz-Fragebogen als eigene Liste", "v1/appDataUsages",
           **{"filter[app]": app, "limit": 10})

    # **Die Nachschlagewerke dahinter.** Gibt es sie, lässt sich der Fragebogen
    # über die Schnittstelle ausfüllen — dann braucht es niemanden, der klickt.
    # Gibt es sie nicht, ist auch das eine klare Antwort.
    for pfad in ("v1/appDataUsageCategories", "v1/appDataUsagePurposes",
                 "v1/appDataUsageDataProtections", "v1/appDataUsageGroupings"):
        zeigen(f"Nachschlagewerk — {pfad}", pfad, **{"limit": 5})

    # Händlerstatus nach dem Digitale-Dienste-Gesetz. Erwartung: gibt es
    # nicht. Geprüft wird sie trotzdem, weil eine Erwartung kein Befund ist.
    for pfad in (f"v1/apps/{app}/appTraderDeclaration",
                 f"v1/apps/{app}/traderDeclaration",
                 f"v1/apps/{app}/appStoreVersionSubmissions",
                 "v1/appTraderDeclarations"):
        zeigen(f"Händlerstatus — {pfad}", pfad, **{"limit": 5})

    # Was Apple sonst noch an der App hängen hat. Steht der Grund irgendwo,
    # dann in einer dieser Beziehungen — und wenn nicht, ist auch das eine
    # Antwort: Über die Schnittstelle ist er nicht zu bekommen.
    zeigen("Beziehungen der App", f"v1/apps/{app}",
           **{"fields[apps]": "name,bundleId,contentRightsDeclaration"})

    zeigen("Preisplan", f"v1/apps/{app}/appPriceSchedule")
    zeigen("Laufende Einreichungen", "v1/reviewSubmissions",
           **{"filter[app]": app, "limit": 10})

    print("\nGelesen, nicht geraten. Was oben mit 404 antwortet, gibt es nicht.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
