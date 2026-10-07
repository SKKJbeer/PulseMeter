#!/usr/bin/env python3
"""Sagt, ob ein App-Store-Connect-Schlüssel die Rolle Admin hat. Nur das.

Apple nennt die Rolle eines Schlüssels nirgends. Es gibt aber Anfragen, die
nur Admin (und der Kontoinhaber) stellen dürfen: die Liste der Nutzer des Teams
und die der offenen Einladungen. **Beide** müssen mit 200 antworten, sonst gilt
der Schlüssel nicht als Admin. Mit der Nutzerliste allein war der Beweis am
7. Oktober zu schwach; die Einladungen sind es, die ihn tragen. Mehr als die
Statuscodes wird nicht gelesen.

**Ausgegeben wird nur der Statuscode und ein Wort.** Die Antwort enthält die
Namen und Mailadressen des Teams, und dieser Lauf steht in einem öffentlichen
Repository. Deshalb wird der Antworttext nie ausgegeben, auch nicht im Fehler.

Umgebung: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8.
Ausgang: 0 = Admin, 1 = kein Admin oder nicht prüfbar.
"""
import os
import sys
import time

import jwt
import requests


def main() -> int:
    try:
        kennung, aussteller, schluessel = (os.environ[n] for n in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_P8"))
    except KeyError:
        print("unvollständig")
        return 1
    if not (kennung and aussteller and schluessel):
        print("unvollständig")
        return 1
    jetzt = int(time.time())
    try:
        token = jwt.encode({"iss": aussteller, "iat": jetzt, "exp": jetzt + 600,
                            "aud": "appstoreconnect-v1"},
                           schluessel, algorithm="ES256", headers={"kid": kennung})
    except Exception:
        # Meist ein p8 mit zerhackten Zeilenumbrüchen. Den Fehlertext nicht
        # ausgeben: Er kann Teile des Schlüssels enthalten.
        print("Schlüssel nicht lesbar")
        return 1
    codes = []
    for pfad in ("/v1/users", "/v1/userInvitations"):
        antwort = requests.get("https://api.appstoreconnect.apple.com" + pfad,
                               params={"limit": 1},
                               headers={"Authorization": f"Bearer {token}"}, timeout=30)
        codes.append(antwort.status_code)
    if codes == [200, 200]:
        print("Admin (200, 200)")
        return 0
    if 403 in codes:
        print(f"kein Admin ({codes[0]}, {codes[1]})")
    elif 401 in codes:
        print("von Apple nicht angenommen (401)")
    else:
        print(f"nicht prüfbar ({codes[0]}, {codes[1]})")
    return 1


if __name__ == "__main__":
    sys.exit(main())
