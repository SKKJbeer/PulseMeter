# Die Website online bringen — kostenlos, in vier Schritten

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

## Schritt 2 — Das Projekt anlegen

Im Dashboard links auf **Workers & Pages** › **Create** › Reiter **Pages** ›
**Upload assets**.

- Projektname: **`pulsemeter`** — exakt so. Der Ablauf sucht danach, und aus dem
  Namen entsteht auch die Adresse `pulsemeter.pages.dev`.
- Es will einmal Dateien sehen, um das Projekt anzulegen. Nimm irgendetwas
  Kleines; der erste richtige Stand kommt eine Minute später über GitHub. (Wer
  mag, zieht `docs/website/` als Ordner hinein — dann steht die Seite schon.)

**Nicht** „Connect to Git" wählen. Das sieht bequemer aus, hängt den Auslöser
aber an Cloudflare, und dann ginge auch eine Seite online, die die Prüfung
nicht bestanden hat.

## Schritt 3 — Ein Token, das genau eine Sache darf

Rechts oben aufs Profilbild › **My Profile** › **API Tokens** › **Create
Token** › bei **Create Custom Token** auf **Get started**.

| Feld | Eintrag |
|---|---|
| Token name | `PulseMeter Pages` |
| Permissions | **Account** › **Cloudflare Pages** › **Edit** |
| Account Resources | Include › dein Konto |

Weiter, **Create Token**, und den Wert **sofort kopieren** — Cloudflare zeigt
ihn genau einmal.

Die **Account ID** steht in der Adresszeile, sobald du im Dashboard bist:
`dash.cloudflare.com/`**`<das ist sie>`**`/…`. Alternativ auf der
Übersichtsseite von Workers & Pages rechts.

## Schritt 4 — Beides ins Repository

[github.com/SKKJbeer/PulseMeter/settings/secrets/actions](https://github.com/SKKJbeer/PulseMeter/settings/secrets/actions)
› **New repository secret**, zweimal:

| Name | Wert |
|---|---|
| `CLOUDFLARE_API_TOKEN` | das Token aus Schritt 3 |
| `CLOUDFLARE_ACCOUNT_ID` | die Kennung aus der Adresszeile |

Fertig. Ab jetzt: **Actions › Website veröffentlichen › Run workflow** — oder
einfach warten, bis die nächste Änderung an der Website in `main` landet.

---

## Woran man merkt, dass etwas fehlt

Der Ablauf **bricht nicht ab**, wenn die zwei Geheimnisse fehlen. Er prüft die
Seite, sagt „Cloudflare ist noch nicht eingerichtet" und ist fertig. So sieht
man den Unterschied zwischen „nicht eingerichtet" und „kaputt" — und ein roter
Lauf, der nichts bedeutet, gewöhnt einem das Hinsehen ab.

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
