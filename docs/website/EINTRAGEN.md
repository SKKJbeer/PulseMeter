# Was vor dem Onlinegehen noch eingetragen werden muss

Drei Stellen, alle im Quelltext mit `PLATZHALTER n von 3` markiert. Suchen
lassen sie sich in einem Zug:

```bash
grep -rn "PLATZHALTER" docs/website/
```

**Solange auch nur eine davon offen ist, darf die Seite nicht online gehen.**
Ein Impressum ohne ladungsfähige Anschrift ist in Deutschland abmahnfähig, und
Apple prüft die Datenschutz-URL vor der Freigabe.

---

## Erledigt: die Kontaktadresse

Eingetragen ist **`geschult-atome.6r@icloud.com`** — eine Adresse aus Apples
„E-Mail-Adresse verbergen". Sie steht an drei Stellen: `hilfe.html`,
`impressum.html` und `datenschutz.html`, und leitet an das Postfach des
Gründers weiter. Kommt darüber Werbung, lässt sie sich in den
iCloud-Einstellungen abschalten, ohne dass jemand die private Adresse erfährt.

Später mit eigener Domain wird daraus `hallo@…` mit kostenloser Weiterleitung
über Cloudflare Email Routing — dann sind es dieselben drei Stellen.

## 1 — Anbieter im Impressum

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

## 2 — Verantwortlicher in der Datenschutzerklärung

`datenschutz.html`, Abschnitt 1. **Dieselben** Angaben wie im Impressum, und
dieselben wie später in App Store Connect. Weichen sie voneinander ab, fällt
es genau dann auf, wenn es unangenehm ist.

## 3 — Der Hosting-Anbieter

`datenschutz.html`, Abschnitt 7. Dort steht heute Cloudflare, weil das der
Plan ist. Wird es ein anderer, gehört dessen Name und Anschrift an diese
Stelle — die Angabe ist Pflicht, weil jeder Hoster beim Ausliefern
IP-Adressen verarbeitet.

Bleibt es bei Cloudflare, genügt es, die eckigen Klammern zu entfernen.

---

## Danach

- `node scripts/check-website.mjs` — prüft unter anderem, dass **kein**
  `PLATZHALTER` mehr im Quelltext steht.
- Adresse eintragen: **nicht von Hand.** `scripts/domain-setzen.sh` setzt die
  `canonical`-Zeilen aller vier Seiten in einem Zug und weigert sich, wenn sie
  schon auseinanderlaufen:

  ```bash
  scripts/domain-setzen.sh                    # zeigt, was eingetragen ist
  scripts/domain-setzen.sh pulsemeter.de      # stellt um
  ```

  Eingetragen ist gerade **`pulsemeter.pages.dev`** — die kostenlose Adresse
  von Cloudflare Pages. Eine halb umgestellte Website ist schlimmer als eine
  mit der falschen Adresse: Google hält `canonical` für die Wahrheit und wirft
  die Seiten weg, die auf eine fremde Adresse zeigen. Deshalb das Skript.
