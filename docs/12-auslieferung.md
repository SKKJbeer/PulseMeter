# 12 – Auslieferung: vom Code in den App Store, ohne Mac

Stand: 2026-08-22, Version 0.71.1

Am 17. August ist PulseMeter zum ersten Mal in TestFlight gelandet — **ohne
Kabel, ohne Xcode auf dem Rechner des Gründers, ohne einen Klick im
Entwicklerportal.** Gebaut, signiert und hochgeladen hat es ein macOS-Läufer bei
GitHub, gestartet mit einem Knopf im Browser.

Das hat **fünf Läufe** gebraucht. Vier davon sind an je einem echten Befund
gescheitert, und keiner dieser Befunde stand in einer Anleitung, die ich vorher
gelesen hätte. Dieses Dokument hält sie fest, damit das nächste Projekt sie
nicht neu bezahlt.

> **Gegenstück zu `08-baukasten.md`.** Der Baukasten beschreibt, wie geprüft
> wird. Dieses Dokument beschreibt, wie ausgeliefert wird. Beide sind
> unabhängig voneinander übertragbar.

---

## 1. Die eine Erkenntnis, die alles trägt

**Ein iOS-Projekt braucht keinen Mac, sondern einen macOS-Läufer.** Wer eine CI
mit `runs-on: macos-*` hat, hat den Mac schon — es fehlen nur zwei Dinge, und
beide gehen ohne Bildschirm:

- **Signieren** mit einem Schlüssel statt eines Anmeldefensters
  (`-authenticationKeyPath`, `-authenticationKeyID`, `-authenticationKeyIssuerID`).
- **Hochladen** mit `xcrun altool --upload-app --apiKey … --apiIssuer …`.

Meine erste Antwort auf die Frage „geht das nicht auch ohne Mac?" war im Kern
„nein, iOS-Apps brauchen Xcode". Das stimmt — und war trotzdem falsch, weil das
Projekt längst einen hatte. **Wenn eine Antwort auf eine Voraussetzung
verweist, prüfe zuerst, ob sie nicht schon erfüllt ist.**

---

## 2. Die Reihenfolge, die funktioniert

Alles im Browser, auch vom Telefon aus. Die Zahlen sind gemessen, nicht
geschätzt.

| # | Was | Wo | Dauer |
|---|---|---|---|
| 1 | API-Schlüssel in App Store Connect, Rolle **App Manager** | Browser | 5 min |
| 2 | Vier Geheimnisse im Repository: Key-ID, Issuer-ID, `.p8`-Inhalt, Team-ID | Browser | 5 min |
| 3 | **Verteilzertifikat einmalig** über die Schnittstelle anlegen und als Geheimnis ablegen | Ablauf | 2 min |
| 4 | **App-Eintrag** in App Store Connect anlegen | Browser | 10 min |
| 5 | Bauen, signieren, hochladen | Ablauf | 3 min |
| 6 | Exportbestimmungen, Testergruppe, Tester, Bau zuweisen | Browser | 5 min |

**Schritt 4 kommt vor Schritt 5, und das ist nicht offensichtlich:** Die
**App-ID** entsteht beim ersten Bau von selbst, der **App-Eintrag** nicht. Vor
dem ersten Bau steht die Kennung aber nicht in der Auswahlliste von App Store
Connect. Also: einmal bauen lassen (scheitert am Upload), dann den Eintrag
anlegen, dann erneut bauen. Oder Schritt 5 starten und den Eintrag anlegen,
während der Lauf läuft — das Zeitfenster reicht.

---

## 3. Die Befunde, in der Reihenfolge, in der sie zuschlagen

### 3.1 Die Bundle-ID gehört nicht auf eine fremde Domain

```
The app identifier "com.pulsemeter.app" cannot be registered to your
development team because it is not available.
```

