# 04 – Monetarisierung

Status: Entwurf zur Entscheidung
Letzte Änderung: 2026-08-04

---

## 1. Problemdefinition

Die Nutzungsfrequenz einer Zähler-App liegt bei 1–12 Öffnungen pro Jahr und Zähler. Das ist die wichtigste wirtschaftliche Randbedingung des Projekts, und sie widerspricht dem Standardmodell des App Stores.

**Kernfrage:** Wie finanzieren wir eine App, die selten geöffnet wird, aber über Jahre relevant bleibt — ohne den Nutzer zu bestrafen und ohne uns in laufende Kosten zu zwingen?

---

## 2. Analyse der Modelle

| Modell | Vorteile | Nachteile | Passung |
|---|---|---|---|
| **Reines Abo** | Planbarer Umsatz, finanziert Weiterentwicklung | Bei 6 Öffnungen/Jahr empfindet der Nutzer das Abo als Erpressung. Deutsche Utility-Käufer reagieren besonders ablehnend. Erzeugt 1-Sterne-Rezensionen — genau die Währung, die wir brauchen | ✗ schlecht |
| **Reiner Einmalkauf** | Fühlt sich fair an, hohe Zufriedenheit, passt zur Frequenz | Kein wiederkehrender Umsatz; Finanzierung von Wartung über Jahre unklar | ~ mittel |
| **Werbung** | Niedrige Einstiegshürde | Zerstört das Premium-Gefühl, widerspricht Datenschutz-Positionierung, im Utility-Segment kaum Umsatz | ✗ raus |
| **Hybrid: Einmalkauf für Private + Abo für Vermieter** | Fairness für die Masse, wiederkehrender Umsatz dort, wo laufender Nutzen entsteht | Zwei Produkte pflegen, Paywall-Logik komplexer | ✓ **Empfehlung** |

---

## 3. Empfehlung

### Struktur

**Kostenlos — dauerhaft, ohne Zeitlimit**
- Bis zu **2 Zähler**
- Unbegrenzt viele Ablesungen, unbegrenzte Historie
- Verlauf und Vorjahresvergleich
- Erinnerungen
- **CSV-Export** — dauerhaft und uneingeschränkt

**PulseMeter Pro — Einmalkauf, ca. 14,99 €**
- Unbegrenzte Zähler und Zählwerke (PV, HT/NT, Wärmepumpe, Wallbox)
- Kosten & Tarife, Tarifhistorie
- Abschlagsvergleich und Jahresprognose
- Foto-Belege
- PDF-Bericht
- Widgets, Siri-Kurzbefehle
- Alle künftigen Funktionen des Privatbereichs

**PulseMeter Vermieter — Abo, ca. 29,99 €/Jahr**
- Mehrere Objekte und Einheiten
- Mieterzuordnung mit Ein-/Auszugsdaten
- Ableseprotokolle als PDF (Foto, Zeitstempel, Unterschrift)
- Verbrauchsnachweis je Einheit und Zeitraum
- Sammelerfassung: alle Zähler eines Objekts in einem Durchgang

### Begründung im Einzelnen

**Warum genau 2 Zähler kostenlos?**
Der typische Mieter hat Strom und Wasser — er wird nie zahlen und ist trotzdem ein zufriedener Nutzer, der die App weiterempfiehlt und gut bewertet. Der typische Eigenheimbesitzer hat vier bis sechs Zähler und stößt innerhalb der ersten Woche an die Grenze — im Moment des erkannten Nutzens, nicht davor. Die Grenze qualifiziert also, statt zu blockieren. Ein Limit auf Ablesungen oder Historie wäre demgegenüber ein Fehler: Es macht die App im entscheidenden Moment unbrauchbar und wirkt kleinlich.

