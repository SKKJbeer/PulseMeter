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

    # **Und was in jeder einzelnen davon liegt.**
    #
    # Bis heute endete diese Aufstellung bei „zwei Einreichungen stehen offen".
    # Das ist eine Anzahl, keine Auskunft — dieselbe Falle, die dieses Projekt
    # schon dreimal hatte. Entscheidend ist, **welche** von beiden die Fassung
    # hält: Eine Fassung darf nur in einer Einreichung liegen, und der Versuch,
    # sie einer zweiten hinzuzufügen, scheitert mit einer Meldung, die von der
    # Fassung spricht und nicht von der Einreichung.
    #
    # `asc-einreichen.py` nimmt die Einreichung mit den meisten Einträgen und
    # sieht in die andere nie hinein. Ob das die richtige Wahl ist, entscheidet
    # sich hier.
    stand, antwort = holen("v1/reviewSubmissions",
                           **{"filter[app]": app, "limit": 10})
    for eintrag in (antwort.json().get("data", []) if stand == 200 else []):
        kennung = eintrag["id"]
        zustand = (eintrag.get("attributes") or {}).get("state", "?")
        print(f"\n── Einträge der Einreichung {kennung[:8]} ({zustand})")
        # **Ohne `include` liefert die Liste die Beziehungen nicht mit.** Der
        # erste Anlauf gab hier fünfmal „unbekannt" aus — und genau derselbe
        # Ausdruck entschied in `asc-einreichen.py` darüber, ob die Fassung
        # schon in der Einreichung liegt. Er war dort immer falsch.
        #
        # **Der zweite Anlauf mit `include` kam mit 400 zurück.** Welche Namen
        # Apple hier zulässt, steht in keiner Anleitung, die ich habe — also
        # wird nicht die nächste Schreibweise geraten, sondern jede Variante
        # einmal versucht und **Apples Einwand ausgedruckt**. Der nennt in
        # aller Regel das Feld, an dem es liegt.
        koerper = None
        for versuch in ({"limit": 50, "include": "appStoreVersion"},
                        {"limit": 50,
                         "fields[reviewSubmissionItems]": "appStoreVersion,state"},
                        {"limit": 50}):
            s, a = holen(f"v1/reviewSubmissions/{kennung}/items", **versuch)
            beschriftung = versuch.get("include") or \
                versuch.get("fields[reviewSubmissionItems]") or "ohne Zusatz"
            if s == 200:
                print(f"   gelesen mit: {beschriftung}")
                koerper = a.json()
                break
            einwand = ""
            try:
                einwand = "; ".join(f"{f.get('title','')}: {f.get('detail','')}"
                                    for f in a.json().get("errors", [])[:2])
            except ValueError:
                einwand = a.text[:160]
            print(f"   {beschriftung} → {s} — {einwand[:200]}")
        if koerper is None:
            print("   auf keinem Weg lesbar")
            continue
        posten = koerper.get("data", [])
        if not posten:
            print("   leer — ein Überbleibsel eines gescheiterten Laufs")
            continue
        beigefuegt = {e["id"]: e for e in koerper.get("included", [])}
        # **Roh ausgeben, nicht nach bekannten Namen suchen.**
        #
        # Der Anlauf davor prüfte eine Liste von Beziehungsnamen und schrieb
        # fünfmal „unbekannt" — dieselbe Sackgasse wie im Einreichskript: Eine
        # Bedingung, die nie zutrifft, sieht aus wie eine, die zu Recht nicht
        # zutrifft. Was der Eintrag *tatsächlich* enthält, sagt nur er selbst.
        for p in posten:
            print(f"   · {json.dumps(p, ensure_ascii=False)[:400]}")
        # Und unabhängig davon, was oben stand: was Apple beigefügt hat.
        for kennung2, e in beigefuegt.items():
            merkmale = {k: v for k, v in (e.get("attributes") or {}).items()
                        if k in ("versionString", "name", "productId", "state")}
            print(f"   ⇒ beigefügt: {e.get('type')} {kennung2[:8]} {merkmale}")

    print("\nGelesen, nicht geraten. Was oben mit 404 antwortet, gibt es nicht.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