`com.pulsemeter.app` war von einem anderen Team belegt. Umgekehrte
Namensschreibweise auf eine Domain, die man **nicht besitzt**, ist eine Wette
gegen alle anderen Apple-Entwickler der Welt — und `com.<produkt>.app` verliert
sie oft.

**Nimm den eigenen Namen:** `de.<nachname>.<produkt>`. Der kollidiert nicht.

**Und entscheide es vor allem anderen.** Die Kennung steckt in der Projektdatei,
in beiden Berechtigungsdateien, in der App-Gruppe, im iCloud-Container, in jeder
Kauf-Kennung, in Tests und Skripten — bei uns an **27 Stellen**. Solange in App
Store Connect noch keine App und kein Kauf existiert, ist das ein Suchen und
Ersetzen. Danach ist es unmöglich, ohne jeden Käufer seinen Kauf zu kosten.

### 3.2 `xcodebuild archive` will ein Development-Profil

```
Communication with Apple failed: Your team has no devices from which to
generate a provisioning profile.
```

**Das ist der teuerste Befund des Tages.** Mit `CODE_SIGN_STYLE=Automatic`
besorgt sich `archive` ein **Development**-Profil und signiert erst beim
Ausführen auf Verteilung um. Ein Entwicklungsprofil verlangt mindestens ein
registriertes Gerät. Ein Konto ohne Kabel hat keins. **Dieser Weg kann nie
durchgehen.**

**Meine erste Erklärung war falsch**, und sie hat einen Lauf gekostet: Ich
hielt die fehlende Angabe `-configuration Release` für die Ursache. Sie wurde
übergeben, und die Meldung blieb wörtlich dieselbe. **Die Profilart hängt nicht
an der Konfiguration.**

Der Ausweg ist **manuelle Signierung**:

1. App-Store-Profile über `POST /v1/profiles` (`profileType: IOS_APP_STORE`)
   anlegen, mit dem Verteilzertifikat verknüpft.
2. Inhalt nach `~/Library/MobileDevice/Provisioning Profiles/<uuid>.mobileprovision`.
3. Bauen mit `CODE_SIGN_STYLE=Manual`,
   `CODE_SIGN_IDENTITY="Apple Distribution"` und
   `PROVISIONING_PROFILE_SPECIFIER` **je Ziel**.

### 3.3 Bauvorgaben auf der Kommandozeile gelten für **alle** Ziele

`CODE_SIGN_ENTITLEMENTS=…` oder `PROVISIONING_PROFILE_SPECIFIER=…` hinter
`xcodebuild` trifft App **und** Erweiterung. Das Widget bekäme dann die
iCloud-Berechtigung der App, die seine eigene Kennung nicht hat.

**Also je Ziel in der Projektdatei, über Variablen:**

```yaml
settings:
  base:
    PULSE_PROFILE_APP: ""          # leer = automatisch, für Simulator und CI
    PULSE_PROFILE_WIDGET: ""
targets:
  App:
    settings: { base: { PROVISIONING_PROFILE_SPECIFIER: $(PULSE_PROFILE_APP) } }
  Widget:
    settings: { base: { PROVISIONING_PROFILE_SPECIFIER: $(PULSE_PROFILE_WIDGET) } }
```

Der Lauf übergibt dann nur die Variablen. Dasselbe Muster trägt
`aps-environment`: `development` in Debug, `production` in Release — fest
eingetragen ist einer der beiden Wege immer falsch.

### 3.4 Berechtigungen brauchen Häkchen an der App-ID

App-Gruppe, iCloud und Push müssen an der App-ID im Portal freigeschaltet sein,
sonst lehnt Apple das **Profil** ab — nicht den Bau, das Profil, und die Meldung
sagt es nicht deutlich.

