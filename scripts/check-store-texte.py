#!/usr/bin/env python3
"""Prüft die Texte in `docs/09-appstore.md` auf den Klang, den sie haben sollen.

**Warum das erst jetzt existiert.** Die Website wird seit dem 28. August auf
Floskeln und Gedankenstriche geprüft. Die Store-Texte nicht — dabei sind sie
die härtere Sorte: Was auf der Website steht, ist in zwei Minuten geändert;
was im App Store steht, braucht eine neue Fassung und eine Prüfung durch Apple.

Der Anlass, vom Gründer am 7. September: Die Funktionstexte müssten
„professionell wirken und dargestellt werden und nicht wie von einer KI
klingen."

**Geprüft werden nur die Blöcke in ```-Zäunen** — also genau das, was die
Skripte nach Apple übertragen. Der Fließtext drumherum ist Begründung für uns
und darf erklären, so viel er will.

Was gezählt wird und warum:

  Floskeln          `scripts/floskeln.txt`, dieselbe Liste wie bei der Website
  Gedankenstriche   höchstens einer je 250 Wörter, dieselbe Schwelle wie bei
                    der Website
  Dreierketten      drei kurze Sätze hintereinander sind Werbesprache, nie ein
                    Gedanke („Verbrauch. Kosten. Kontrolle.")
  Ausrufezeichen    keins. Wer eins braucht, hat den Satz nicht fertig
  Wir-Form          „wir freuen uns", „wir haben verbessert" — die App spricht
                    zum Nutzer, nicht die Firma über sich

Aufruf:

    python3 scripts/check-store-texte.py
"""

import pathlib
import re
import sys

WURZEL = pathlib.Path(__file__).resolve().parent.parent
QUELLE = WURZEL / "docs" / "09-appstore.md"
LISTE = WURZEL / "scripts" / "floskeln.txt"

# **Dieselbe Schwelle wie bei der Website: ein Strich je 250 Wörter.**
# Der erste Anlauf stand auf 120, mit der Begründung, kurze Texte vertrügen
# weniger. Das mag stimmen, nur hat dann jeder Text eine eigene Zahl, und eine
# Regel, die man nachschlagen muss, wird nicht befolgt. Eine Zahl für beide.
WOERTER_JE_STRICH = 250

# **Nicht jeder Block ist ein Text für Menschen.** Unter diesen Überschriften
# stehen Werte, keine Prosa: Schlagworte sind eine kommagetrennte Liste, und
# die Hinweise für die Prüfung sind ein technischer Text an einen Prüfer bei
# Apple — der darf und soll erklären.
NICHT_PRUEFEN = (
    "Schlagworte",
    "Hinweise für die Prüfung",
    "Bundle",
    "Kennungen",
)


def floskeln() -> list[str]:
    zeilen = LISTE.read_text(encoding="utf-8").splitlines()
    return [z.strip() for z in zeilen if z.strip() and not z.startswith("#")]


def bloecke(inhalt: str) -> list[tuple[str, str]]:
    """Jeder ```-Block mit der Überschrift, unter der er steht."""
    gefunden = []
    ueberschrift = "(ohne Überschrift)"
    zeilen = inhalt.split("\n")
    i = 0
    while i < len(zeilen):
        zeile = zeilen[i]
        if zeile.startswith("#"):
            ueberschrift = zeile.lstrip("#").strip()
        elif zeile.startswith("```"):
            j = i + 1
            while j < len(zeilen) and not zeilen[j].startswith("```"):
                j += 1
            gefunden.append((ueberschrift, "\n".join(zeilen[i + 1:j])))
            i = j
        i += 1
    return gefunden


def kurze_saetze_am_stueck(text: str) -> int:
    """Die längste Kette kurzer Sätze hintereinander.

    „Kurz" heißt hier höchstens vier Wörter. Drei davon in Folge sind die
    Dreierkette aus `CLAUDE.md` — „Verbrauch. Kosten. Kontrolle." —, und die
    ist immer Werbung und nie eine Aussage.
    """
    # **Aufzählungen sind keine Sätze.** Der erste Anlauf schlug auf der
    # Preisliste an — „Unbegrenzt viele Zähler | Kosten und Preise | …" —, und
    # das ist keine Dreierkette, sondern eine Liste von Kaufnamen. Zeilen, die
    # als Aufzählung erkennbar sind, fallen vor dem Zählen heraus.
    ohne_liste = "\n".join(z for z in text.split("\n")
                           if not z.lstrip().startswith(("•", "-", "*", "–")))
    saetze = [s.strip() for s in re.split(r"[.!?]\s+|\n\n", ohne_liste) if s.strip()]
    laengste = kette = 0
    for satz in saetze:
        if len(satz.split()) <= 4:
            kette += 1
            laengste = max(laengste, kette)
        else:
            kette = 0
    return laengste


def main() -> int:
    if not QUELLE.exists():
        print(f"::error::{QUELLE} fehlt.")
        return 1

    verboten = floskeln()
    funde: list[str] = []
    geprueft = 0

    for ueberschrift, text in bloecke(QUELLE.read_text(encoding="utf-8")):
        if any(teil in ueberschrift for teil in NICHT_PRUEFEN):
            continue
        if len(text.split()) < 8:
            continue
        geprueft += 1
        klein = text.lower()

        treffer = [w for w in verboten if w in klein]
        if treffer:
            funde.append(f"{ueberschrift}: {', '.join(treffer)} "
                         f"— sagt über diese App nichts")

        woerter = len(text.split())
        striche = len(re.findall(r"\w\s—\s\w", text))
        erlaubt = max(1, round(woerter / WOERTER_JE_STRICH))
        if striche > erlaubt:
            funde.append(f"{ueberschrift}: {striche} Gedankenstriche auf "
                         f"{woerter} Wörter (bis {erlaubt})")

        kette = kurze_saetze_am_stueck(text)
        if kette >= 3:
            funde.append(f"{ueberschrift}: {kette} kurze Sätze am Stück "
                         f"— das ist eine Dreierkette, kein Gedanke")

        if "!" in text:
            funde.append(f"{ueberschrift}: Ausrufezeichen — der Satz trägt "
                         f"sich selbst oder er trägt nicht")

        # **Nur die werbliche Wir-Form.** Der erste Anlauf fing „Auf unseren
        # Servern liegen sie nicht — wir haben keine." Das ist der beste Satz
        # der ganzen Beschreibung: eine Tatsache über das Produkt, kein
        # Selbstlob. Gemeint war „wir freuen uns", „wir präsentieren" — die
        # Firma, die über sich spricht.
        wir = re.findall(r"\bwir (?:freuen uns|präsentieren|stellen vor|"
                         r"haben verbessert|haben optimiert|sind stolz)\b",
                         klein)
        if wir:
            # Schlusszeichen typografisch, nicht gerade: Ein `"` inmitten
            # eines `"`-begrenzten f-Strings beendet ihn. Dieselbe Falle wie
            # im Baukasten unter „Deutsche Prosa gehört nicht durch die Shell".
            funde.append(f"{ueberschrift}: „{wir[0]}“ — die App spricht zum "
                         f"Nutzer, nicht die Firma über sich")

    if funde:
        print("Store-Texte:")
        for zeile in funde:
            print(f"  · {zeile}")
        print(f"\n{len(funde)} Fund(e) in {geprueft} Textblöcken. "
              f"Die Regeln stehen in .claude/skills/selbstsprechend/SKILL.md, "
              f"Abschnitt „Funktionstexte\".")
        return 1

    print(f"Store-Texte: {geprueft} Blöcke geprüft, kein Fund.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
