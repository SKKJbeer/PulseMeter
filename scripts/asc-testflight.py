#!/usr/bin/env python3
"""Schreibt „Was ist neu" an den frisch hochgeladenen Bau — und meldet, wann er
bei den Testern steht.

**Warum es das gibt.** Der Ablauf `testflight.yml` fragt seit dem ersten Tag
nach einem Hinweis: „Was ist neu? Steht später bei den Testern." Der Text wurde
entgegengenommen und dann nirgends verwendet. Zehn Bauten lang stand bei den
Testern nichts — ein Versprechen, das die Oberfläche gibt und der Ablauf nicht
hält. Genau das verbietet dieses Projekt sich selbst (`docs/09-appstore.md`).

`altool --upload-app` lädt nur hoch. Die Testhinweise hängen nicht am Paket,
sondern am Bau in App Store Connect, und dorthin führt nur die Schnittstelle.
Sie sind erst erreichbar, wenn Apple den Bau verarbeitet hat — deshalb wird
gewartet.

**Was dieses Skript nicht tut:** Es gibt nichts für externe Tester frei. Das
verlangt eine Beta-Prüfung durch Apple und ist eine Entscheidung, keine
Automatisierung. Für die interne Gruppe — den Gründer auf seinem eigenen Gerät —
ist der Bau nach der Verarbeitung sofort da.

Aus der Umgebung:
  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8   Zugang, wie bei `asc-profil.py`
  PULSE_BUNDLE_ID                         Bezeichner der App
  PULSE_BUILD                             Buildnummer (die Laufnummer)
  PULSE_HINWEIS                           Der Text für die Tester
"""
import json
import os
import re
import sys
import time

import jwt
import requests

BASIS = "https://api.appstoreconnect.apple.com/v1"
SPRACHE = "de-DE"

# Apple braucht für einen Bau meist zwei bis zehn Minuten. Zwanzig sind
# großzügig; länger zu warten kostet nur Läuferzeit, denn der Bau kommt
# ohnehin an — das Skript wäre dann nur nicht mehr dabei.
GEDULD_SEKUNDEN = 20 * 60
ABSTAND_SEKUNDEN = 30


def hinweis(text: str) -> None:
    print(f"::notice::{text}")


def abbruch(text: str, rat: str = "") -> None:
    print(f"::error::{text}")
    if rat:
        print(rat)
    sys.exit(1)


def anmeldung() -> str:
    jetzt = int(time.time())
    try:
        return jwt.encode(
            {"iss": os.environ["ASC_ISSUER_ID"], "iat": jetzt, "exp": jetzt + 900,
             "aud": "appstoreconnect-v1"},
            os.environ["ASC_KEY_P8"],
            algorithm="ES256",
            headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
        )
    except Exception as fehler:  # noqa: BLE001
        abbruch(f"Der Schlüssel ließ sich nicht lesen: {fehler}")
    return ""


class Apple:
    """Spricht mit Apple — und **erneuert dabei seinen Zugang**.

    **Der Zugang lief ab, während gewartet wurde.** In Lauf 33 ist genau das
    passiert: Bau 33 war um 06:02 hochgeladen, die Testhinweise scheiterten um
    06:19 mit

        401 NOT_AUTHORIZED — make sure that it has not expired

    Dieselben Zugangsdaten hatten im selben Lauf drei Minuten vorher noch
    Profile angelegt. Der Fehler war eine Rechnung, die nicht aufging:
    `anmeldung()` signiert für **900** Sekunden, `bau_abwarten` wartet bis zu
    **1200**. Der Kopf wurde einmal gebaut und danach zwanzig Minuten lang
    weiterbenutzt. Solange Apple einen Bau in unter einer Viertelstunde
    verarbeitete, fiel das nie auf.

    Zwei Zahlen, die einander widersprechen und in verschiedenen Dateien
    stehen, laufen irgendwann auseinander. Deshalb wird der Kopf jetzt beim
    Benutzen geprüft und nach zehn Minuten neu signiert — mit fünf Minuten Luft
    zur Gültigkeit. Signieren kostet Mikrosekunden; die Alternative kostet einen
    Bau ohne Hinweistext.
    """

    #: Nach so vielen Sekunden wird neu signiert. Deutlich unter den 900, für
    #: die `anmeldung()` gilt — eine Anfrage darf unterwegs nicht ablaufen.
    FRISCH_NACH = 600

    def __init__(self) -> None:
        self._kopf: dict[str, str] = {}
        self._signiert = 0.0

    @property
    def kopf(self) -> dict[str, str]:
        if time.time() - self._signiert > self.FRISCH_NACH:
            self._kopf = {"Authorization": f"Bearer {anmeldung()}",
                          "Content-Type": "application/json"}
            self._signiert = time.time()
        return self._kopf

    def holen(self, pfad: str, **werte) -> dict:
        antwort = requests.get(f"{BASIS}/{pfad}", headers=self.kopf,
                               params=werte, timeout=30)
        if antwort.status_code != 200:
            abbruch(f"GET {pfad} scheiterte ({antwort.status_code}): "
                    f"{antwort.text[:300]}")
        return antwort.json()

    def schreiben(self, verb: str, pfad: str, koerper: dict):
        return requests.request(verb, f"{BASIS}/{pfad}", headers=self.kopf,
                                data=json.dumps(koerper), timeout=30)


