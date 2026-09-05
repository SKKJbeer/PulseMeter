#!/usr/bin/env python3
"""Schaltet die Berechtigungen der App-IDs über Apples Schnittstelle frei.

App-Gruppe, iCloud und Push müssen an der App-ID im Entwicklerportal
freigeschaltet sein, sonst lehnt Apple das Verteilprofil ab. Bisher stand in
`docs/07-v1-plan.md`, das sei Handarbeit im Portal. Dieses Skript versucht es
über dieselbe Schnittstelle, über die schon Zertifikat und Profile kommen.

**Es bricht nie ab.** Ein Auslieferungslauf darf daran nicht scheitern: Was
sich nicht setzen lässt, wird benannt, und der Bau fährt mit leeren
Berechtigungen weiter — so wie bisher. Erst wenn am Ende wirklich alles steht,
meldet das Skript `bereit=ja`, und nur dann zieht der Bau die
Berechtigungsdateien an.

**Was dieses Skript prüfen kann und was nicht.** Die *Fähigkeiten* an einer
App-ID — `APP_GROUPS`, `ICLOUD`, `PUSH_NOTIFICATIONS` — stehen in der
Schnittstelle und werden gesetzt und nachgelesen. Die *Kennungen* dahinter, die
App-Gruppe `group.…` und der iCloud-Behälter `iCloud.…`, gibt es dort **nicht**:
Jeder Pfad darauf antwortet 404, unabhängig davon, ob sie angelegt sind. Sie
zählen deshalb nicht gegen `bereit`, sondern werden als „nicht prüfbar"
ausgewiesen. Die Probe darauf ist das Signieren.

**Warum das Ergebnis nachgelesen und nicht geglaubt wird.** Eine Antwort mit
201 sagt, dass Apple die Anfrage angenommen hat. Ob die App-ID danach das
kann, was die Berechtigungsdatei verlangt, steht in der App-ID — also wird sie
am Ende noch einmal gelesen. Ein Bau, der auf einer Vermutung signiert,
scheitert zwanzig Minuten später an einer Meldung, die den Grund nicht nennt.

Aufruf (Umgebung wie bei `asc-profil.py`):

    ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_P8=… python3 scripts/asc-berechtigungen.py
"""

import json
import os
import sys
import time

import jwt
import requests

BASIS = "https://api.appstoreconnect.apple.com/v1"

APP = "de.karjoth.pulsemeter"
WIDGET = "de.karjoth.pulsemeter.widget"
GRUPPE = "group.de.karjoth.pulsemeter"
BEHAELTER = "iCloud.de.karjoth.pulsemeter"

# Was jede Kennung können muss, und warum — die Begründungen stehen ausführlich
# in `App/PulseMeter.entitlements`.
GEBRAUCHT = {
    APP: ["APP_GROUPS", "ICLOUD", "PUSH_NOTIFICATIONS"],
    # Das Widget liest nur, was die App im gemeinsamen Ordner hinterlegt hat.
    # iCloud und Push braucht es nicht, und eine Berechtigung, die niemand
    # benutzt, ist eine, die jemand erklären muss.
    WIDGET: ["APP_GROUPS"],
}

offen: list[str] = []
getan: list[str] = []

# **„Weiß ich nicht" ist nicht „fehlt", und die Unterscheidung hat einen Bau
# gekostet.** App-Gruppe und iCloud-Behälter gibt es in Apples Schnittstelle
# nicht — jede Abfrage darauf antwortet mit 404, **egal ob sie angelegt sind
# oder nicht**. Der 404 kommt vom Pfad, nicht vom Gegenstand.
#
# Bis 0.108.1 landeten beide trotzdem in `offen`, und damit konnte `bereit`
# niemals „ja" werden. Solange das nur eine Warnung war, fiel es nicht auf;
# als daraus in 0.107.2 ein Torwächter wurde, sperrte er jeden Bau aus — auch
# nachdem der Gründer beide Kennungen angelegt hatte. Eine Bedingung, die nie
# eintreten kann, sieht aus wie eine, die zu Recht nicht eintritt.
#
# Was hier nicht prüfbar ist, wird deshalb benannt und **nicht gewertet**. Die
# echte Probe ist der Bau selbst: Fehlt eine der beiden Kennungen wirklich,
# passt das Verteilprofil nicht zur Berechtigungsdatei, und `xcodebuild
# archive` bricht ab. Das ist die Aussage, die zählt.
unbekannt: list[str] = []


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
        """GET, das eine Fehlantwort zurückgibt statt den Lauf zu beenden."""
        antwort = requests.get(f"{BASIS}/{pfad}", headers=self.kopf,
                               params=werte, timeout=30)
        return antwort.status_code, antwort

    def anlegen(self, pfad: str, koerper: dict):
        antwort = requests.post(f"{BASIS}/{pfad}", headers=self.kopf,
                                data=json.dumps(koerper), timeout=30)
        return antwort.status_code, antwort


