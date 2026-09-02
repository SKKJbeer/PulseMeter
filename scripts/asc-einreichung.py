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

import hashlib
import json
import os
import pathlib
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
    # **Nicht auf `###` festgenagelt.** Die Store-Texte stehen unter dritter
    # Ebene, die Hinweise für die Prüfung unter „## 5. Hinweise für die
    # Prüfung" — mit Nummer davor. Wer nur eine Schreibweise sucht, bekommt
    # stillschweigend einen leeren Text zurück und trägt nichts ein.
    kopf = re.compile(r"^#{2,4} (?:\d+\. )?" + re.escape(ueberschrift) + r"\s*$",
                      re.M)
    treffer = kopf.search(inhalt)
    if treffer is None:
        return ""
    block = re.search(r"```\n(.*?)```", inhalt[treffer.end():], re.S)
    return block.group(1).strip() if block else ""


# Aus derselben Datei, Abschnitt 2 „Einordnung".
KATEGORIE_HAUPT = "UTILITIES"
KATEGORIE_ZWEIT = "FINANCE"

WEBSITE = "https://zaehlora.pages.dev"
DATENSCHUTZ = f"{WEBSITE}/datenschutz"
SUPPORT = f"{WEBSITE}/hilfe"


# In Apples Fehlertexten steht das Feld in einfachen Anführungszeichen.
# **Und zwar unabhängig von der Großschreibung.** Apple schreibt einmal
# „Unexpected json type provided for attribute 'messagingAndChat'" und einmal
# „Attribute 'whatsNew' cannot be edited" — dasselbe Wort, zwei Schreibweisen.
# Das Muster traf nur die kleine, und der zweite Einwand blieb ungehört.
FELD_IM_FEHLER = re.compile(r"attribute '([A-Za-z]+)'", re.I)


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

        # **Ein genanntes Feld, das gar nicht mitgeschickt wurde, fehlt.** Die
        # beiden bekannten Einwände nennen ein Feld, das dabei war — falscher
        # Typ, nicht änderbar. Dieser hier nennt eines, das fehlt, und dann
        # hilft weder Umdrehen noch Weglassen. Er wird deshalb als das gemeldet,
        # was er ist: eine fehlende Angabe, mit Namen.
        if treffer and treffer.group(1) not in bleibt:
            offen.append(f"{was}: Apple verlangt zusätzlich "
                         f"„{treffer.group(1)}“ — {text}")
            return False

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
    #
    # **Felder, die eine Adresse wollen, bekommen keine Stufe.** Der zweite
    # Lauf brach mit „must be a valid RFC 3986 URI" ab, und diesmal nannte
    # Apple das Feld nicht — es blieb nur der Name selbst als Hinweis. Alles
    # mit `Url` oder `Uri` im Namen bleibt deshalb außen vor.
    felder = list((alter.get("attributes") or {}).keys())
    getan.append(f"Altersfreigabe führt {len(felder)} Felder: {', '.join(sorted(felder))}")
    antworten = {name: "NONE" for name in felder
                 if name not in ("ageRatingOverride", "kidsAgeBand")
                 and "url" not in name.lower() and "uri" not in name.lower()}
    setzen(apple, "v1/ageRatingDeclarations", "ageRatingDeclarations",
           alter["id"], antworten, "Altersfreigabe 4+")


# **Welche Größe der Store verlangt.** Apple nimmt für eine neue Einreichung
# das 6,9-Zoll-Format; die Simulator-Bilder kommen von einem iPhone 17 Pro Max
# und haben genau diese Auflösung. Hochskalieren wäre sichtbar — deshalb kommen
# sie seit 0.96.3 zusätzlich in voller Größe in den Zweig `screenshots`.
#
# **Die Kennung heißt trotzdem `67`, und das sieht wie ein Fehler aus.** Sie ist
# keiner: Am 2. September nachgesehen, was tatsächlich bei Apple liegt — ein
# Satz `APP_IPHONE_67` mit fünf Bildern, alle auf `COMPLETE`. Unter dieser
# Kennung nimmt Apple die 6,9-Zoll-Bilder an. Wer die Zeile für einen
# Tippfehler hält und sie ändert, verliert den Satz.
BILDSCHIRM = "APP_IPHONE_67"

# Die Reihenfolge ist die Reihenfolge auf der Store-Seite. Erst das, was die
# App tut, dann wofür sie es tut.
BILDER = [
    ("screenshot-light.jpg", "Übersicht"),
    ("screenshot-capture-light.jpg", "Ablesen"),
    ("screenshot-verlauf-light.jpg", "Verlauf"),
    ("screenshot-bericht-light.jpg", "Bericht"),
    ("screenshot-zaehler-light.jpg", "Zähler"),
]


