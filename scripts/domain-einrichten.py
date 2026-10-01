#!/usr/bin/env python3
"""Hängt eine eigene Domain an die Website: Cloudflare-Zone, DNS, Pages.

    scripts/domain-einrichten.py zaehlora.de

Jeder Schritt sieht erst nach, ob er schon erledigt ist, und tut dann nichts.
Der Ablauf darf also beliebig oft laufen: zum Einrichten, und danach, um
nachzusehen, ob die Domain inzwischen aktiv ist.

Umgebung:
    CLOUDFLARE_DOMAIN_TOKEN   Zone · Zone · Edit, Zone · DNS · Edit (anlegen, Einträge)
    CLOUDFLARE_API_TOKEN      Cloudflare Pages · Edit (Domain an die Website hängen)
    CLOUDFLARE_ACCOUNT_ID
    NETCUP_KUNDENNUMMER, NETCUP_API_KEY, NETCUP_API_PASSWORT   (freiwillig)

**Warum zwei Cloudflare-Schlüssel.** Der zum Hochladen der Website darf genau
das, und so soll es bleiben: Er läuft bei jeder Änderung. Der für Domains
läuft nur hier.

**Die Nameserver bei netcup.** Sie werden beim Anbieter der Domain eingetragen,
nicht bei Cloudflare. netcups Schnittstelle erlaubt das nach allem, was
bekannt ist, nur Wiederverkäufern. Dieses Skript fragt deshalb zuerst lesend,
und wenn netcup ablehnt, schreibt es die beiden Namen in die Zusammenfassung,
damit sie jemand von Hand einträgt. Eine Annahme wird hier ausprobiert, nicht
geglaubt.
"""
import json
import os
import sys
import urllib.error
import urllib.request

PROJEKT = "zaehlora"
ZIEL = f"{PROJEKT}.pages.dev"
CF = "https://api.cloudflare.com/client/v4"
NETCUP = "https://ccp.netcup.net/run/webservice/servers/endpoint.php?JSON"

zeilen = []


def melde(text=""):
    print(text)
    zeilen.append(text)


def anfrage(methode, url, token=None, daten=None):
    kopf = {"Content-Type": "application/json"}
    if token:
        kopf["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, method=methode, headers=kopf,
                                 data=json.dumps(daten).encode() if daten is not None else None)
    try:
        with urllib.request.urlopen(req, timeout=30) as antwort:
            return json.load(antwort)
    except urllib.error.HTTPError as fehler:
        try:
            return json.loads(fehler.read().decode())
        except ValueError:
            return {"success": False, "errors": [{"message": f"HTTP {fehler.code}"}]}


def fehlertext(antwort):
    return "; ".join(f"{e.get('code', '')} {e.get('message', '')}".strip()
                     for e in antwort.get("errors") or []) or "ohne Begründung"


def zone(domain, token, konto):
    gefunden = anfrage("GET", f"{CF}/zones?name={domain}", token)
    if not gefunden.get("success"):
        sys.exit(f"Cloudflare lehnt ab: {fehlertext(gefunden)}. Hat CLOUDFLARE_DOMAIN_TOKEN „Zone · Zone · Edit“?")
    if gefunden["result"]:
        z = gefunden["result"][0]
        melde(f"- Zone {domain} besteht schon, Zustand **{z['status']}**")
        return z
    neu = anfrage("POST", f"{CF}/zones", token, {"name": domain, "account": {"id": konto}, "type": "full"})
    if not neu.get("success"):
        sys.exit(f"Zone ließ sich nicht anlegen: {fehlertext(neu)}")
    melde(f"- Zone {domain} angelegt, Zustand **{neu['result']['status']}**")
    return neu["result"]


def eintrag(zone_id, name, token):
    """Ein CNAME auf die Website, über Cloudflare geleitet.

    Auch für die Domain ohne `www`: Cloudflare löst einen CNAME an der Wurzel
    selbst auf („CNAME flattening"). Genau das kann netcups DNS nicht, und
    deshalb liegt die Domain bei Cloudflare.
    """
    da = anfrage("GET", f"{CF}/zones/{zone_id}/dns_records?name={name}", token)
    for r in da.get("result") or []:
        if r["type"] == "CNAME" and r["content"] == ZIEL:
            melde(f"- DNS {name} → {ZIEL} steht schon")
            return
        if r["type"] in ("A", "AAAA", "CNAME"):
            # Ein Platzhalter von netcup oder ein alter Eintrag. Er wiche sonst
            # der Website nicht, und die Domain zeigte auf eine Parkseite.
            anfrage("DELETE", f"{CF}/zones/{zone_id}/dns_records/{r['id']}", token)
            melde(f"- DNS {name}: alten Eintrag {r['type']} {r['content']} entfernt")
    neu = anfrage("POST", f"{CF}/zones/{zone_id}/dns_records", token,
                  {"type": "CNAME", "name": name, "content": ZIEL, "proxied": True, "ttl": 1})
    if not neu.get("success"):
        sys.exit(f"DNS-Eintrag {name} ließ sich nicht setzen: {fehlertext(neu)}")
    melde(f"- DNS {name} → {ZIEL} gesetzt")


