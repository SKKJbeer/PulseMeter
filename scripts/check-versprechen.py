#!/usr/bin/env python3
"""Hält die Website an das, was der Quelltext hergibt.

**Der Anlass, und er ist teuer bezahlt.** Am 29. August fand ein Audit auf
`zaehlora.pages.dev/hilfe` diesen Satz:

    „Kostenlos bleiben: … der Vorjahresvergleich, Erinnerungen und der Export.
     … Jedes Stück 1,99 €, alle vier zusammen 4,99 €."

Erinnerungen kosteten zu dem Zeitpunkt seit zwei Wochen 0,99 €, und es waren
fünf Freischaltungen. Die Preisseite derselben Website stand richtig. Zwei
öffentlich erreichbare Seiten widersprachen sich also beim Preis, und die
falsche versprach ein Feature gratis, das Geld kostet.

**Warum es niemandem auffiel.** `check-strings.py` hält die *Adresse* an drei
Orten zusammen, `check-website.mjs` prüft die Seiten untereinander auf Aufbau
und Ton. Den Betrag prüfte nichts. Eine Zahl, die an zwei Orten steht und nur
an einem gepflegt wird, wandert früher oder später auseinander — das ist keine
Nachlässigkeit, das ist die Bauart.

Geprüft wird deshalb gegen die **eine** Quelle, die zählt: `Entitlement.swift`.
Was dort steht, geht in den Store; was auf der Website steht, ist eine Kopie.

Dazu die zweite Fassung desselben Problems: Das FAQ-Markup stand auf der
Startseite, der sichtbare Text auf der Hilfeseite. Zwei Fassungen derselben
Antwort, und genau die Preisantwort lief auseinander. Markup und Text stehen
jetzt auf **einer** Seite, und diese Prüfung hält sie Wort für Wort zusammen.

    python3 scripts/check-versprechen.py
"""
import json
import pathlib
import re
import sys

funde: list[str] = []

WURZEL = pathlib.Path(__file__).resolve().parent.parent
ENTITLEMENT = WURZEL / "Packages/PulseCore/Sources/PulseCore/Access/Entitlement.swift"
START = WURZEL / "docs/website/index.html"
HILFE = WURZEL / "docs/website/hilfe.html"

ZAHLWORT = {1: "ein", 2: "zwei", 3: "drei", 4: "vier", 5: "fünf", 6: "sechs"}


def euro(wert: str) -> str:
    """`4.99` aus dem Quelltext wird zu `4,99 €`, wie es auf der Seite steht."""
    return wert.replace(".", ",") + " €"


