# Die Website online bringen — kostenlos, in zwei Schritten

Alles hier ist im **kostenlosen** Tarif von Cloudflare enthalten. Keine
Kreditkarte, keine Testphase, kein Betrag, der später fällig wird. Pages
liefert unbegrenzt viele Aufrufe aus; begrenzt ist nur die Zahl der
Veröffentlichungen (500 im Monat), und die Website ändert sich nicht 500-mal
im Monat.

Nach der Einrichtung geht jede Änderung an `docs/website/` von selbst online,
sobald sie in `main` liegt — und nur dann, wenn `check-website.mjs` sie
durchlässt.

---

## Was du am Ende hast

`https://pulsemeter.pages.dev` — die Adresse, die schon in allen Seiten als
`canonical` eingetragen ist. Eine eigene Domain (`pulsemeter.de`) lässt sich
später davorhängen; dafür gibt es `scripts/domain-setzen.sh`, und der Umzug ist
ein Eintrag im Dashboard.

---

## Schritt 1 — Konto

[dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up) — E-Mail und
Passwort, mehr nicht. Beim Einrichten fragt Cloudflare nach einer Domain: **Das
überspringen.** Für Pages braucht es keine.

Das Dashboard läuft im Browser des Telefons. Es gibt keine App, die den Link
abfängt.

## Schritt 2 — An den Zweig `website` hängen

Im Dashboard links auf **Workers & Pages** › **Create** › Reiter **Pages** ›
**Connect to Git** › das Repository `SKKJbeer/PulseMeter` auswählen.

| Feld | Eintrag |
|---|---|
| Project name | `pulsemeter` |
| Production branch | **`website`** — nicht `main` |
| Framework preset | **None** |
| Build command | *leer lassen* |
| Build output directory | `/` |

**Save and Deploy.** Nach etwa einer Minute steht die Seite auf
`https://pulsemeter.pages.dev`.

### Warum `website` und nicht `main`

Im Zweig `website` liegen die fertigen Seiten in der Wurzel — kein
`docs/website/` davor, keine Skripte, keine Dokumente. Und vor allem: Der Zweig
entsteht **nur nach einer bestandenen Prüfung.** Der Ablauf „Website
veröffentlichen" prüft erst `check-website.mjs` und schreibt ihn dann. Hinge
Cloudflare an `main`, ginge auch online, was die Prüfung nicht durchgelassen
hat — etwa eine Seite mit einer offenen Textlücke im Impressum.

Der Zweig wird bei jeder Änderung überschrieben. Er ist keine Historie, sondern
der jeweils geprüfte Stand.

---

## Der andere Weg: über ein Token

Braucht man nicht, wenn Schritt 2 steht. Er ist hier, weil er ohne Cloudflares
Zugriff aufs Repository auskommt — und weil der Ablauf ihn schon kann, sobald
zwei Geheimnisse hinterlegt sind.

**Am Telefon geht das nicht:** Die GitHub-App hat überhaupt keinen
Einstellungsbereich, und der Link dorthin läuft ins Leere. Es braucht einen
Browser mit Desktop-Ansicht oder einen Rechner.

1. Profil › **API Tokens** › **Create Custom Token**, Berechtigung
   **Account** › **Cloudflare Pages** › **Edit**. Wert sofort kopieren,
   Cloudflare zeigt ihn genau einmal.
2. Die **Account ID** steht in der Adresszeile des Dashboards.
3. Beides unter
   [Settings › Secrets and variables › Actions](https://github.com/SKKJbeer/PulseMeter/settings/secrets/actions)
   als `CLOUDFLARE_API_TOKEN` und `CLOUDFLARE_ACCOUNT_ID` hinterlegen.

Sind sie da, lädt der Ablauf zusätzlich direkt hoch. Sind sie nicht da, macht
er nichts weiter — der Zweig steht trotzdem, und Cloudflare holt ihn sich.

---

## Woran man merkt, dass etwas fehlt

Der Ablauf **bricht nicht ab**, wenn die Geheimnisse für den Token-Weg fehlen.
Er prüft die Seite, schreibt den Zweig, sagt „Cloudflare ist noch nicht
eingerichtet" und ist fertig. So sieht man den Unterschied zwischen „nicht
eingerichtet" und „kaputt" — und ein roter Lauf, der nichts bedeutet, gewöhnt
einem das Hinsehen ab.

## Was vor dem ersten Mal noch zu tun ist

- **Der Platzhalter in `datenschutz.html`.** Dort steht der Hoster in eckigen
  Klammern. Bleibt es bei Cloudflare, genügt es, die Klammern zu entfernen —
  Name und Anschrift stimmen dann. `check-website.mjs` lässt die Seite erst
  durch, wenn kein `PLATZHALTER` mehr im Quelltext steht, und der Ablauf oben
  hält sich daran.
- **Das App-Store-Abzeichen** steht auf „Bald im App Store" und führt
  nirgendwohin. Am Starttag: `scripts/appstore-knopf.sh an`.

## Später: eigene Domain

`pulsemeter.de` kaufen (Cloudflare Registrar verkauft zum Einkaufspreis),
im Pages-Projekt unter **Custom domains** eintragen, und dann **einmal**:

```bash
scripts/domain-setzen.sh pulsemeter.de
```

Das setzt die `canonical`-Zeilen aller Seiten, die Sitemap und `robots.txt` in
einem Zug. Von Hand geht das schief: Google hält `canonical` für die Wahrheit
und wirft weg, was auf eine andere Adresse zeigt.
