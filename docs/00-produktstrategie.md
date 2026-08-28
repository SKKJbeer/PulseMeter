# 00 – Produktstrategie

Status: Entwurf zur Entscheidung
Letzte Änderung: 2026-08-04

---

## 1. Problemdefinition

Zählerstände abzulesen ist kein Problem. **Aus Zählerständen eine Antwort zu bekommen, ist das Problem.**

Wer heute Zählerstände erfasst, macht das aus genau drei Gründen:

| Job-to-be-done | Auslöser | Frequenz | Zahlungsbereitschaft |
|---|---|---|---|
| **A – Festhalten** „Ich schreibe den Stand auf, bevor ich ihn vergesse." | Monatsanfang, Umzug, Aufforderung des Versorgers | 1–12×/Jahr | niedrig |
| **B – Einordnen** „Verbrauche ich mehr als letztes Jahr? Reicht mein Abschlag?" | Preiserhöhung, Nachzahlung, neue Wärmepumpe/PV | laufend, passiv | **hoch** |
| **C – Nachweisen** „Ich brauche einen Beleg." | Jahresabrechnung prüfen, Nebenkosten, Mieterwechsel | 1–2×/Jahr | **hoch** |

Der Fehler fast aller bestehenden Apps: Sie lösen **A** hervorragend und **B** und **C** gar nicht. Sie sind Datenbanken mit einer Eingabemaske. Der Nutzer trägt jahrelang Zahlen ein und bekommt am Ende — eine Tabelle.

**Unsere These:** Der Wert entsteht nicht bei der Eingabe, sondern bei der Interpretation. Die Eingabe muss reibungslos sein (sonst gibt es keine Daten), aber das Produkt ist die Antwort.

---

## 2. Marktanalyse

### Was es gibt

- **Versorger-Apps** (E.ON, EnBW, Stadtwerke): nur der eigene Vertrag, kein Vergleich, wechseln nicht mit dem Nutzer mit, oft unangenehm zu bedienen.
- **Zählerstand-Apps im Store** (diverse, meist Einzelentwickler): funktional, aber tabellenlastig, technische Sprache, kein Dark Mode, schwache Charts, keine Kostenlogik, kein iCloud-Sync.
- **Smart-Home-/Energiemanager** (Tibber, Shelly, SMA, Home Assistant): Echtzeitdaten, aber setzen Hardware voraus, sind für Nicht-Techniker unbenutzbar und lösen den analogen Zähler an der Wand gar nicht.
- **Excel / Notizen-App**: der eigentliche Marktführer. Der ehrlichste Wettbewerber.

### Die Lücke

> Es gibt keine App, die sich anfühlt wie eine Apple-App, die auch **Zweirichtungszähler, Zählerwechsel, Gas-Umrechnung und Abschlagsvergleich** korrekt beherrscht, und die einem Nicht-Techniker in 5 Sekunden sagt, ob er im Plan liegt.

Das ist eine schmale, aber echte Lücke — und sie ist verteidigbar, weil sie zwei Dinge gleichzeitig verlangt, die selten zusammenkommen: **fachliche Tiefe** (Messtechnik, deutsche Energieabrechnung) und **radikale Oberflächen-Einfachheit**.

### Positionierung in einem Satz

> **PulseMeter ist das Haushaltsbuch für Verbrauch: du trägst eine Zahl ein, und die App sagt dir, ob alles im Rahmen ist.**

---

## 3. Zielgruppen und Priorisierung

Deine Liste ist richtig, aber sie ist keine Reihenfolge. Ich schlage eine harte Priorisierung vor:

| # | Gruppe | Anteil des Marktes | v1 | Warum |
|---|---|---|---|---|
| 1 | **Eigenheimbesitzer / Familien** | groß | ✅ Kern | Größte Gruppe, einfachster Anwendungsfall, treibt Bewertungen und Weiterempfehlung |
| 2 | **PV- und Wärmepumpen-Besitzer** | wachsend, zahlungsbereit | ✅ Kern | Haben mehrere Zähler, echten Analysebedarf, hohe Zahlungsbereitschaft — **unser Premium-Anker** |
| 3 | **Vermieter (1–5 Einheiten)** | kleiner, zahlungsbereit | ⏳ v1.1 | Braucht Objekt-/Einheiten-Modell — Architektur ab Tag 1 vorbereiten, UI später |
| 4 | **Kleine Hausverwaltungen** | Nische | ❌ später | Andere Anforderungen (Mehrbenutzer, Rollen, Abrechnung) — eigenes Produkt-Kapitel |