def bild_hochladen(apple: Apple, satz_id: str, pfad: str, nummer: int) -> str | None:
    """Anmelden, Bytes schicken, Vollzug melden — wie beim Prüfbild der Käufe."""
    daten = pathlib.Path(pfad).read_bytes()
    stand, antwort = apple.anlegen("v1/appScreenshots", {"data": {
        "type": "appScreenshots",
        "attributes": {"fileSize": len(daten),
                       "fileName": os.path.basename(pfad)},
        "relationships": {"appScreenshotSet": {
            "data": {"type": "appScreenshotSets", "id": satz_id}}},
    }})
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

    stand, antwort = apple.aendern(f"v1/appScreenshots/{bild_id}", {"data": {
        "type": "appScreenshots", "id": bild_id,
        "attributes": {"uploaded": True,
                       "sourceFileChecksum": hashlib.md5(daten).hexdigest()},
    }})
    if stand not in (200, 201):
        return f"nicht bestätigt ({stand}) — {kurz(antwort)}"
    return None


def bilder_fuellen(apple: Apple, ort_id: str) -> None:
    """Die Bildschirmfotos aus dem Zweig `screenshots`, in voller Größe."""
    ordner = os.path.join(os.path.dirname(__file__), "..", "build", "store")
    if not os.path.isdir(ordner):
        offen.append("Bildschirmfotos: der Ordner build/store fehlt — "
                     "der Ablauf holt ihn aus dem Zweig screenshots")
        return

    stand, satz = erste(apple, f"v1/appStoreVersionLocalizations/{ort_id}"
                                "/appScreenshotSets", **{"limit": 20})
    if satz is None:
        stand, antwort = apple.anlegen("v1/appScreenshotSets", {"data": {
            "type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": BILDSCHIRM},
            "relationships": {"appStoreVersionLocalization": {
                "data": {"type": "appStoreVersionLocalizations", "id": ort_id}}},
        }})
        if stand not in (200, 201):
            offen.append(f"Bildersatz ließ sich nicht anlegen ({stand}) "
                         f"— {kurz(antwort)}")
            return
        satz = antwort.json()["data"]

    # **Nicht doppelt hochladen.** Ein zweiter Lauf soll die Seite nicht mit
    # denselben Bildern zweimal füllen.
    stand, vorhanden = apple.holen(f"v1/appScreenshotSets/{satz['id']}/appScreenshots",
                                   **{"limit": 20})
    schon = {e["attributes"].get("fileName")
             for e in (vorhanden.json().get("data", []) if stand == 200 else [])}

    for nummer, (datei, was) in enumerate(BILDER, start=1):
        if datei in schon:
            getan.append(f"Bild {nummer} ({was}): stand schon")
            continue
        pfad = os.path.join(ordner, datei)
        if not os.path.isfile(pfad):
            offen.append(f"Bild {nummer} ({was}): {datei} liegt nicht im Zweig")
            continue
        fehler = bild_hochladen(apple, satz["id"], pfad, nummer)
        if fehler:
            offen.append(f"Bild {nummer} ({was}): {fehler}")
        else:
            getan.append(f"Bild {nummer} ({was}): hochgeladen")


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

    bilder_fuellen(apple, ort["id"])
    pruefung_fuellen(apple, fassung["id"])


# **Der Hinweistext an die Prüfung stand nur im Dokument.** Der Lauf trug ihn
# nirgends ein und fragte auch nicht danach — 15 Punkte standen grün, und
# dieser fehlte, ohne dass ihn jemand vermisst hätte. Ein Prüfer, der eine
# leere App startet und nicht weiß, wo Daten herkommen, bewertet eine leere
# App; genau davor warnt der Absatz unter dem Text seit Wochen.
#
# Name und E-Mail kommen aus dem Impressum — vom Gründer selbst als Quelle
# benannt: „kontakt kennst du von meinem impressum der homepage". Sie werden
# von dort gelesen und nicht abgetippt: Ein zweites Mal hingeschrieben, laufen
# beide auseinander, und im Impressum steht die Fassung, die rechtlich gilt.
# **Die Telefonnummer steht dort nicht.** Sie wird deshalb auch nicht gesetzt.
def kontakt_aus_impressum() -> tuple[str, str, str]:
    pfad = os.path.join(os.path.dirname(__file__), "..", "docs", "website",
                        "impressum.html")
    try:
        with open(pfad, encoding="utf-8") as datei:
            inhalt = datei.read()
    except OSError:
        return "", "", ""

    block = re.search(r'<address class="anschrift">(.*?)</address>', inhalt, re.S)
    if block is None:
        return "", "", ""

    zeilen = [re.sub(r"<[^>]+>", "", z).strip()
              for z in block.group(1).split("<br>")]
    name = next((z for z in zeilen if z), "")
    post = re.search(r"mailto:([^\"']+)", block.group(1))
    if " " not in name or post is None:
        return "", "", ""
    vorname, _, nachname = name.rpartition(" ")
    return vorname, nachname, post.group(1)