**Die erste Auslieferung darf ohne sie fahren.** Wir haben die
Berechtigungsdateien für den ersten Bau leer gelassen: Die App läuft
vollständig, nur das Widget bleibt leer und der iCloud-Abgleich aus. Für beides
gab es im Code schon einen Rückfall. **Die zwei Wochen echte Eigennutzung sind
mehr wert als der Abgleich** — sie können sofort anfangen, und die Häkchen
kommen später.

Voraussetzung dafür: Der Code muss den Ausfall aushalten. Bei uns tut er es in
drei Stufen — iCloud, sonst lokal, sonst flüchtig —, und die **mittlere** Stufe
ist die wichtige. Ohne sie fiele der Simulator auf einen flüchtigen Speicher
zurück, die App würde nichts sichern, und **jede** Oberflächenprüfung wäre rot,
ohne dass irgendwo der Grund stünde.

### 3.5 Der Läufer hat mehrere Xcodes, und das voreingestellte ist zu alt

```
Validation failed (409) SDK version issue. This app was built with the
iOS 18.5 SDK. All iOS and iPadOS apps must be built with the iOS 26 SDK
or later.
```

Der Läufer stand auf Xcode 16.4, obwohl 26.3 daneben lag. **Nie das
voreingestellte Xcode nehmen.** Die höchste vorhandene Fassung suchen, per
`xcode-select` setzen — und wenn keine reicht, **auflisten, was da ist**, statt
mit einer Vermutung über das Läuferbild neu zu starten.

### 3.6 Hochgeladen ist nicht testbar

Vier getrennte Dinge, und jedes einzelne hält den Bau unsichtbar:

1. **Exportbestimmungen** beantworten. Ohne das steht der Bau auf „Missing
   Compliance" und **kein Tester sieht ihn**.
2. Eine **Gruppe für interne Tests** anlegen.
3. **Sich selbst als Tester eintragen** — Kontoinhaber zu sein genügt nicht.
   Das war bei uns der letzte Stolperstein.
4. Den **Bau der Gruppe zuweisen**.

---

## 4. Was wann in TestFlight lag

`CHANGELOG.md` sagt, was sich geändert hat. Diese Tabelle sagt, **was auf einem
Telefon gelandet ist** — das ist eine andere Frage, und sie stand bis 0.69.2
nirgends.

Die **Buildnummer ist die Laufnummer** des Arbeitsablaufs
(`CURRENT_PROJECT_VERSION=${{ github.run_number }}`), nicht die Version. Sie
zählt auch bei einem gescheiterten Lauf weiter; die Nummern 1 bis 4 hat App
Store Connect deshalb nie gesehen.

| Build | Version | Datum | Ergebnis | Was neu war |
|---|---|---|---|---|
| 1 | 0.59.1 | 17.08. 09:53 | ✗ | Erster Versuch überhaupt. Bezeichner `com.pulsemeter.app` war bei Apple vergeben |
| 2 | 0.60.0 | 17.08. 10:00 | ✗ | Neuer Bezeichner `de.karjoth.pulsemeter`; Archiv suchte ein Entwicklungsprofil |
| 3 | 0.60.1 | 17.08. 10:08 | ✗ | Verteilprofile über die API; dasselbe Profil-Problem |
| 4 | 0.60.1 | 17.08. 10:18 | ✗ | Wiederholung; Apple lehnte das iOS-18-SDK ab |
| 5 | 0.60.2 | 17.08. 10:25 | ✓ | **Erster Build auf dem Gerät.** Xcode 26 wird jetzt selbst gewählt |
| 6 | 0.62.1 | 17.08. 12:08 | ✓ | Herunterladen-Menü im Verlauf, CSV und PDF |
| 7 | 0.64.0 | 17.08. 18:13 | ✓ | Datum **und Uhrzeit** bei der Ablesung; mehrere Einträge pro Tag |
| 8 | 0.66.0 | 18.08. 06:56 | ✓ | Szenarienprüfungen, Kontraste nach AA, Schaltjahr-Fehler im Vergleich behoben |
| 9 | 0.67.2 | 21.08. 19:41 | ✓ | Hochrechnung für den laufenden Monat, erste Fassung |
| 10 | 0.69.2 | 22.08. 11:43 | ✓ | Der laufende Monat als eigene Leiste unter dem Verlauf |
| 11 | 0.69.2 | 22.08. 14:57 | ✗ | Abgebrochen: derselbe Stand ein zweites Mal geschickt, weil ich nicht nachgesehen hatte, ob Build 10 schon lief |