**Begründung der Reihenfolge:** Gruppe 1 gibt uns Volumen und Rezensionen, Gruppe 2 gibt uns Umsatz, Gruppe 3 gibt uns Preisspielraum nach oben. Gruppe 4 zuerst zu bauen würde die App für Gruppe 1 sofort überladen — und genau das ist der Fehler, den unsere Wettbewerber machen.

**Designregel, die daraus folgt:** Ein Nutzer mit einem einzigen Stromzähler darf die Wörter „Objekt", „Einheit", „Messstelle", „Zählwerk" oder „Register" **nie zu Gesicht bekommen**. Die Struktur existiert im Datenmodell, nicht in der Oberfläche. Sie wird erst sichtbar, wenn der Nutzer sie durch sein Verhalten anfordert (zweites Gebäude anlegt).

---

## 4. Widerspruch: drei Punkte aus dem Briefing, die ich anders sehe

Du hast ausdrücklich kritisches Denken verlangt. Hier sind die drei wichtigsten Einwände.

### 4.1 „Täglich oder monatlich aktiv genutzt" ist das falsche Erfolgskriterium

**Problem:** Ein Zähler wird real 1–12× pro Jahr abgelesen. Eine App, die auf tägliche Nutzung optimiert, wird zwangsläufig Features erfinden, die niemand braucht — Gamification, Feeds, Push-Spam. Das ist exakt der Weg zur überladenen App, die du nicht willst.

**Empfehlung:** Wir optimieren nicht auf DAU, sondern auf **Wiederkehr über 12 Monate**. Die relevanten Metriken sind:

- **Ablese-Retention M12**: Anteil der Nutzer, die 12 Monate nach Installation noch Stände erfassen. Zielwert: > 35 %.
- **Erinnerungs-Opt-in**: Zielwert > 70 %. Die lokale Benachrichtigung *ist* unser Retention-Motor, nicht ein Feature.
- **Lücken-Quote**: Anteil der Nutzer ohne Datenlücke > 60 Tage.

**Auswirkung auf UX:** Passive Präsenz statt aktiver Nutzung — Widget auf dem Homescreen, Lock-Screen-Widget, Siri-Kurzbefehl, eine gut getimte Erinnerung. Die App soll *präsent* sein, ohne *geöffnet* zu werden.

**Auswirkung auf Monetarisierung:** siehe `04-monetarisierung.md`. Niedrige Öffnungsfrequenz ist das stärkste Argument gegen ein reines Abo.

### 4.2 „Dashboard für alle Ressourcen" führt direkt in eine Produktfalle

**Problem:** Die Vision „persönliches Dashboard für den Verbrauch aller Ressourcen" liest sich harmlos, zieht aber unweigerlich Richtung Live-Daten: Shelly, Tibber, SMA, Wechselrichter-APIs, Smart-Meter-Gateway. Das ist ein **anderes Produkt** — mit Server-Infrastruktur, laufenden Kosten, Hardware-Support-Hölle und einer Zielgruppe von Technikern.

**Empfehlung:** Wir halten die Vision, aber definieren sie präzise um: PulseMeter ist das Dashboard für **manuell und periodisch erfasste** Verbrauchsdaten aller Art. Live-Integrationen sind ein **explizites Nicht-Ziel** bis mindestens v2.0, und wenn, dann als optionale Datenquelle in dasselbe Modell — nie als eigener Modus.

**Begründung:** Unsere Stärke ist, dass wir mit *jedem* Zähler funktionieren, auch dem 30 Jahre alten Ferraris-Zähler an der Wand. Sobald wir Hardware voraussetzen, verlieren wir 90 % der Zielgruppe und den Grund, warum uns jemand weiterempfiehlt.

### 4.3 Vermieter-Funktionen sind ein rechtliches Risiko, wenn wir sie falsch benennen

**Problem:** „Nebenkostenabrechnung" ist in Deutschland durch BetrKV und Heizkostenverordnung reguliert (Verteilerschlüssel, 50/70-Regel, Gradtagszahlen, Fristen). Wenn wir suggerieren, unsere PDFs seien abrechnungsfähig, übernehmen wir eine Verantwortung, die wir nicht tragen wollen.

**Empfehlung:** Wir liefern **Ableseprotokolle und Verbrauchsnachweise**, keine Abrechnung. Die Formulierung im Produkt lautet konsequent „Nachweis", „Protokoll", „Übergabeprotokoll" — nie „Abrechnung". Das ist gleichzeitig ehrlicher und schützt uns.

**Auswirkung:** Der Vermieter-Tarif verkauft *Beweissicherheit* (Foto, Zeitstempel, Unterschrift, sauberes PDF), nicht *Rechenlogik*. Das ist ohnehin der Teil, den Vermieter wirklich schmerzhaft finden.

---

## 5. Produktprinzipien (operationalisiert)

