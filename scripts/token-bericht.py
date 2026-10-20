#!/usr/bin/env python3
"""Wo der Tokenverbrauch einer Sitzung herkommt, aus dem Sitzungsprotokoll.

Vom Gründer am 20. Oktober: „ich habe das gefühl dass ich aktuell mehr token
verbrauche." Das Gefühl stimmte, und die Ursache war nicht die, die man
zuerst vermutet: nicht die langen Anweisungsdateien, nicht der große
Baukasten, sondern **die Länge einer einzigen Sitzung** und was bei jeder Pause
über einer Stunde mit ihr passiert.

Das Protokoll (`~/.claude/projects/<Projekt>/<Sitzung>.jsonl`) führt je Antwort
die echten Zähler: frisch gelesen, aus dem Zwischenspeicher gelesen, neu in den
Zwischenspeicher geschrieben, geschrieben. Daraus folgt:

* **Jede Antwort liest den ganzen Kontext noch einmal.** Aus dem
  Zwischenspeicher kostet das einen Bruchteil, aber bei 400 000 Token Kontext
  und tausend Antworten ist es der größte Posten.
* **Nach einer Pause über eine Stunde ist der Zwischenspeicher weg** und wird
  für den ganzen Kontext neu geschrieben, zum höheren Preis. Dasselbe passiert
  bei einem Modellwechsel mitten in der Sitzung.
* **Alles, was einmal im Kontext steht, wird bei jeder weiteren Antwort mit
  gelesen**, bis die Sitzung verdichtet wird: ein langes Protokoll, ein Bild,
  jede Meldung über verbundene Dienste.

Aufruf:  scripts/token-bericht.py            neueste Sitzung dieses Projekts
         scripts/token-bericht.py <datei>    eine bestimmte

Die Kosteneinheiten sind **relativ** (Eingabe = 1, aus dem Zwischenspeicher
lesen = 0,1, neu schreiben = 1,25 bis 2, Ausgabe = 5), keine Preise. Aktuelle
Preise stehen bei Anthropic; hier geht es um Verhältnisse.
"""
import collections
import datetime as dt
import glob
import json
import os
import sys

# Ab dieser Kontextgröße ist eine neue Sitzung billiger als weiterzumachen.
GRENZE = 300_000
# Ein Neuaufbau, der so viel neu schreibt, gilt als „ganzer Kontext".
NEUAUFBAU = 150_000


def neueste() -> str:
    dateien = glob.glob(os.path.expanduser("~/.claude/projects/*PulseMeter*/*.jsonl"))
    if not dateien:
        sys.exit("Kein Sitzungsprotokoll unter ~/.claude/projects/*PulseMeter*/ gefunden.")
    return max(dateien, key=os.path.getmtime)


def strings(o):
    if isinstance(o, str):
        yield o
    elif isinstance(o, dict):
        for v in o.values():
            yield from strings(v)
    elif isinstance(o, list):
        for v in o:
            yield from strings(v)


def lesen(pfad: str):
    antworten, gesehen, namen = [], set(), {}
    hinweise = collections.Counter()
    groesse = collections.Counter()
    ergebnisse = collections.defaultdict(list)
    muster = {
        "Meldungen über verbundene Dienste": ("deferred tools", "MCP servers", "MCP Server Instructions"),
        "CLAUDE.md und Anweisungsdateien neu eingelesen": ("Instruction files were re-read",),
        "Verzeichnis aller Skills": ("The following skills are available",),
        "Erinnerung an die Aufgabenliste": ("task tools haven't been used",),
        "Benachrichtigungen geplanter Läufe": ("scheduled trigger",),
    }
    for zeile in open(pfad, encoding="utf-8"):
        try:
            d = json.loads(zeile)
        except ValueError:
            continue
        m = d.get("message") or {}
        u, inhalt = m.get("usage"), m.get("content")
        if d.get("type") == "assistant" and u:
            schluessel = m.get("id") or d.get("uuid")
            if schluessel not in gesehen:
                gesehen.add(schluessel)
                antworten.append(dict(
                    ts=d.get("timestamp", ""), modell=m.get("model"),
                    ein=u.get("input_tokens", 0), aus=u.get("output_tokens", 0),
                    lese=u.get("cache_read_input_tokens", 0),
                    neu=u.get("cache_creation_input_tokens", 0)))
        if d.get("type") == "assistant" and isinstance(inhalt, list):
            for b in inhalt:
                if b.get("type") == "tool_use":
                    namen[b["id"]] = b["name"]
                    groesse["Eingaben, die ich schreibe (Befehle, Skripte, Dateien)"] += len(json.dumps(b.get("input"), ensure_ascii=False))
        if d.get("type") == "user" and isinstance(inhalt, list):
            for b in inhalt:
                if b.get("type") == "tool_result":
                    teile = b.get("content")
                    n = 0
                    if isinstance(teile, list):
                        for t in teile:
                            n += 4500 if t.get("type") == "image" else len(t.get("text", ""))
                    else:
                        n = len(str(teile or ""))
                    ergebnisse[namen.get(b.get("tool_use_id"), "?")].append(n)
        for s in strings(d):
            if len(s) < 400:
                continue
            for name, teile in muster.items():
                if any(t in s for t in teile):
                    hinweise[name] += len(s)
                    break
    return antworten, hinweise, groesse, ergebnisse