def kurz(antwort) -> str:
    """Apples Fehlertext, auf das Lesbare eingedampft."""
    try:
        fehler = antwort.json().get("errors", [])
        if fehler:
            erster = fehler[0]
            return f"{erster.get('title', '')} — {erster.get('detail', '')}"[:200]
    except ValueError:
        pass
    return antwort.text[:200]


def kennung_finden(apple: Apple, bezeichner: str):
    stand, antwort = apple.holen("bundleIds",
                                 **{"filter[identifier]": bezeichner, "limit": 200})
    if stand != 200:
        offen.append(f"Kennungen ließen sich nicht lesen ({stand}): {kurz(antwort)}")
        return None
    # Genau vergleichen: Apple filtert als Präfix, `de.karjoth.pulsemeter`
    # liefert also auch `.widget` mit. Dieselbe Falle wie in `asc-profil.py`.
    for eintrag in antwort.json().get("data", []):
        if eintrag["attributes"]["identifier"] == bezeichner:
            return eintrag["id"]
    offen.append(f"Die App-ID {bezeichner} ist bei Apple nicht registriert")
    return None


def vorhandene(apple: Apple, kennung: str) -> tuple[bool, set[str]]:
    """Was die App-ID kann — und ob die Frage überhaupt beantwortet wurde.

    **Der Rückgabewert hat zwei Teile, und der erste ist der wichtigere.**
    Bau 18 meldete „fehlt weiterhin APP_GROUPS, ICLOUD, PUSH_NOTIFICATIONS",
    obwohl Apple alle drei mit 200 angenommen hatte. Die Ursache lag hier: Bei
    einer Fehlantwort gab diese Funktion eine leere Menge zurück, und leer
    heißt für den Aufrufer „nichts eingeschaltet". „Konnte ich nicht lesen"
    und „ist nicht da" sahen also gleich aus — und das ist dieselbe
    Fehlerklasse wie zwei Zeiträume, die man gegeneinanderhält: zwei
    verschiedene Sachverhalte unter einer Zahl.

    Zwei Wege, weil nicht feststeht, welchen Apple für diese Beziehung
    anbietet. Der erste, der antwortet, gilt.
    """
    stand, antwort = apple.holen(f"bundleIds/{kennung}/bundleIdCapabilities",
                                 **{"limit": 200})
    if stand == 200:
        return True, {e["attributes"]["capabilityType"]
                      for e in antwort.json().get("data", [])
                      if e.get("attributes", {}).get("capabilityType")}
    erster = f"{stand} — {kurz(antwort)}"

    stand, antwort = apple.holen(f"bundleIds/{kennung}",
                                 **{"include": "bundleIdCapabilities"})
    if stand == 200:
        return True, {e.get("attributes", {}).get("capabilityType")
                      for e in antwort.json().get("included", [])
                      if e.get("attributes", {}).get("capabilityType")}

    offen.append(f"Was {kennung} kann, ließ sich nicht nachlesen "
                 f"(Beziehung: {erster}; eingebettet: {stand}) — "
                 "gesetzt wurde es, nachgeprüft ist es nicht")
    return False, set()


