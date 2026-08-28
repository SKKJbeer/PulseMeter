# Die Website online bringen — kostenlos, in drei Schritten

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

## Und was du nicht tun musst

**Das Pages-Projekt legt der Ablauf selbst an.** Von Hand ist es zweimal
schiefgegangen: einmal über „Connect to Git" mit `Could not detect a directory
to deploy`, einmal weil danach kein Projekt namens `pulsemeter` existierte.
`scripts/cloudflare-projekt.sh` sieht nach und legt es an, wenn es fehlt — das
Token darf das.

*(Falls doch ein Projekt mit Git-Anbindung herumsteht: Projekt › **Settings** ›
**Builds** › **Disconnect**. Sonst baut Cloudflare parallel weiter und die
Läufe scheitern nebeneinander.)*

## Schritt 2 — Ein Token, das genau eine Sache darf

[dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens)
› **Create Token** › bei **Create Custom Token** auf **Get started**.

| Feld | Eintrag |
|---|---|
| Token name | `PulseMeter Pages` |
| Permissions | **Account** › **Cloudflare Pages** › **Edit** |
| Account Resources | Include › dein Konto |

Das ist die **einzige** Berechtigung, die es braucht. Nicht „Edit Cloudflare
Workers" aus den Vorlagen — die darf viel mehr, und ein Token, das mehr darf
als nötig, ist ein Token, das mehr kaputtmachen kann.

**Create Token**, und den Wert **sofort kopieren** — Cloudflare zeigt ihn genau
einmal.

Die **Account ID** steht in der Adresszeile, sobald du im Dashboard bist:
`dash.cloudflare.com/`**`<das ist sie>`**`/…`

## Schritt 3 — Beides ins Repository

[github.com/SKKJbeer/PulseMeter/settings/secrets/actions](https://github.com/SKKJbeer/PulseMeter/settings/secrets/actions)
› **New repository secret**, zweimal:

| Name | Wert |
|---|---|
| `CLOUDFLARE_API_TOKEN` | das Token von eben |
| `CLOUDFLARE_ACCOUNT_ID` | die Kennung aus der Adresszeile |

**Am Telefon nur im Browser**, nicht in der GitHub-App: Die hat überhaupt
keinen Einstellungsbereich und schluckt den Verweis, ohne ihn zeigen zu können.
Den Link lange gedrückt halten und „In Safari öffnen" wählen — oder die Adresse
von Hand eintippen.

Danach: **Actions › Website veröffentlichen › Run workflow.**

---

## Der Zweig `website` — falls Git-Anbindung doch einmal sein soll

Der Ablauf legt die geprüften Seiten zusätzlich in einen Zweig namens
`website`, in die Wurzel, ohne die Anleitungen. Wer ein Pages-Projekt daran
hängen will, nimmt: Production branch `website`, Framework preset **None**,
Build command **leer**, Build output directory `/`.

Der Zweig ist auch ohne das nützlich: Dort steht schwarz auf weiß, was zuletzt
die Prüfung bestanden hat.

---

## Woran man merkt, dass etwas fehlt

Der Ablauf **bricht nicht ab**, wenn die Geheimnisse für den Token-Weg fehlen.
Er prüft die Seite, schreibt den Zweig, sagt „Cloudflare ist noch nicht
eingerichtet" und ist fertig. So sieht man den Unterschied zwischen „nicht
eingerichtet" und „kaputt" — und ein roter Lauf, der nichts bedeutet, gewöhnt
einem das Hinsehen ab.

## Was vor dem ersten Mal noch zu tun ist

- ~~Der Platzhalter in `datenschutz.html`~~ — seit 0.95.4 zu. Dort steht jetzt
  Cloudflare ohne Klammern.
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
