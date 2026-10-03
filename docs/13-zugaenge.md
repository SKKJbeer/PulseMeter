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
| 1 | Analytics Engine einschalten | die Zählung auf der Website | **erledigt am 30. September**, Datensatz `zaehlora_aufrufe`, Bindung `ZAEHLUNG` |
| 2 | Leseschlüssel Cloudflare | Wochenbericht Website | **erledigt am 30. September**, erster Bericht gelaufen |
| 3 | Search Console | Google-Verzeichnis | offen |
| 4 | Google-Dienstkonto | Wochenbericht Google, Sitemap | offen |
| 5 | Berichtsschlüssel App Store Connect | täglicher Ablauf „Zahlen" | offen, scheitert seit dem 5. September |
| 6 | Anbieterkennung `pt` | Laden-Knopf auf der Website | offen |
| 7 | Domain `zaehlora.de` an die Website | Ablauf „Domain einrichten“ | **erledigt am 3. Oktober**, die Website steht unter `zaehlora.de`, die alten Adressen leiten weiter |

---

## 1. Analytics Engine einschalten (Cloudflare, ein Klick)

<https://dash.cloudflare.com/?to=/:account/workers/analytics-engine>

Dort **Enable** (oder „Set up"). Kostet nichts.

*Danach von allein:* Der nächste Lauf von „Website veröffentlichen" lädt mit
Zählung hoch. Bis dahin geht die Seite ohne Zählung online, und der Lauf sagt
es mit einer Warnung.

## 2. Leseschlüssel Cloudflare

Der Schlüssel zum Hochladen darf keine Statistik lesen: Am 26. September
antwortete Cloudflare darauf mit 403 „Authentication error". Es braucht also
einen eigenen, der nur lesen kann:

<https://dash.cloudflare.com/profile/api-tokens> → **Create Token** →
**Create Custom Token**

- Name: `Zählora Statistik`
- Permissions: **Account** · **Account Analytics** · **Read**
- sonst nichts, **Continue to summary** → **Create Token**

Als Geheimnis `CLOUDFLARE_STATISTIK_TOKEN`.

## 3. Search Console (Google)

<https://search.google.com/search-console/welcome>

1. Links **Domain**, dort `zaehlora.de` eintragen, **Weiter**. (Nicht
   „URL-Präfix“: Die Domain umfasst `www` und jede Unterseite.)
2. Google zeigt einen TXT-Eintrag, der so aussieht:
   `google-site-verification=AbC…xyz`. **Diese Zeile in den Chat schicken.**
   Sie ist nicht geheim, sie steht danach für jeden lesbar im DNS.
3. Das Fenster offen lassen. Claude schreibt den Eintrag über den Ablauf
   „Domain einrichten“ (Eingabe „Bestätigungscode“) zu Cloudflare und meldet
   sich, dann **Bestätigen** drücken.

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
   `zaehlora.de` wählen → **Nutzer hinzufügen** → Adresse,
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

## 7. Domain `zaehlora.de`

Gekauft bei netcup. Den Rest macht der Ablauf **„Domain einrichten“**
(`domain.yml`): Zone bei Cloudflare, DNS, Domain an die Website, und wenn
netcup es zulässt auch die Nameserver. Er braucht:

- **`CLOUDFLARE_DOMAIN_TOKEN`**: <https://dash.cloudflare.com/profile/api-tokens>
  → Create Custom Token, Name `Zählora Domain`, Permissions **Zone · Zone ·
  Edit**, **Zone · DNS · Edit**, **Zone · Zone Settings · Edit**, Zone
  Resources **All zones from an account**.
- Für den Versuch bei netcup drei Geheimnisse: `NETCUP_KUNDENNUMMER`,
  `NETCUP_API` (liegt seit 1. Oktober), `NETCUP_API_PASSWORT`. API-Key und API-Passwort stehen im
  netcup-Kundenbereich unter **Stammdaten → API**; das Passwort zeigt netcup
  nur beim Anlegen. Ohne die drei schreibt der Ablauf die beiden Nameserver
  in seine Zusammenfassung, und sie werden von Hand eingetragen.

**Von Hand bei netcup** (neu registrierte Domain, deshalb über ein Set; im
Reiter „Nameserver“ selbst gibt es kein Eingabefeld):

1. <https://www.customercontrolpanel.de> → links **Nameserver Set** →
   **Erstellen**. Name `Cloudflare`, dann `rita.ns.cloudflare.com` und
   `rudy.ns.cloudflare.com` eintragen, IP-Felder leer lassen, **Speichern**.
2. **Domains** → Lupe bei `zaehlora.de` → Reiter **Nameserver** → Typ
   **Eigene Nameserver verwenden** → Set `Cloudflare` → **Speichern**.

Quelle: netcup-Hilfe, „Eigene Nameserver hinterlegen (CloudDNS)“.

Erst wenn die Domain antwortet, stellt `scripts/domain-setzen.sh` die Adressen
in den Seiten um, und `zaehlora.pages.dev` leitet weiter. **Beides geschehen am
3. Oktober (0.118.10).** `NETCUP_API` wird seitdem nicht mehr gebraucht und darf
gelöscht werden, sobald kein anderes Projekt ihn über Punkt 8 übernehmen soll.

## 8. Dieselben Schlüssel in einem anderen Projekt

GitHub gibt ein Geheimnis nie wieder heraus, auch nicht dem Besitzer. Ein Lauf
kann es aber lesen und versiegelt in ein anderes Repository schreiben. Das macht
der Ablauf **„Geheimnisse weitergeben"** (`geheimnisse-weitergeben.yml`) für
`CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_DOMAIN_TOKEN`,
`CLOUDFLARE_STATISTIK_TOKEN` und `NETCUP_API`.

1. Das vorhandene Token `GH_PAT` um das Ziel erweitern, statt ein neues
   anzulegen: <https://github.com/settings/personal-access-tokens> → das Token
   → **Edit** → **Repository access** → das Ziel dazunehmen → **Update**. Es
   braucht dort **Secrets: Read and write**, das hat es schon.
2. <https://github.com/SKKJbeer/PulseMeter/actions/workflows/geheimnisse-weitergeben.yml>
   → **Run workflow** → Name des Ziels, zum Beispiel `Fortress` → **Run**.

Die Zusammenfassung des Laufs sagt je Schlüssel „übertragen" oder
„übersprungen". Die Werte stehen nirgends.

## Was schon von selbst läuft

- Website: bei jeder Änderung geprüft und veröffentlicht, IndexNow gemeldet
  (Bing, DuckDuckGo, Yandex).
- Zählung und Wochenbericht, sobald 1 erledigt ist.
- TestFlight, Einreichung, Werbetext: über die vorhandenen Schlüssel.