Deine Prinzipien sind richtig, aber zu abstrakt zum Entscheiden. Ich übersetze sie in überprüfbare Regeln:

1. **60-Sekunden-Regel.** Von Erstinstallation bis zur ersten gespeicherten Ablesung: unter 60 Sekunden, ohne Konto, ohne Tutorial.
2. **3-Tap-Regel.** Vom App-Start bis zur gespeicherten Folge-Ablesung: maximal 3 Berührungen.
3. **5-Sekunden-Regel.** Der Startbildschirm beantwortet in unter 5 Sekunden Blickzeit die Frage „Ist alles im Rahmen?" — ohne Scrollen, ohne Interaktion.
4. **Keine Sackgasse.** Jede Zahl, die wir anzeigen, muss antippbar sein und erklären, wie sie zustande kommt. Vertrauen entsteht durch Nachvollziehbarkeit, nicht durch Autorität.
5. **Datenfreiheit.** Export ist dauerhaft kostenlos, in offenen Formaten. Wir halten niemals Nutzerdaten als Verhandlungsmasse. Das ist eine Monetarisierungs-Entscheidung, keine Wohltätigkeit — es ist der Grund, warum uns jemand vertraut.
6. **Kein technisches Vokabular.** Verbotene Wörter in der UI: Register, Zählwerk, OBIS, Entität, Synchronisation, Datensatz, Messstelle. Erlaubt in Einstellungen/Detailansichten für Fortgeschrittene, nie im Hauptfluss.
7. **Nie stillschweigend rechnen.** Geschätzte, interpolierte oder hochgerechnete Werte sind immer als solche gekennzeichnet. Eine erfundene Zahl, die wie eine gemessene aussieht, zerstört das Produkt.

---

## 6. Risikoregister

| # | Risiko | Eintritt | Wirkung | Gegenmaßnahme |
|---|---|---|---|---|
| R1 | Niedrige Nutzungsfrequenz → schwache Monetarisierung | hoch | hoch | Einmalkauf statt Abo im Kern (siehe 04); Erinnerungen als Retention-Motor |
| R2 | Falsches Datenmodell (Ein-Zahl-pro-Zähler) blockiert PV/HT-NT | mittel | **kritisch** | Register-Modell ab Tag 1 (siehe 02) — nachträglich nicht sauber migrierbar |
| R3 | SwiftData + CloudKit Reifegrad, Sync-Konflikte, Datenverlust | mittel | **kritisch** | Repository-Abstraktion, aggressive Backup-/Export-Strategie, Schema bewusst simpel halten |
| R4 | OCR-Erwartung: Nutzer erwartet Magie, bekommt Fehler | hoch | mittel | OCR nur als Vorschlag mit Bestätigung, nie automatisch speichern; nicht in v1 |
| R5 | Scope-Creep Richtung Smart Home | hoch | hoch | Explizites Nicht-Ziel dokumentiert (4.2) |
| R6 | Rechtliche Erwartung an Vermieter-Exporte | mittel | hoch | Sprachregelung „Nachweis" statt „Abrechnung" (4.3) |
| R7 | Wir bauen die App zu groß vor dem ersten Nutzer | hoch | hoch | v1-Scope in `05-roadmap.md` ist bewusst schmerzhaft klein |
| R8 | Keine Mac-/Xcode-Umgebung in dieser Session | sicher | mittel | Domänenlogik plattformfrei und ohne Apple-Frameworks bauen, damit sie unabhängig testbar bleibt |

---

## 7. Erfolgskriterien (messbar)

| Kriterium | Zielwert v1 |
|---|---|
| Zeit bis zur ersten Ablesung | < 60 s (Median) |
| Ablese-Retention M12 | > 35 % |
| Erinnerungs-Opt-in | > 70 % |
| App-Store-Bewertung | ≥ 4,7 bei ≥ 100 Bewertungen |
| Free → Pro Konversion | 3–6 % |
| Absturzfreie Sessions | > 99,8 % |
| Startzeit bis interaktiv (Cold Start) | < 800 ms |
| VoiceOver-Abdeckung Hauptflüsse | 100 % |

---

## 8. Offene strategische Fragen

Diese Punkte kann ich nicht sinnvoll allein entscheiden — sie stehen in der Zusammenfassung an dich.

1. Fokus v1: nur Privatnutzer, oder Vermieter-Basisfunktionen sofort mit?
2. Monetarisierungsmodell (Empfehlung liegt vor, siehe 04).
3. Minimales iOS-Ziel und damit verbundene Technologiewahl (siehe 01).
4. Marktstart: nur DACH oder direkt international (betrifft Gas-Umrechnung, Einheiten, Währung, Tarifmodell).