def sichtbarer_text(roh: str) -> str:
    """Was ein Mensch liest: ohne Kommentare, Skripte, Stil und Markup.

    Dieselbe Normalisierung für beide Seiten der FAQ-Prüfung — sonst
    verglichen wir Zeilenumbrüche statt Sätze.
    """
    ohne = re.sub(r"<!--.*?-->|<script.*?</script>|<style.*?</style>", " ",
                  roh, flags=re.S)
    ohne = re.sub(r"<[^>]+>", " ", ohne)
    ohne = (ohne.replace("&amp;", "&").replace("&nbsp;", " ")
                .replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", '"'))
    ohne = re.sub(r"\s+", " ", ohne)
    # Ein `</a>` mitten im Satz hinterlässt sonst „umrechnen ." — der Punkt
    # gehört ans Wort, und im Markup soll derselbe Satz stehen wie auf der Seite.
    return re.sub(r"\s+([.,;:!?])", r"\1", ohne).strip()


# ---------------------------------------------------------------- die Preise

if not ENTITLEMENT.exists():
    funde.append(f"{ENTITLEMENT} fehlt — ohne sie ist nichts zu prüfen")
    print("\n".join(funde))
    sys.exit(1)

quelle = ENTITLEMENT.read_text(encoding="utf-8")

# `case .everything: return Decimal(string: "4.99")!` und die Geschwister.
# Bewusst über den Fallnamen und nicht über die Reihenfolge: Wer einen Fall
# einfügt, verschiebt sonst stillschweigend alle Zuordnungen.
preise: dict[str, str] = {}
for fall, betrag in re.findall(
        r'case \.(\w+):\s*return Decimal\(string: "([\d.]+)"\)!', quelle):
    preise[fall] = betrag
standard = re.search(r'default:\s*return Decimal\(string: "([\d.]+)"\)!', quelle)

if "everything" not in preise or "reminders" not in preise or standard is None:
    funde.append(f"{ENTITLEMENT.name}: die Preise liessen sich nicht lesen "
                 f"(gefunden: {sorted(preise) or 'keine'})")

# Die einzeln käuflichen Stücke — Zahl und Namen aus `individually`.
block = re.search(r"public static var individually: \[ProductID\] \{(.*?)\}",
                  quelle, re.S)
einzeln = re.findall(r"\.(\w+)", block.group(1)) if block else []

grenze = re.search(r"freeMeterLimit = (\d+)", quelle)

if funde:
    print("\n".join(funde))
    sys.exit(1)

erlaubt = {euro(standard.group(1)), euro(preise["everything"]),
           euro(preise["reminders"])}

# Die Summe der Einzelkäufe. Sie steht auf der Preisseite als Argument für das
# Bündel („einzeln wären es 8,95 €") und ist damit eine Behauptung über eine
# Rechnung, nicht über einen Preis — sie fällt sonst durch jedes Raster.
summe = 0.0
for produkt in einzeln:
    summe += float(preise.get(produkt, standard.group(1)))
erlaubt.add(f"{summe:.2f}".replace(".", ",") + " €")

for seite in (START, HILFE):
    text = sichtbarer_text(seite.read_text(encoding="utf-8"))
    for betrag in set(re.findall(r"\d+,\d{2}\s*€", text)):
        normal = re.sub(r"\s+", " ", betrag)
        if normal not in erlaubt:
            funde.append(
                f"{seite.relative_to(WURZEL)}: {normal} steht auf der Seite, "
                f"aber nicht im Quelltext — dort gibt es "
                f"{', '.join(sorted(erlaubt))}")

# **Wie viele Freischaltungen es sind, steht als Wort da.** „alle vier
# zusammen" war genau der Fehler: Der Betrag daneben stimmte sogar, die Anzahl
# nicht. Ein Preis ohne die Anzahl, für die er gilt, ist keine Preisangabe.
wort = ZAHLWORT.get(len(einzeln), str(len(einzeln)))
for seite in (START, HILFE):
    text = sichtbarer_text(seite.read_text(encoding="utf-8"))
    for treffer in re.findall(r"[Aa]lle (\w+)\s+(?:zusammen|Freischaltungen)", text):
        if treffer.lower() != wort:
            funde.append(
                f"{seite.relative_to(WURZEL)}: „alle {treffer} …" + "" +
                f"\" — es sind {len(einzeln)} einzelne Freischaltungen "
                f"({', '.join(einzeln)})")

# Die kostenlose Grenze, ebenfalls als Wort.
if grenze:
    frei = ZAHLWORT.get(int(grenze.group(1)), grenze.group(1))
    # Ohne Rücksicht auf Groß- und Kleinschreibung: Auf der Preistafel fängt
    # der Satz mit „Zwei Zähler" an, im Fließtext steht „zwei Zähler".
    text = sichtbarer_text(START.read_text(encoding="utf-8")).lower()
    if f"{frei} zähler" not in text:
        funde.append(f"docs/website/index.html: „{frei} Zähler\" steht nicht auf "
                     f"der Seite — freeMeterLimit ist {grenze.group(1)}")

# ------------------------------------------------------------------- die FAQ

roh = HILFE.read_text(encoding="utf-8")

# Sichtbar: jede Frage mit ihrer Antwort, in der Reihenfolge der Seite.
sichtbar: list[tuple[str, str]] = []
for frage in re.findall(r'<div class="frage">(.*?)</div>', roh, re.S):
    kopf = re.search(r"<h3>(.*?)</h3>", frage, re.S)
    absatz = re.search(r"<p>(.*?)</p>", frage, re.S)
    if kopf and absatz:
        sichtbar.append((sichtbarer_text(kopf.group(1)),
                         sichtbarer_text(absatz.group(1))))

markup = re.search(r'<script type="application/ld\+json">(.*?)</script>',
                   roh, re.S)
if markup is None:
    funde.append("docs/website/hilfe.html: kein FAQ-Markup — die Fragen stehen "
                 "sichtbar da, aber keine Suchmaschine sieht sie")
elif not sichtbar:
    funde.append("docs/website/hilfe.html: keine <div class=\"frage\">-Blöcke "
                 "gefunden — die Prüfung greift ins Leere")
else:
    try:
        daten = json.loads(markup.group(1))
    except json.JSONDecodeError as fehler:
        daten = None
        funde.append(f"docs/website/hilfe.html: das FAQ-Markup ist kein "
                     f"gültiges JSON — {fehler}")
    if daten is not None:
        ausgezeichnet = {
            eintrag["name"]: eintrag["acceptedAnswer"]["text"]
            for eintrag in daten.get("mainEntity", [])
        }
        for frage, antwort in sichtbar:
            if frage not in ausgezeichnet:
                funde.append(f"docs/website/hilfe.html: „{frage}\" steht auf der "
                             f"Seite, fehlt aber im FAQ-Markup")
            elif ausgezeichnet[frage] != antwort:
                funde.append(
                    f"docs/website/hilfe.html: die Antwort auf „{frage}\" "
                    f"lautet im Markup anders als auf der Seite\n"
                    f"    Seite:  {antwort[:110]}\n"
                    f"    Markup: {ausgezeichnet[frage][:110]}")
        for frage in ausgezeichnet:
            if frage not in {f for f, _ in sichtbar}:
                funde.append(f"docs/website/hilfe.html: „{frage}\" steht im "
                             f"FAQ-Markup, aber nicht auf der Seite")

if funde:
    print("\n".join(funde))
    print(f"\n{len(funde)} Fund(e).")
    sys.exit(1)

print(f"Preise, Anzahl der Freischaltungen und FAQ decken sich mit "
      f"{ENTITLEMENT.name}.")