def app_finden(apple: Apple, bezeichner: str) -> str:
    for eintrag in apple.holen("apps", **{"filter[bundleId]": bezeichner,
                                          "limit": 200}).get("data", []):
        # Genau vergleichen: Apple filtert Bezeichner als Präfix, und
        # `de.karjoth.pulsemeter` liefert auch das Widget mit. Dieselbe Falle
        # wie in `asc-profil.py`.
        if eintrag["attributes"]["bundleId"] == bezeichner:
            return eintrag["id"]
    abbruch(f"Zu {bezeichner} gibt es in App Store Connect keine App.",
            "In App Store Connect unter „Apps“ eine App mit genau diesem "
            "Bezeichner anlegen.")
    return ""


def neuester_bau(apple: Apple, app_id: str) -> str:
    """Die Nummer des zuletzt hochgeladenen Baus.

    Damit sich ein Hinweis nachtragen lässt, ohne die Nummer nachzuschlagen —
    im Regelfall ist der gemeinte Bau ohnehin der letzte.
    """
    treffer = apple.holen("builds", **{"filter[app]": app_id,
                                       "sort": "-uploadedDate",
                                       "limit": 1}).get("data", [])
    if not treffer:
        abbruch("Zu dieser App gibt es noch keinen Bau.")
    return treffer[0]["attributes"]["version"]


def bau_abwarten(apple: Apple, app_id: str, nummer: str) -> tuple[str | None, str]:
    """Wartet, bis Apple den Bau verarbeitet hat.

    Gibt die ID zurück und **wie weit es gekommen ist** — denn beides ist zu
    unterscheiden und war es bisher nicht:

    - `„nicht in der Liste"` — Apple kennt den Bau überhaupt nicht. Entweder
      dauert die Aufnahme noch, oder der Upload ist nie angekommen.
    - Ein Zustand wie `PROCESSING` — Apple hat ihn, ist aber nicht fertig.

    Bis 0.113.16 meldete das Skript in beiden Fällen „noch in Verarbeitung".
    Das ist im zweiten Fall wahr und im ersten eine Behauptung über etwas, das
    gar nicht nachgesehen wurde. Bau 33 stand danach über drei Stunden ohne
    Auskunft da, und aus der Meldung ging nicht hervor, ob man warten oder
    nachsehen muss — zwei sehr verschiedene nächste Schritte.
    """
    ende = time.time() + GEDULD_SEKUNDEN
    zuletzt = ""
    gesehen = "nicht in der Liste"
    while time.time() < ende:
        treffer = apple.holen("builds", **{"filter[app]": app_id,
                                           "filter[version]": nummer,
                                           "limit": 1}).get("data", [])
        if treffer:
            zustand = treffer[0]["attributes"]["processingState"]
            gesehen = zustand
            if zustand != zuletzt:
                hinweis(f"Bau {nummer}: {zustand}")
                zuletzt = zustand
            if zustand == "VALID":
                return treffer[0]["id"], zustand
            if zustand in ("INVALID", "FAILED"):
                abbruch(f"Apple hat Bau {nummer} abgelehnt ({zustand}).",
                        "Der Grund steht in App Store Connect unter TestFlight "
                        "beim Bau selbst.")
        time.sleep(ABSTAND_SEKUNDEN)
    return None, gesehen


def zahlen(version: str) -> tuple:
    """`0.93.10` gehört hinter `0.93.9`, nicht davor."""
    return tuple(int(teil) for teil in version.split("."))


def zuletzt_ausgeliefert() -> str:
    """Welche Version im vorigen Bau steckte — laut Auslieferungsprotokoll.

    Die Tabelle dort bekommt ihre Zeile **nach** dem Bau. Beim Bau selbst steht
    also noch der Vorgänger obenauf, und genau das ist die gesuchte Grenze.
    """
    pfad = os.path.join(os.path.dirname(__file__), "..", "docs",
                        "12-auslieferung.md")
    hoechster, version = -1, ""
    try:
        with open(pfad, encoding="utf-8") as datei:
            for zeile in datei:
                treffer = re.match(r"\|\s*(\d+)\s*\|\s*([\d.]+)\s*\|", zeile)
                if treffer and int(treffer.group(1)) > hoechster:
                    hoechster, version = int(treffer.group(1)), treffer.group(2)
    except OSError:
        return ""
    return version