def zeit(s: str) -> dt.datetime:
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))


def main() -> int:
    pfad = sys.argv[1] if len(sys.argv) > 1 else neueste()
    a, hinweise, groesse, ergebnisse = lesen(pfad)
    if not a:
        print("Keine Antworten im Protokoll.")
        return 1
    kosten = lambda r, w: r["ein"] + 0.1 * r["lese"] + w * r["neu"] + 5 * r["aus"]
    kontext = lambda r: r["ein"] + r["lese"] + r["neu"]
    jetzt = kontext(a[-1])

    print(f"Sitzung: {os.path.basename(pfad)}")
    print(f"{len(a)} Antworten, {a[0]['ts'][:10]} bis {a[-1]['ts'][:10]}")
    print(f"Kontext jetzt: {jetzt/1000:.0f}k Token, im Schnitt {sum(map(kontext, a))/len(a)/1000:.0f}k")
    print(f"Aus dem Zwischenspeicher gelesen {sum(r['lese'] for r in a)/1e6:.0f} M, "
          f"neu geschrieben {sum(r['neu'] for r in a)/1e6:.1f} M, "
          f"selbst geschrieben {sum(r['aus'] for r in a)/1e6:.2f} M Token")

    neuaufbau = []
    for i, r in enumerate(a):
        if r["neu"] > NEUAUFBAU and r["lese"] < 50_000:
            v = a[i - 1] if i else None
            pause = (zeit(r["ts"]) - zeit(v["ts"])).total_seconds() / 60 if v else 0
            if v and v["modell"] != r["modell"] and pause < 60:
                grund = "Modellwechsel"
            elif pause >= 60:
                grund = "Pause über einer Stunde"
            else:
                grund = "anderes (zum Beispiel nach einer Verdichtung)"
            neuaufbau.append((r, grund, pause))

    print("\nKostenanteile (relative Einheiten, Zwischenspeicher-Schreiben 1,25 bis 2):")
    for w, name in ((1.25, "kurzer Zwischenspeicher"), (2.0, "Zwischenspeicher für eine Stunde")):
        gesamt = sum(kosten(r, w) for r in a)
        neu = sum(kosten(r, w) for r, _, _ in neuaufbau)
        lese = sum(0.1 * r["lese"] for r in a)
        aus = sum(5 * r["aus"] for r in a)
        print(f"  {name:<34} Neuaufbauten {neu/gesamt:>4.0%}, Lesen {lese/gesamt:>4.0%}, Ausgabe {aus/gesamt:>4.0%}")

    print(f"\nNeuaufbauten des ganzen Kontexts: {len(neuaufbau)}")
    ursachen = collections.Counter(g for _, g, _ in neuaufbau)
    tok = collections.Counter()
    for r, g, _ in neuaufbau:
        tok[g] += r["neu"]
    for g, n in ursachen.most_common():
        print(f"  {g:<44}{n:>3}x  {tok[g]/1e6:>4.1f} M Token")
    tage = collections.Counter(r["ts"][:10] for r, _, _ in neuaufbau)
    if tage:
        print("  je Tag: " + ", ".join(f"{t[5:]} {n}x" for t, n in sorted(tage.items())))

    if hinweise or groesse:
        print("\nWas im Kontext liegt und bei jeder Antwort mitgelesen wird (≈ Token):")
        for k, v in hinweise.most_common():
            print(f"  {k:<48}{v/3.5/1000:>6.0f}k")
        for k, v in groesse.most_common():
            print(f"  {k:<48}{v/3.5/1000:>6.0f}k")
        for k, v in sorted(ergebnisse.items(), key=lambda kv: -sum(kv[1]))[:4]:
            print(f"  Ergebnisse von {k:<33}{sum(v)/3.5/1000:>6.0f}k  ({len(v)}x, größtes {max(v)/3.5/1000:.1f}k)")

    print()
    if jetzt > GRENZE:
        print(f"→ Der Kontext ist über {GRENZE//1000}k. Eine neue Sitzung ist jetzt billiger als weiterzumachen:")
        print("  Übergabe in docs/06-uebergabe.md aktualisieren, dann neu anfangen.")
    else:
        print(f"→ Der Kontext liegt unter {GRENZE//1000}k. Weitermachen ist in Ordnung.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