def pruefung_fuellen(apple: Apple, fassung_id: str) -> None:
    text = store_text("Hinweise für die Prüfung")
    if not text:
        offen.append("Hinweise für die Prüfung: kein Text in docs/09-appstore.md")
        return

    vorname, nachname, post = kontakt_aus_impressum()
    if not post:
        offen.append("Kontakt: aus dem Impressum ließ sich nichts lesen")

    # **Apple nimmt den Kontakt nur vollständig.** Der erste Versuch, Name und
    # E-Mail allein einzutragen, kam mit 409 zurück:
    #
    #     You must provide a value for the attribute 'contactPhone'
    #
    # Ohne Nummer wandert also auch der Name nicht hinüber — und die Nummer
    # steht nicht im Impressum. Sie kommt deshalb aus einem Geheimnis und nicht
    # aus dem Repository: Eine private Telefonnummer gehört in keine Datei, die
    # jemand später einmal öffentlich stellt.
    #
    # **Die E-Mail darf abweichen.** Der Gründer hat für die Prüfung eine
    # andere genannt als die im Impressum. Das ist zulässig — der rechtliche
    # Kontakt und der, unter dem ein Prüfer nachfragt, müssen nicht derselbe
    # sein. Steht das Geheimnis, gilt es; sonst bleibt es beim Impressum.
    werte = {"notes": text, "demoAccountRequired": False}
    fon = os.environ.get("ASC_KONTAKT_TELEFON", "").strip()
    post = os.environ.get("ASC_KONTAKT_MAIL", "").strip() or post
    if fon and post:
        werte.update({"contactFirstName": vorname, "contactLastName": nachname,
                      "contactEmail": post, "contactPhone": fon})
    else:
        gehoert_ihm.append(
            "Telefonnummer für die Prüfung — als Geheimnis "
            "ASC_KONTAKT_TELEFON hinterlegen; Apple nimmt Name und E-Mail "
            "nicht ohne sie an")

    stand, pruefung = erste(apple,
                            f"v1/appStoreVersions/{fassung_id}/appStoreReviewDetail")
    was = f"Hinweise für die Prüfung ({len(text)} Zeichen)"
    if "contactPhone" in werte:
        was += f" und Kontakt {vorname} {nachname}"

    if pruefung is None:
        stand, antwort = apple.anlegen("v1/appStoreReviewDetails", {"data": {
            "type": "appStoreReviewDetails",
            "attributes": {k: v for k, v in werte.items() if v != ""},
            "relationships": {"appStoreVersion": {
                "data": {"type": "appStoreVersions", "id": fassung_id}}},
        }})
        if stand in (200, 201):
            getan.append(f"{was} angelegt")
        else:
            offen.append(f"{was}: ging nicht ({stand}) — {kurz(antwort)}")
        return

    setzen(apple, "v1/appStoreReviewDetails", "appStoreReviewDetails",
           pruefung["id"], werte, was)


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

    felder = [("description", "Beschreibung"),
              ("keywords", "Schlagworte"),
              ("promotionalText", "Werbetext"),
              # Standen als „kann nur der Gründer", solange die Website nicht
              # veröffentlicht war. Sie steht.
              ("supportUrl", "Support-URL"),
              ("marketingUrl", "Marketing-URL")]
    # **„Neue Funktionen" gehört nicht zur ersten Fassung.** Apple lehnt das
    # Feld dort ab — „cannot be edited at this time" —, und das ist richtig: Es
    # gibt nichts, was neu wäre. Als „fehlt" zu melden, was gar nicht sein
    # darf, macht die Liste unbrauchbar.
    if feld(fassung, "versionString") != "1.0":
        felder.insert(3, ("whatsNew", "Neue Funktionen"))

    for name, was in felder:
        wem = None
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
    hinweise = feld(pruefung, "notes") or ""
    pruefe(bool(hinweise.strip()),
           f"Hinweise für die Prüfung ({len(hinweise)} Zeichen)"
           if hinweise else "Hinweise für die Prüfung fehlen")

    # **Ein Punkt, weil Apple den Block nur ganz nimmt.** Ein Versuch mit Name
    # und E-Mail allein kam mit 409 zurück: „You must provide a value for the
    # attribute 'contactPhone'". Die drei Felder getrennt zu melden hieße,
    # Fortschritt zu behaupten, den es bei Apple nicht gibt — dort steht bis
    # zur Nummer gar nichts.
    wer = " ".join(x for x in (feld(pruefung, "contactFirstName"),
                               feld(pruefung, "contactLastName")) if x)
    post = feld(pruefung, "contactEmail") or ""
    fon = feld(pruefung, "contactPhone") or ""
    pruefe(bool(wer and post and fon.strip()),
           f"Kontakt für die Prüfung: {wer}, {post}, {fon}"
           if wer and post and fon.strip() else
           "Kontakt für die Prüfung — Name und E-Mail stehen im Impressum, "
           "die Telefonnummer nicht. Apple nimmt den Block nur vollständig; "
           "als Geheimnis ASC_KONTAKT_TELEFON hinterlegen",
           gehoert_ihm)