def pages_domain(name, token, konto):
    basis = f"{CF}/accounts/{konto}/pages/projects/{PROJEKT}/domains"
    da = anfrage("GET", basis, token)
    for d in da.get("result") or []:
        if d.get("name") == name:
            melde(f"- Website unter {name}: **{d.get('status')}**")
            return d.get("status")
    neu = anfrage("POST", basis, token, {"name": name})
    if not neu.get("success"):
        melde(f"- Website unter {name}: nicht angehängt ({fehlertext(neu)})")
        return None
    melde(f"- Website unter {name} angehängt: **{neu['result'].get('status')}**")
    return neu["result"].get("status")


def netcup(domain, nameserver):
    kunde = os.environ.get("NETCUP_KUNDENNUMMER", "")
    schluessel = os.environ.get("NETCUP_API_KEY", "")
    passwort = os.environ.get("NETCUP_API_PASSWORT", "")
    if not (kunde and schluessel and passwort):
        fehlt = [n for n, w in (("NETCUP_KUNDENNUMMER", kunde), ("NETCUP_API_KEY", schluessel),
                               ("NETCUP_API_PASSWORT", passwort)) if not w]
        melde(f"- netcup: nicht versucht, es fehlt {', '.join(fehlt)}")
        return False
    def rufe(aktion, param):
        return anfrage("POST", NETCUP, daten={"action": aktion, "param": param})
    an = rufe("login", {"customernumber": kunde, "apikey": schluessel, "apipassword": passwort})
    if an.get("status") != "success":
        melde(f"- netcup: Anmeldung abgelehnt ({an.get('longmessage') or an.get('shortmessage')})")
        return False
    sitzung = {"customernumber": kunde, "apikey": schluessel,
               "apisessionid": an["responsedata"]["apisessionid"]}
    try:
        info = rufe("infoDomain", {**sitzung, "domainname": domain})
        if info.get("status") != "success":
            melde(f"- netcup: Nameserver lesen abgelehnt ({info.get('longmessage') or info.get('shortmessage')}), "
                  "also von Hand eintragen")
            return False
        jetzt = sorted(n.get("hostname", "").lower().rstrip(".")
                       for n in (info["responsedata"].get("nameserverentry") or []))
        if jetzt == sorted(nameserver):
            melde("- netcup: Nameserver stehen schon auf Cloudflare")
            return True
        neu = rufe("updateDomain", {**sitzung, "domainname": domain,
                                    "nameservers": {f"nameserver{i + 1}": {"hostname": n}
                                                    for i, n in enumerate(nameserver)}})
        if neu.get("status") != "success":
            melde(f"- netcup: Nameserver ändern abgelehnt ({neu.get('longmessage') or neu.get('shortmessage')})")
            return False
        melde("- netcup: **Nameserver auf Cloudflare umgestellt**")
        return True
    finally:
        rufe("logout", sitzung)


def main():
    domain = (sys.argv[1] if len(sys.argv) > 1 else "zaehlora.de").lower()
    konto = os.environ["CLOUDFLARE_ACCOUNT_ID"]
    zone_token = os.environ.get("CLOUDFLARE_DOMAIN_TOKEN", "")
    if not zone_token:
        sys.exit("CLOUDFLARE_DOMAIN_TOKEN fehlt. Anleitung: docs/13-zugaenge.md")

    melde(f"## Domain {domain}")
    melde()
    z = zone(domain, zone_token, konto)
    nameserver = [n.lower() for n in z.get("name_servers") or []]
    for name in (domain, f"www.{domain}"):
        eintrag(z["id"], name, zone_token)
    for name in (domain, f"www.{domain}"):
        pages_domain(name, os.environ["CLOUDFLARE_API_TOKEN"], konto)

    if z["status"] != "active":
        umgestellt = netcup(domain, nameserver)
        melde()
        if not umgestellt:
            melde("### Von Hand bei netcup eintragen")
            melde()
            melde("customercontrolpanel.de → Domains → zaehlora.de → Reiter **Nameserver** → eigene Nameserver:")
            melde()
            for n in nameserver:
                melde(f"- `{n}`")
        melde()
        melde("Danach dauert es meist unter einer Stunde, höchstens einen Tag. "
              "Dieser Ablauf darf jederzeit wieder laufen und zeigt dann den Zustand.")
    else:
        melde()
        melde("**Die Domain ist bei Cloudflare aktiv.**")

    ziel = os.environ.get("GITHUB_STEP_SUMMARY")
    if ziel:
        with open(ziel, "a", encoding="utf-8") as datei:
            datei.write("\n".join(zeilen) + "\n")


if __name__ == "__main__":
    main()