Zeitangaben in UTC. Ein ✗ heißt: hochgeladen wurde nichts, die Nummer ist
trotzdem verbraucht.

### Was bei den Testern steht

`altool --upload-app` lädt nur hoch. Die Testhinweise — „Was ist neu" — hängen
nicht am Paket, sondern am Bau in App Store Connect, und dorthin führt nur die
Schnittstelle. Erreichbar sind sie erst, wenn Apple den Bau verarbeitet hat.

Der Ablauf fragte von Anfang an nach diesem Text und schrieb ihn nirgends hin.
Zehn Bauten lang stand bei den Testern nichts. Seit 0.70.0 trägt
`scripts/asc-testflight.py` ihn nach dem Hochladen ein: Es wartet auf die
Verarbeitung, legt die Lokalisierung `de-DE` an oder ändert sie und meldet, wann
der Bau bereitsteht. Dauert die Verarbeitung länger als zwanzig Minuten, endet
das Skript grün mit einem Hinweis — der Bau kommt trotzdem an, und ein roter
Lauf für etwas, das niemand beheben kann, wäre eine Meldung ohne Handlung.

**Was der Ablauf bewusst nicht tut:** Er gibt nichts für **externe** Tester
frei. Das verlangt eine Beta-Prüfung durch Apple und ist eine Entscheidung,
keine Automatisierung. Für die interne Gruppe steht der Bau nach der
Verarbeitung sofort bereit.

**Die Zeile kommt nach jedem Lauf dazu, auch nach einem gescheiterten.** Ohne
sie lässt sich eine Rückmeldung vom Gerät nicht zuordnen: „bei mir sieht das
anders aus" ist ohne „welcher Build?" nicht zu beantworten, und die Antwort
steht sonst nirgends.

---

## 5. Die Kleinigkeiten, die je einen Lauf kosten

| Falle | Was zu tun ist |
|---|---|
| **Buildnummer doppelt** | App Store Connect nimmt jede Nummer **einmal**. `CURRENT_PROJECT_VERSION=${{ github.run_number }}` |
| **Drei Zertifikate, dann Schluss** | Zertifikat **einmal** anlegen und als Geheimnis ablegen. Ein frischer Läufer legt sonst jedes Mal ein neues an |
| **PKCS#12 lässt sich nicht einlesen** | `openssl pkcs12 -export -legacy`. OpenSSL 3 erzeugt sonst ein Format, das der Schlüsselbund mit „MAC verification failed" ablehnt — das sieht nach falschem Kennwort aus und ist keins |
| **`codesign` wartet auf ein Kennwort** | `security set-key-partition-list -S apple-tool:,apple:,codesign:` nach dem Import. Ohne das läuft der Auftrag in die Zeitgrenze |
| **Falsches Profil am falschen Ziel** | Apples `filter[identifier]` filtert als **Präfix**: Die Abfrage nach `de.x.app` liefert auch `de.x.app.widget`. Genau vergleichen, nicht das erste Ergebnis nehmen |
| **Zugangsdaten fehlen** | Die Prüfung darauf als **ersten** Schritt. Sonst läuft der Auftrag zwanzig Minuten und scheitert an einer Meldung, die nicht sagt, welches Geheimnis fehlt |

---

## 6. Geheimnisse schreiben, nicht abtippen

