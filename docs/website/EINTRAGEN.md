# Was vor dem Onlinegehen noch eingetragen werden muss

**Zwei Stellen** sind noch offen, im Quelltext mit `PLATZHALTER n von 2`
markiert. Finden lässt sie sich mit:

```bash
grep -rn "PLATZHALTER" docs/website/
```

---

## Erledigt

- **Die Kontaktadresse.** `geschult-atome.6r@icloud.com` aus Apples
  „E-Mail-Adresse verbergen", eingetragen auf der Hilfeseite, im Impressum und
  in der Datenschutzerklärung. Sie leitet weiter und lässt sich abschalten,
  falls Werbung darüber kommt — die private Adresse erfährt dabei niemand.
  Später mit eigener Domain wird daraus `hallo@…` über Cloudflare Email
  Routing; es sind dieselben drei Stellen.
- **Die Anschrift.** Steffen Karjoth, Corelliweg 28, 70195 Stuttgart — im
  Impressum und in der Datenschutzerklärung, dort **wortgleich**. Dieselben
  Angaben gehören später in App Store Connect.

---

## Offen 1 — Umsatzsteuer-Identifikationsnummer

`impressum.html`, Abschnitt „Umsatzsteuer".

Dort stand bis 0.49.0 „Kleinunternehmer im Sinne von § 19 Umsatzsteuergesetz".
**Das war eine Annahme, und sie ist falsch** — der Gründer hat am 16. August
bestätigt, dass er kein Kleinunternehmer ist. Der Satz ist ersatzlos raus.

§ 5 DDG verlangt die Umsatzsteuer-Identifikationsnummer, **soweit vorhanden**.
Wer eine hat, trägt sie ein; wer keine hat, lässt den Abschnitt weg — dann ist
auch der Absatz zu löschen und nicht leer stehen zu lassen.

Auf die Preise im App Store wirkt sich das nicht aus: Bei App-Verkäufen in der
EU ist **Apple der Verkäufer** gegenüber dem Kunden und führt die Umsatzsteuer
ab. Die Beträge in `04-monetarisierung.md` sind das, was der Kunde zahlt, und
bleiben es.

## Offen 2 — der Hosting-Anbieter

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