**Warum ist der Export dauerhaft kostenlos?**
Weil ein Zahlungsmodell, das Nutzerdaten als Geisel nimmt, exakt das Vertrauen zerstört, das dieses Produkt tragen soll. Der Export ist außerdem unser stärkstes Argument gegen die Angst „was, wenn die App eingestellt wird?" — eine reale Sorge bei Utility-Apps kleiner Anbieter und ein Grund, warum Menschen bei Excel bleiben. (Der PDF-*Bericht* ist etwas anderes als der Daten-*Export*: Ersterer ist ein gestaltetes Dokument und legitim Pro.)

**Warum Einmalkauf im Kern?**
Die Frequenz rechtfertigt kein Abo, CloudKit erzeugt keine laufenden Serverkosten (siehe `01`, ADR-002), und Fairness ist bei dieser Zielgruppe ein Kaufargument. Die Architekturentscheidung *ermöglicht* das Geschäftsmodell — deshalb ist Monetarisierung Teil der Technikentscheidung, nicht ein nachgelagerter Schritt.

**Warum beim Vermieter ein Abo?**
Dort entsteht wiederkehrender Nutzen (jährliche Protokolle, Mieterwechsel, Nachweise) und ein wirtschaftlicher Nutzen, der den Preis um ein Vielfaches übersteigt. Ein Abo ist hier nicht nur akzeptiert, sondern erwartet — es ist eine Betriebsausgabe.

**Finanzierung der Weiterentwicklung ohne Abo-Basis.**
Über kostenpflichtige Hauptversionen (Pro 2.0 nach 2–3 Jahren mit substanziellem Mehrwert, Bestandskunden mit deutlichem Rabatt) — das etablierte, faire Muster hochwertiger Utility-Apps. Kein „Pro wird plötzlich Abo".

---

## 4. Preisstrategie

| | Preis | Begründung |
|---|---|---|
| Pro | **14,99 €** | Oberhalb der Impulskauf-Schwelle, unterhalb der Nachdenk-Schwelle. Signalisiert Qualität. 4,99 € würde Beliebigkeit signalisieren und den Umsatz nicht durch Menge kompensieren. |
| Vermieter | **29,99 €/Jahr** | Unter 3 €/Monat, gemessen an einer einzigen vermiedenen Streitigkeit über Zählerstände trivial. |
| Launch | −33 % für 4 Wochen | Bewertungen zum Start einsammeln, nicht Umsatz maximieren |
| Familienfreigabe | ja | Kostet nichts, wird in Rezensionen positiv erwähnt |

**Keine** Rabattschlacht, keine wiederkehrenden Popups, kein Countdown-Timer. Die Paywall erscheint an genau **zwei** Stellen: beim Anlegen des dritten Zählers und beim Antippen einer Pro-Funktion — jeweils mit klarer Erklärung, was sie leistet, und einem sichtbaren Weg zurück.

---

## 5. Was wir bewusst nicht tun

- Kein Feature künstlich verschlechtern, um Pro zu verkaufen
- Keine Werbung, in keiner Form
- Kein Verkauf oder Weitergabe von Verbrauchsdaten — auch nicht aggregiert oder anonymisiert
- Keine Bewertungs-Aufforderung vor der dritten erfolgreichen Ablesung
- Keine Pro-Hinweise im Erfassungsfluss — der Kernnutzen bleibt immer unangetastet

---

## 6. Risiko

Der Einmalkauf begrenzt den maximalen Umsatz pro Nutzer. Das ist eine bewusste Entscheidung zugunsten von Bewertung, Weiterempfehlung und Vertrauen — den drei Faktoren, über die eine Utility-App im App Store überhaupt erst gefunden wird. Der Hebel liegt bei diesem Produkt in der Reichweite, nicht in der Extraktion.

**Zu überwachen:** Wenn die Vermieter-Zielgruppe nach 12 Monaten deutlich stärker konvertiert als erwartet, verschiebt sich der Produktschwerpunkt — dann ist die Frage neu zu stellen, ob wir eine Privatnutzer-App mit Vermieter-Zusatz sind oder umgekehrt.