def kaeufe_pruefen(apple: Apple, app_id: str) -> None:
    stand, antwort = apple.holen(f"v1/apps/{app_id}/inAppPurchasesV2", **{"limit": 50})
    if stand != 200:
        offen.append(f"Die Käufe sind nicht lesbar ({stand})")
        return
    zustaende = [e["attributes"].get("state", "?")
                 for e in antwort.json().get("data", [])]
    bereit = [z for z in zustaende if z in ("READY_TO_SUBMIT", "APPROVED")]
    pruefe(len(bereit) == 6,
           f"Sechs Käufe bereit ({len(bereit)} von {len(zustaende)}: "
           f"{', '.join(sorted(set(zustaende)))})")


def verfuegbarkeit_pruefen(apple: Apple, app_id: str) -> None:
    stand, plan = erste(apple, f"v1/apps/{app_id}/appPriceSchedule")
    pruefe(plan is not None, f"Preisplan der App (Antwort {stand})")

    # **„Vorhanden" ist auch hier nicht „richtig".** Bis 0.101.0 stand hier nur,
    # ob Apple auf die Frage antwortet. Genau dieser Eintrag war bei 0.87.0
    # schon einmal vorhanden **und leer** — die App war in keinem einzigen Land
    # verkäuflich, und nichts wurde rot. Gezählt wird deshalb, und Deutschland
    # muss darunter sein: Es ist der Laden, für den die Texte geschrieben sind.
    stand, wo = erste(apple, f"v1/apps/{app_id}/appAvailabilityV2")
    if wo is None:
        offen.append(f"Verfügbarkeit nicht lesbar (Antwort {stand})")
    else:
        # **`filter[available]` hat Apple mit 400 abgelehnt.** Der erste Anlauf
        # meldete daraufhin „verkäuflich in 0 Ländern" — richtig gezählt, falsch
        # geschlossen: Die leere Liste kam von der eigenen Anfrage, nicht vom
        # Laden. Genau diese Verwechslung hat schon einmal einen halben Tag
        # gekostet (Baukasten, „Eine richtige Meldung mit einer falschen
        # Ursache"). Gefragt wird jetzt ohne Filter, und was Apple einwendet,
        # steht im Protokoll statt einer Vermutung.
        stand, antwort = apple.holen(
            f"v2/appAvailabilities/{wo['id']}/territoryAvailabilities",
            **{"limit": 200, "include": "territory"})
        if stand != 200:
            offen.append(f"Die Länder ließen sich nicht lesen ({stand}) "
                         f"— {kurz(antwort)}")
            return
        eintraege = antwort.json().get("data", [])
        laender = [e.get("relationships", {}).get("territory", {})
                    .get("data", {}).get("id")
                   for e in eintraege
                   if e.get("attributes", {}).get("available") is not False]
        pruefe(len(laender) > 0 and "DEU" in laender,
               f"Verkäuflich in {len(laender)} Ländern, Deutschland dabei"
               if "DEU" in laender else
               f"Verkäuflich in {len(laender)} von {len(eintraege)} Ländern "
               f"— Deutschland nicht dabei")


def freigabe_pruefen(apple: Apple, app_id: str) -> None:
    """Was nach der Freigabe durch Apple passiert.

    **Kein Mangel, sondern eine Entscheidung — deshalb steht sie beim Gründer.**
    `AFTER_APPROVAL` heißt: Sobald die Prüfung durch ist, steht die App im
    Laden, ohne dass jemand etwas tut. `MANUAL` heißt: Sie wartet auf einen
    Knopfdruck. Wer morgen live sein will, sollte wissen, welches von beidem
    eingestellt ist — der Unterschied ist ein Tag.
    """
    stand, fassung = erste(apple, f"v1/apps/{app_id}/appStoreVersions",
                           **{"limit": 5, "filter[platform]": "IOS"})
    art = feld(fassung, "releaseType") or "—"
    wie = {"AFTER_APPROVAL": "geht sofort nach der Freigabe in den Laden",
           "MANUAL": "wartet nach der Freigabe auf einen Knopfdruck",
           "SCHEDULED": "geht zum eingestellten Termin in den Laden"}
    pruefe(art in wie, f"Nach der Freigabe: {wie.get(art, art)}", gehoert_ihm)


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
    freigabe_pruefen(apple, app_id)

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
