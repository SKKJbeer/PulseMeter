# Zugänge — was der Gründer einmal anlegt, damit der Rest von selbst läuft

Stand 0.117.7, 26. September 2026.

Alles, was sich mit einem Schlüssel erledigen lässt, erledigen die Abläufe.
Hier steht nur, was **kein** Schlüssel kann: ein Schalter in einem Konto, ein
Schlüssel, der erst entstehen muss, ein Code, den nur der Kontoinhaber sieht.
Jeder Punkt hat einen direkten Link und sagt, was danach von allein passiert.

**Geheimnisse gehören in GitHub, nie in den Chat.** Eintragen unter:
<https://github.com/SKKJbeer/PulseMeter/settings/secrets/actions/new>
Name oben, Wert unten, „Add secret". Was kein Geheimnis ist (ein
Bestätigungscode, eine Anbieterkennung), darf in den Chat.

| # | Was | Wer es liest | Zustand |
|---|---|---|---|
| 1 | Analytics Engine einschalten | die Zählung auf der Website | offen |
| 2 | Leseschlüssel Cloudflare | Wochenbericht Website | offen (vielleicht reicht der vorhandene) |
| 3 | Search Console | Google-Verzeichnis | offen |
| 4 | Google-Dienstkonto | Wochenbericht Google, Sitemap | offen |
| 5 | Berichtsschlüssel App Store Connect | täglicher Ablauf „Zahlen" | offen, scheitert seit dem 5. September |
| 6 | Anbieterkennung `pt` | Laden-Knopf auf der Website | offen |

---

## 1. Analytics Engine einschalten (Cloudflare, ein Klick)

<https://dash.cloudflare.com/?to=/:account/workers/analytics-engine>

Dort **Enable** (oder „Set up"). Kostet nichts.

*Danach von allein:* Der nächste Lauf von „Website veröffentlichen" lädt mit
Zählung hoch. Bis dahin geht die Seite ohne Zählung online, und der Lauf sagt
es mit einer Warnung.

## 2. Leseschlüssel Cloudflare (nur wenn der Bericht es verlangt)

Der Wochenbericht versucht es zuerst mit dem Schlüssel zum Hochladen. Meldet
er „Die Zählung ließ sich nicht lesen", braucht es einen eigenen:

<https://dash.cloudflare.com/profile/api-tokens> → **Create Token** →
**Create Custom Token**

- Name: `Zählora Statistik`
- Permissions: **Account** · **Account Analytics** · **Read**
- sonst nichts, **Continue to summary** → **Create Token**

Als Geheimnis `CLOUDFLARE_STATISTIK_TOKEN`.

## 3. Search Console (Google)

<https://search.google.com/search-console/welcome>

1. Rechts **URL-Präfix**, Adresse `https://zaehlora.pages.dev/`, **Weiter**.
2. Unter „Andere Bestätigungsmethoden" **HTML-Tag** aufklappen.
3. Die Zeile sieht so aus:
   `<meta name="google-site-verification" content="AbC…xyz" />`.
   **Den Wert in `content` in den Chat schicken** (er ist nicht geheim, er
   steht danach ohnehin im Quelltext der Startseite).
4. Das Fenster offen lassen. Sobald die Seite mit dem Code online ist, meldet
   Claude sich, dann **Bestätigen** drücken.

*Danach von allein:* Mit Punkt 4 meldet der Wochenbericht die Sitemap bei jedem
Lauf an. Ohne Punkt 4 einmal von Hand: in der Search Console links
**Sitemaps**, `sitemap.xml` eintragen, **Senden**.

## 4. Google-Dienstkonto (damit die Google-Zahlen von selbst kommen)

Einmalig rund fünf Minuten, danach nie wieder.

1. Projekt anlegen: <https://console.cloud.google.com/projectcreate>, Name
   `zaehlora`, **Erstellen**.
2. Schnittstelle einschalten:
   <https://console.cloud.google.com/apis/library/searchconsole.googleapis.com>
   → oben das Projekt `zaehlora` wählen → **Aktivieren**.
3. Dienstkonto: <https://console.cloud.google.com/iam-admin/serviceaccounts/create>
   → Name `zaehlora-bericht` → **Erstellen und fortfahren** → Rolle leer
   lassen → **Fertig**.
4. In der Liste das Dienstkonto öffnen → Reiter **Schlüssel** →
   **Schlüssel hinzufügen** → **Neuen Schlüssel erstellen** → **JSON**. Eine
   Datei wird geladen.
5. Den **ganzen Inhalt** dieser Datei als Geheimnis `GOOGLE_SC_SCHLUESSEL`
   eintragen. Danach die Datei löschen.
6. Die Adresse des Dienstkontos (endet auf `iam.gserviceaccount.com`, steht in
   der Liste) in der Search Console eintragen:
   <https://search.google.com/search-console/users> → Property
   `zaehlora.pages.dev` wählen → **Nutzer hinzufügen** → Adresse,
   Berechtigung **Vollständig** → **Hinzufügen**.

*Danach von allein:* Montags Suchbegriffe, Einblendungen, Klicks und Position
je Seite im Lauf „Website-Zahlen", und die Sitemap bei jedem Lauf gemeldet.

## 5. Berichtsschlüssel App Store Connect

Der vorhandene Schlüssel darf einreichen, aber keine Berichte lesen; Apple
antwortet 403. Die Rolle eines Schlüssels lässt sich nachträglich nicht ändern,
also ein zweiter:

<https://appstoreconnect.apple.com/access/integrations/api> → Reiter
**Team-Schlüssel** → **+**

- Name: `Zählora Berichte`
- Zugriff: **Admin**
- **Generieren**, dann in der Zeile **API-Schlüssel laden** (geht nur ein
  einziges Mal).

Zwei Geheimnisse:

- `ASC_BERICHT_KEY_ID` — die **Schlüssel-ID** aus der Zeile (zehn Zeichen)
- `ASC_BERICHT_KEY_P8` — der ganze Inhalt der geladenen `.p8`-Datei, von
  `-----BEGIN PRIVATE KEY-----` bis `-----END PRIVATE KEY-----`

Die Aussteller-ID ist dieselbe wie beim vorhandenen Schlüssel.

*Danach von allein:* Der tägliche Lauf „Zahlen" fordert die Berichte an,
**auch rückwirkend bis zum Start im Laden**, und zeigt ab dem Folgetag
Einblendungen, Seitenaufrufe und Ladungen.

## 6. Anbieterkennung für den Laden-Knopf

<https://appstoreconnect.apple.com/analytics> → die App → oben
**Akquisition** (oder „Acquisition") → **Kampagnen** → **Kampagnenlink
erstellen**. Irgendein Kampagnenname, dann steht ein Link da mit
`pt=123456789`. **Diese Zahl in den Chat schicken.** Sie ist nicht geheim.

*Danach von allein:* Der Knopf auf der Website trägt `ct=website-start`, und
App Store Connect zeigt unter „Kampagnen", wie viele über die Website kamen
und luden.

---

## Was schon von selbst läuft

- Website: bei jeder Änderung geprüft und veröffentlicht, IndexNow gemeldet
  (Bing, DuckDuckGo, Yandex).
- Zählung und Wochenbericht, sobald 1 erledigt ist.
- TestFlight, Einreichung, Werbetext: über die vorhandenen Schlüssel.
