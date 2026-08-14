# Was vor dem Onlinegehen noch eingetragen werden muss

Vier Stellen, alle im Quelltext mit `PLATZHALTER n von 4` markiert. Suchen
lassen sie sich in einem Zug:

```bash
grep -rn "PLATZHALTER" docs/website/
```

**Solange auch nur eine davon offen ist, darf die Seite nicht online gehen.**
Ein Impressum ohne ladungsfähige Anschrift ist in Deutschland abmahnfähig, und
Apple prüft die Datenschutz-URL vor der Freigabe.

---

## 1 — Kontaktadresse auf der Hilfeseite

`hilfe.html`, Abschnitt „Kontakt".

Vorgesehen ist `hallo@pulsemeter.de` mit kostenloser Weiterleitung ins
bestehende Postfach (Cloudflare Email Routing). Bis die Domain steht, ist die
Adresse **nicht erreichbar** — eine Support-Seite mit toter Adresse ist
schlimmer als keine.

## 2 — Anbieter im Impressum

`impressum.html`, Abschnitt „Anbieter". Vier Zeilen:

```
[Vorname Nachname]
[Straße und Hausnummer]
[Postleitzahl und Ort]
```

Bei einer Privatperson die **Wohnanschrift**. Ein Postfach genügt nicht —
verlangt ist eine Anschrift, an die sich zustellen lässt.

Zu prüfen ist außerdem der Absatz zur **Umsatzsteuer**: Er steht heute auf
Kleinunternehmer nach § 19 UStG. Trifft das nicht zu, gehört dort die
Umsatzsteuer-Identifikationsnummer hin.

## 3 — Verantwortlicher in der Datenschutzerklärung

`datenschutz.html`, Abschnitt 1. **Dieselben** Angaben wie im Impressum, und
dieselben wie später in App Store Connect. Weichen sie voneinander ab, fällt
es genau dann auf, wenn es unangenehm ist.

## 4 — Der Hosting-Anbieter

`datenschutz.html`, Abschnitt 7. Dort steht heute Cloudflare, weil das der
Plan ist. Wird es ein anderer, gehört dessen Name und Anschrift an diese
Stelle — die Angabe ist Pflicht, weil jeder Hoster beim Ausliefern
IP-Adressen verarbeitet.

Bleibt es bei Cloudflare, genügt es, die eckigen Klammern zu entfernen.

---

## Danach

- `node scripts/check-website.mjs` — prüft unter anderem, dass **kein**
  `PLATZHALTER` mehr im Quelltext steht.
- Domain eintragen: In allen vier Dateien steht `https://pulsemeter.de/` als
  `canonical`. Wird es eine andere Adresse, muss sie dort ebenfalls geändert
  werden, sonst verweist die Seite auf sich selbst unter falschem Namen.