Ein Verteilzertifikat als Base64 sind rund viertausend Zeichen. Die aus einem
Protokoll in ein Formularfeld zu übertragen — auf einem Telefon — ist keine
Automatisierung, und ein privater Schlüssel, der durch die Zwischenablage geht,
liegt danach in der Zwischenablage.

GitHub nimmt Geheimnisse nur **versiegelt** an: öffentlichen Schlüssel des
Repositories holen, Wert in eine Sealed Box legen, `PUT` auf
`/actions/secrets/<name>`. Der Klartext verlässt den Lauf nie.

Dafür braucht der Ablauf ein **fein granuliertes** Token mit
„Secrets: Read and write". Ein klassisches Token mit `repo` genügt **nicht** —
das ist die häufigste Verwechslung.

**Ein Token mit Schreibrecht auf Geheimnisse ist nicht nichts.** Deshalb gibt es
den Weg auch ohne: dann legt der Ablauf die Werte als Artefakt ab und jemand
trägt sie von Hand ein. Diese Wahl gehört dem Betreiber, nicht dem Werkzeug.

---

## 7. Was das Vorgehen an sich gelehrt hat

**Der Fehlschlag ist die Auskunft.** Fünf Läufe, vier Befunde — und **zweimal
war meine Vermutung falsch und das Protokoll richtig**: einmal bei
`-configuration Release`, einmal bei der Ursache des roten Oberflächentests. Der
Reflex, aus einer Meldung eine Erklärung zu bauen und danach zu handeln, hat
mehr gekostet als das Lesen.

**Ein schneller Fehlschlag ist billig.** Die Läufe scheiterten nach 80 bis 130
Sekunden. Bei dieser Länge lohnt es, zu probieren statt zu grübeln. Genau
deshalb gehört die Zugangsprüfung nach vorn: Sie macht den billigen Fehlschlag
noch billiger.

**Zwei rote Läufe mit derselben Meldung sind kein Fortschritt.** Beim zweiten
Mal derselben Diagnose ist die Ursache nicht im Code — dann melden statt
basteln. Bei uns fehlte der App-Eintrag, und den kann kein Skript anlegen.

**Eine Prüfung, die grundlos anschlägt, ist schlechter als keine.** Nach vier
Fehlern durch ein deutsches Anführungszeichen mit **geradem** Schlusszeichen
habe ich eine Suche nach dem Muster gebaut. Sie fand 24 Stellen, von denen keine
einzige schadete — in einem Kommentar ist das Zeichen harmlos. Die richtige
Prüfung testet nicht das Zeichen, sondern die **Folge**: Python übersetzen,
YAML laden, **jeden `run:`-Block durch `bash -n`**. Dieselbe Lehre wie bei den
wackligen Oberflächenprüfungen, nur in einer anderen Sprache.

---

## 8. Auf ein neues Projekt übertragen

Vier Dateien tragen das Ganze. Auszutauschen ist darin nur die Kennung.

| Datei | Was sie tut |
|---|---|
| `.github/workflows/zertifikat.yml` | Einmal: Schlüsselpaar, Zertifikat über die Schnittstelle, PKCS#12, als Geheimnis |
| `.github/workflows/testflight.yml` | Jedes Mal: Xcode wählen, Zugang prüfen, Zertifikat einlesen, Profile anlegen, archivieren, ausführen, hochladen |
| `scripts/asc-zertifikat.py` | Spricht mit Apple über Zertifikate |
| `scripts/asc-profil.py` | Spricht mit Apple über Profile |
| `scripts/gh-geheimnis.py` | Versiegelt und schreibt Repository-Geheimnisse |

Dazu in der Projektdatei: `PROVISIONING_PROFILE_SPECIFIER` und
`CODE_SIGN_ENTITLEMENTS` je Ziel als Variable, leer als Vorgabe.

**Und die Reihenfolge aus Abschnitt 2 einhalten.** Sie ist nicht beliebig — sie
ist das, was von fünf Fehlschlägen übrig geblieben ist.
