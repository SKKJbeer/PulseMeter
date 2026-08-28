# Was vor dem Onlinegehen noch eingetragen werden muss

**Nichts mehr offen.** Der Quelltext enthält keinen `PLATZHALTER` mehr, und
`check-website.mjs` prüft das bei jedem Lauf. Nachsehen:

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
- **Die Umsatzsteuer.** Der Abschnitt ist raus. § 5 DDG verlangt die
  Umsatzsteuer-Identifikationsnummer nur, *soweit vorhanden* — der Gründer hat
  am 16. August bestätigt, dass er keine hat, und eine leere Zeile wäre
  schlechter als gar keine. Bis 0.49.0 stand dort „Kleinunternehmer im Sinne
  von § 19 Umsatzsteuergesetz", auch das nur geraten.

  Auf die Preise im App Store wirkt sich das nicht aus: Bei App-Verkäufen in
  der EU ist **Apple der Verkäufer** gegenüber dem Kunden und führt die
  Umsatzsteuer ab. Die Beträge in `04-monetarisierung.md` sind das, was der
  Kunde zahlt, und bleiben es. Kommt später eine USt-IdNr. dazu, gehört sie
  als eigener Abschnitt zurück ins Impressum.

---

- **Der Hosting-Anbieter.** `datenschutz.html`, Abschnitt 7: Cloudflare Inc.,
  101 Townsend St, San Francisco. Die Angabe ist Pflicht, weil jeder Hoster
  beim Ausliefern IP-Adressen verarbeitet.

  Bestätigt hat der Gründer das am 28. August nicht mit einem Wort, sondern mit
  einer Handlung: Konto bei Cloudflare, Pages-Projekt, Token ausgestellt und im
  Repository hinterlegt. Wird es später ein anderer Anbieter, gehört dessen
  Name und Anschrift an dieselbe Stelle.

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