def aus_changelog() -> str:
    """Baut den Hinweis aus allem, was seit dem letzten Bau dazugekommen ist.

    **Warum das hier steht.** Der Ablauf hatte als Vorgabe „Neuer Stand zum
    Ausprobieren." — ein Satz, der nichts sagt. Wer den Lauf ohne Text
    anstößt, und das ist der Normalfall, wenn er von einer Sitzung angestoßen
    wird, liefert damit einen Bau ohne Auskunft. Dieselbe Fehlerklasse wie zehn
    Bauten lang ganz ohne Text, nur höflicher verpackt.

    Das Änderungsprotokoll steht ohnehin schon da und ist verpflichtend
    (Regel 1b). Es zu nehmen ist billiger, als es zweimal zu schreiben.
    """
    pfad = os.path.join(os.path.dirname(__file__), "..", "CHANGELOG.md")
    try:
        with open(pfad, encoding="utf-8") as datei:
            inhalt = datei.read()
    except OSError:
        return ""

    grenze = zuletzt_ausgeliefert()
    stuecke, sammeln = [], []
    for zeile in inhalt.splitlines():
        kopf = re.match(r"^## ([\d.]+) — ", zeile)
        if kopf:
            if sammeln:
                stuecke.append("\n".join(sammeln).strip())
                sammeln = []
            try:
                neuer = not grenze or zahlen(kopf.group(1)) > zahlen(grenze)
            except ValueError:
                neuer = not stuecke          # im Zweifel nur das Neueste
            if not neuer:
                break
            sammeln = [f"{kopf.group(1)}"]
            continue
        if sammeln:
            sammeln.append(zeile)
    if sammeln:
        stuecke.append("\n".join(sammeln).strip())

    text = "\n\n".join(stuecke)
    # Für die Tester lesbar machen: Auszeichnung raus, Aufzählungspunkte rein.
    text = re.sub(r"^---$", "", text, flags=re.M)
    text = re.sub(r"^### ", "", text, flags=re.M)
    text = re.sub(r"^- ", "· ", text, flags=re.M)
    text = text.replace("**", "").replace("`", "")
    text = re.sub(r"\n{3,}", "\n\n", text).strip()
    text = nur_erlaubte_zeichen(text)
    # App Store Connect nimmt höchstens 4000 Zeichen.
    return text[:3990].rstrip() + " …" if len(text) > 4000 else text


# **Apple nimmt nicht jedes Zeichen, und sagt das erst beim Schreiben.**
#
#     Text for whatsNew contains invalid characters:'[─, ✓]'
#
# Gefunden am 3. September: Zwei Einträge im Änderungsprotokoll zitierten
# Protokollzeilen — `── Preisplan` und `✓ Fassung 1.0 hinzugefügt` —, und die
# Aufbereitung entfernte zwar Auszeichnung, aber keine verbotenen Zeichen. Der
# Lauf brach ab, und zwar erst bei Apple.
#
# **Das ist keine Kosmetik, sondern eine Sperre:** Der Bau wäre ohne
# Testhinweise stehen geblieben — genau der Zustand, der hier zehn Bauten lang
# unbemerkt war.
ERSATZ = {"─": "-", "━": "-", "│": "|", "⇢": "->", "⇒": "->", "→": "->",
          "←": "<-", "✓": "+", "✗": "!", "✔": "+", "✘": "!"}

# Was neben Buchstaben, Ziffern und Leerraum stehen bleiben darf. Der
# Mittelpunkt ist Absicht: Er ist seit zehn Bauten der Aufzählungspunkt, und
# Apple hat ihn jedes Mal angenommen.
ERLAUBT = set(".,;:!?()[]{}<>/\\|@#%&*+=_\"'`^~$€§°-–—·…„“”‚‘’")


def nur_erlaubte_zeichen(text: str) -> str:
    """Ersetzt, was Apple ablehnt — und **sagt**, was es entfernt hat.

    Stillschweigend zu löschen wäre schlimmer als der Abbruch: Der Text käme
    durch und niemand wüsste, dass etwas fehlt.
    """
    for zeichen, dafuer in ERSATZ.items():
        text = text.replace(zeichen, dafuer)
    entfernt = sorted({z for z in text
                       if not (z.isalnum() or z.isspace() or z in ERLAUBT)})
    if entfernt:
        print(f"::warning::Zeichen entfernt, die Apple nicht nimmt: "
              f"{' '.join(entfernt)}")
        text = "".join(z for z in text
                       if z.isalnum() or z.isspace() or z in ERLAUBT)
    return text