def einschalten(apple: Apple, kennung: str, bezeichner: str, art: str) -> None:
    koerper = {"data": {
        "type": "bundleIdCapabilities",
        "attributes": {"capabilityType": art},
        "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": kennung}}},
    }}
    # CloudKit statt der alten Ablage: `XCODE_6` ist die Fassung, die
    # `com.apple.developer.icloud-services = CloudKit` verlangt. Ohne die
    # Angabe legt Apple die App-ID auf die Vorgabe fest, und die passt dann
    # nicht zur Berechtigungsdatei.
    if art == "ICLOUD":
        koerper["data"]["attributes"]["settings"] = [
            {"key": "ICLOUD_VERSION", "options": [{"key": "XCODE_6"}]}
        ]

    stand, antwort = apple.anlegen("bundleIdCapabilities", koerper)
    if stand in (200, 201):
        getan.append(f"{bezeichner}: {art} eingeschaltet")
        return
    # 409 heißt hier meist „steht schon" — kein Fehler, sondern der Zielzustand.
    if stand == 409:
        getan.append(f"{bezeichner}: {art} stand schon")
        return
    if art == "ICLOUD" and stand == 400:
        # Noch einmal ohne Feineinstellung: Wenn Apple die Fassung nicht
        # entgegennimmt, ist eine eingeschaltete iCloud immer noch besser als
        # keine — und die Fassung steht dann im Portal auf der Vorgabe.
        koerper["data"]["attributes"].pop("settings", None)
        stand, antwort = apple.anlegen("bundleIdCapabilities", koerper)
        if stand in (200, 201, 409):
            getan.append(f"{bezeichner}: ICLOUD eingeschaltet (ohne Fassungsangabe)")
            return
    offen.append(f"{bezeichner}: {art} ließ sich nicht setzen ({stand}) — {kurz(antwort)}")


def sammlung(apple: Apple, pfad: str, bezeichner: str, name: str):
    """Eine App-Gruppe oder einen iCloud-Behälter suchen, sonst anlegen.

    **Beides ist in Apples öffentlicher Schnittstelle nicht dokumentiert.** Der
    Versuch steht hier trotzdem: Er kostet zwei Anfragen, und die Antwort sagt
    schwarz auf weiß, ob es geht — das ist mehr wert als eine Vermutung im
    Dokument. Geht es nicht, wandert genau diese eine Stelle in die Liste
    dessen, was jemand im Portal anklicken muss.
    """
    stand, antwort = apple.holen(pfad, **{"filter[identifier]": bezeichner, "limit": 200})
    if stand == 200:
        for eintrag in antwort.json().get("data", []):
            if eintrag["attributes"].get("identifier") == bezeichner:
                getan.append(f"{bezeichner} ist angelegt")
                return eintrag["id"]
    elif stand in (404, 401, 403):
        # Nicht in `offen`: Der Fehlercode gilt dem Pfad, nicht der Kennung —
        # siehe die Begründung bei `unbekannt` oben. Ob sie existiert, sagt
        # erst der Bau.
        unbekannt.append(f"{bezeichner}: über die Schnittstelle nicht prüfbar "
                         f"({stand}) — im Portal anzulegen, falls es sie noch "
                         f"nicht gibt")
        return None

    stand, antwort = apple.anlegen(pfad, {"data": {
        "type": pfad,
        "attributes": {"identifier": bezeichner, "name": name},
    }})
    if stand in (200, 201):
        getan.append(f"{bezeichner} angelegt")
        return antwort.json().get("data", {}).get("id")
    offen.append(f"{bezeichner} ließ sich nicht anlegen ({stand}) — {kurz(antwort)}")
    return None


def verknuepfen(apple: Apple, kennung: str, bezeichner: str,
                pfad: str, ziel_typ: str, ziel_id: str) -> None:
    """Die Gruppe oder den Behälter an der App-ID eintragen.

    Ohne diesen Schritt trägt das Verteilprofil die Berechtigung ohne Inhalt:
    „App-Gruppen: ja, welche: keine". Die Signierung geht dann durch und die
    App findet den gemeinsamen Ordner trotzdem nicht.
    """
    if not ziel_id:
        return
    stand, antwort = apple.anlegen(
        f"bundleIds/{kennung}/relationships/{pfad}",
        {"data": [{"type": ziel_typ, "id": ziel_id}]})
    if stand in (200, 201, 204, 409):
        getan.append(f"{bezeichner}: {pfad} zugeordnet")
        return
    offen.append(f"{bezeichner}: {pfad} ließ sich nicht zuordnen ({stand}) "
                 f"— {kurz(antwort)}")


def main() -> None:
    fehlend = [n for n in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_P8")
               if not os.environ.get(n)]
    if fehlend:
        print(f"::warning::Ohne {', '.join(fehlend)} lässt sich nichts setzen.")
        melden(bereit=False)
        return

    apple = Apple(anmeldung())

    gruppe = sammlung(apple, "appGroups", GRUPPE, "PulseMeter")
    behaelter = sammlung(apple, "cloudContainers", BEHAELTER, "PulseMeter")

    for bezeichner, arten in GEBRAUCHT.items():
        kennung = kennung_finden(apple, bezeichner)
        if not kennung:
            continue
        _, steht = vorhandene(apple, kennung)
        for art in arten:
            if art in steht:
                getan.append(f"{bezeichner}: {art} stand schon")
                continue
            einschalten(apple, kennung, bezeichner, art)
        if "APP_GROUPS" in arten:
            verknuepfen(apple, kennung, bezeichner, "appGroups", "appGroups", gruppe)
        if "ICLOUD" in arten:
            verknuepfen(apple, kennung, bezeichner, "cloudContainers",
                        "cloudContainers", behaelter)

    # **Nachlesen statt glauben.** Was oben angenommen wurde, muss jetzt in der
    # App-ID stehen — sonst signiert der Bau gegen eine Vermutung.
    vollstaendig = not offen
    for bezeichner, arten in GEBRAUCHT.items():
        kennung = kennung_finden(apple, bezeichner)
        if not kennung:
            vollstaendig = False
            continue
        lesbar, steht = vorhandene(apple, kennung)
        if not lesbar:
            # Nicht als „fehlt" melden. Was hier fehlt, ist die Auskunft.
            vollstaendig = False
            continue
        fehlt = [a for a in arten if a not in steht]
        if fehlt:
            vollstaendig = False
            offen.append(f"{bezeichner}: fehlt weiterhin {', '.join(fehlt)}")
        else:
            getan.append(f"{bezeichner}: nachgelesen, alles steht")

    melden(bereit=vollstaendig)


def melden(bereit: bool) -> None:
    if getan:
        print("Gesetzt:")
        for zeile in dict.fromkeys(getan):
            print(f"  · {zeile}")
    if offen:
        print("\nOffen — das muss jemand im Portal anklicken:")
        for zeile in dict.fromkeys(offen):
            print(f"  · {zeile}")
        print("\n  https://developer.apple.com/account/resources/identifiers/list")
    if unbekannt:
        print("\nNicht prüfbar — Apple hat dafür keine Schnittstelle:")
        for zeile in dict.fromkeys(unbekannt):
            print(f"  · {zeile}")
        print("  Ob es sie gibt, sagt der Bau: Ohne sie passt das Verteilprofil "
              "nicht zur Berechtigungsdatei.")

    if bereit:
        print("\n::notice::Die Berechtigungen an den App-IDs stehen. Der Bau "
              "nimmt die Berechtigungsdateien mit; ob App-Gruppe und "
              "iCloud-Behälter wirklich angelegt sind, zeigt das Signieren.")
    else:
        print("\n::warning::Die Berechtigungen stehen noch nicht vollständig. "
              "Der Bau fährt ohne sie — die App läuft, nur Widget und "
              "iCloud-Abgleich bleiben aus.")

    ausgabe = os.environ.get("GITHUB_OUTPUT")
    if ausgabe:
        with open(ausgabe, "a", encoding="utf-8") as datei:
            datei.write(f"bereit={'ja' if bereit else 'nein'}\n")

    # Immer 0: Dieses Skript ist eine Verbesserung, kein Torwächter. Was es
    # nicht schafft, hat der Bau vorher auch nicht gehabt.
    sys.exit(0)


if __name__ == "__main__":
    main()