def text_setzen(apple: Apple, bau_id: str, text: str) -> None:
    """Legt die Testhinweise an — oder ändert sie, falls es sie schon gibt."""
    vorhanden = apple.holen(f"builds/{bau_id}/betaBuildLocalizations",
                            **{"limit": 50}).get("data", [])
    for eintrag in vorhanden:
        if eintrag["attributes"]["locale"] == SPRACHE:
            antwort = apple.schreiben(
                "PATCH", f"betaBuildLocalizations/{eintrag['id']}",
                {"data": {"type": "betaBuildLocalizations", "id": eintrag["id"],
                          "attributes": {"whatsNew": text}}})
            if antwort.status_code not in (200, 204):
                abbruch(f"Die Testhinweise ließen sich nicht ändern "
                        f"({antwort.status_code}): {antwort.text[:300]}")
            return

    antwort = apple.schreiben("POST", "betaBuildLocalizations", {
        "data": {
            "type": "betaBuildLocalizations",
            "attributes": {"locale": SPRACHE, "whatsNew": text},
            "relationships": {"build": {"data": {"type": "builds", "id": bau_id}}},
        }
    })
    if antwort.status_code not in (200, 201):
        abbruch(f"Die Testhinweise ließen sich nicht anlegen "
                f"({antwort.status_code}): {antwort.text[:300]}")


def main() -> None:
    nummer = os.environ.get("PULSE_BUILD", "").strip()
    text = os.environ.get("PULSE_HINWEIS", "").strip()
    bezeichner = os.environ.get("PULSE_BUNDLE_ID", "").strip()
    if not bezeichner:
        abbruch("PULSE_BUNDLE_ID muss gesetzt sein.")
    if not text:
        text = aus_changelog()
        if text:
            hinweis("Kein Text angegeben — genommen wird, was seit dem letzten "
                    "Bau im Änderungsprotokoll steht.")
    if not text:
        hinweis("Kein Hinweistext angegeben — es gibt nichts einzutragen.")
        return

    apple = Apple()
    app_id = app_finden(apple, bezeichner)
    if not nummer:
        nummer = neuester_bau(apple, app_id)
        # **Der neueste ist nicht immer der gemeinte.** Am 10. September lief
        # dieser Nachtrag zwölf Minuten nach dem Hochladen von Bau 33 — und
        # trug den Text an Bau **32** ein, weil 33 in Apples Liste noch gar
        # nicht stand. Der Lauf meldete Erfolg, der neue Bau blieb ohne
        # Auskunft, und der alte bekam seine Hinweise ein zweites Mal.
        #
        # Die Vorgabe bleibt, sie ist im Regelfall richtig. Aber sie sagt jetzt
        # laut, was sie getan hat.
        print(f"::warning::Keine Nummer angegeben — genommen wird der neueste "
              f"Bau, und das ist Bau {nummer}. Ist ein anderer gemeint, gehört "
              f"seine Nummer angegeben.")
    bau, gesehen = bau_abwarten(apple, app_id, nummer)
    if bau is None:
        # **Ob das ein Fehlschlag ist, hängt daran, wozu der Lauf da war.**
        #
        # Im TestFlight-Lauf ist es keiner: Der Bau ist hochgeladen, das war
        # die Aufgabe, und die Verarbeitung dauert heute eben länger als die
        # Geduld dieses Skripts. Rot zu färben hieße, einen gelungenen Upload
        # als gescheitert zu melden.
        #
        # Im Nachtrag-Lauf ist es einer, und zwar der einzige, den es dort
        # geben kann: Dieser Ablauf hat **nur** diese eine Aufgabe. Am
        # 10. September lief er zweimal grün, ohne die Hinweise zu setzen —
        # einmal an Bau 32 statt 33, einmal gar nicht. Beide Male stand
        # „success" daneben, und beide Male hätte niemand nachgesehen.
        #
        # Ein grüner Lauf, der seine einzige Aufgabe nicht erledigt hat, ist
        # schlimmer als ein roter: Er wird geglaubt.
        pflicht = os.environ.get("PULSE_HINWEIS_PFLICHT", "").strip() == "1"
        # Der Zustand gehört in die Meldung, weil er den nächsten Schritt
        # bestimmt: „PROCESSING" heißt warten, „nicht in der Liste" heißt
        # nachsehen, ob der Upload überhaupt angekommen ist.
        satz = (f"Bau {nummer} nach {GEDULD_SEKUNDEN // 60} Minuten: "
                f"{gesehen}. Die Testhinweise stehen damit **nicht**. "
                "Später noch einmal anstoßen oder in App Store Connect "
                "eintragen.")
        if pflicht:
            abbruch(satz)
        hinweis(satz)
        return

    text_setzen(apple, bau, text)
    hinweis(f"Bau {nummer} steht bereit, die Testhinweise sind eingetragen.")


if __name__ == "__main__":
    main()
