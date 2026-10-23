# Kamera: Fotos, Befund und Regeln

Die Kamera (1.6, `05-roadmap.md`) liest einen Zählerstand aus einem Foto und
**schlägt ihn vor**. Der Nutzer bestätigt oder tippt selbst. Dieses Verzeichnis
hält fest, was wir über Zählerfotos wissen, bevor die Kamera in der App steht,
und womit sie geprüft wird.

## Was hier liegt

| Datei | Was |
|---|---|
| `fotos/` | 15 Zählerfotos von Wikimedia Commons, frei lizenziert, verkleinert auf 900 Pixel Breite |
| `fotos.json` | je Foto: Quelle, Urheber, Lizenz, **Soll-Stand** (von Hand abgelesen), Stellen des Zählwerks, was die Falle ist, bei lesbaren Anzeigen der Rahmen um das Display (`ausschnitt`) |
| `vektoren.json` | 46 Fälle für den Leser, dazu Folgen für die Einigung über mehrere Bilder, die Swift und der Klick-Dummy beide bestehen müssen |
| `vision-gelesen.json` | was Vision auf den Fotos wirklich gelesen hat (macOS-Läufer, 21.10.2026); `MeterTextReaderVisionTests` liest sie |
| `lcd-vektoren.json` | Referenzbilder und -ausgaben des Ziffernnetzes (aus Python), die Swift und der Klick-Dummy bestehen müssen; geschrieben von `scripts/kamera-netz/golden.py` |

`scripts/check-kamerafotos.py` bricht ab, wenn bei einem Foto Urheber, Quelle oder
eine freie Lizenz fehlt oder ein Foto im Ordner liegt, das nicht in `fotos.json`
steht. Die Fotos sind **nur Prüfmaterial**, nicht Teil der App.

## Befund: Was auf einem Zählerfoto steht

Bei Commons wurde nach „Stromzähler", „Gaszähler", „Wasserzähler", „smart
meter" und Verwandtem gesucht (122 frei lizenzierte Treffer), 48 davon ausgewählt,
41 ließen sich laden und ansehen, 15 kamen in die Sammlung. Beim Ablesen der
Soll-Stände habe ich zweimal falsch gelesen, und beide Male war es eine Falle,
die auch die Kamera trifft, dazu kommen die Rollen:

1. **Ein Display zeigt nicht immer den Stand.** Foto 01: „27:08:22" über dem Wort
   DATE. Als Zahl gelesen wären das 270.822 kWh.
2. **Ein kleiner Punkt entscheidet um den Faktor 100.** Foto 27: „00004.67 kWh",
   ich las zuerst 467.
3. **Rollen stehen manchmal halb gedreht.** Foto 11 (Gas, die dritte rote Rolle)
   und Foto 43 (Wasser, die vierte Rolle zwischen 1 und 2). Welche Ziffer gilt,
   sieht nur, wer hinsieht.

Dazu das Typenschild. Auf einem ganzen Foto liest eine Texterkennung zuerst und
am zuverlässigsten **das, was nicht der Stand ist**: Seriennummern (`2812689`,
`86122566`, ein Strichcode mit 16 Ziffern), die Eigentumsnummer des
Netzbetreibers (`6.047.178`), Impulskonstanten (`5000 Imp/kWh`), Baujahr
(`2024`), Spannung (`230V`), Stromstärke (`10(60) A`).

**Tesseract als Gegenprobe** (nicht Apples Vision, aber eine echte Engine mit
echtem Rauschen, die hier unter Linux läuft):

| | gefunden |
|---|---|
| ganzes Foto, 9 Fotos mit ablesbarem Stand | **1 von 9** (der Gaszähler) |
| von Hand gewählter Ausschnitt um das Display, 7 Fotos | **0 von 7**, bei Foto 32 sogar `9357` statt `1936` |

Das sagt etwas über Tesseract (Siebensegment-Anzeigen sind seine bekannte
Schwäche), **nichts über Vision**. Es sagt aber zwei Dinge über den Entwurf:

- **Der Erkennungskern darf nichts voraussetzen.** Er bekommt, was auch immer
  gelesen wurde, und muss mit Rauschen und Fehlern leben. Bei Foto 32 hätte eine
  Engine mit `9357` eine plausible, falsche Zahl geliefert.
- **Ob die Kamera auf LCD-Zählern taugt, ist offen**, bis Vision auf dem Mac
  an denselben Fotos gemessen ist. Fällt Vision auf Siebensegment-Anzeigen
  ähnlich ab, braucht Stufe 2 (Sucher mit Rahmen) eine eigene Ziffernerkennung
  für Siebensegment, die mit Bildpunkten arbeitet statt mit Text.

## Gemessen: Vision auf dem ganzen Foto (21. Oktober 2026)

`kamera-messen` auf dem macOS-Läufer von GitHub (macOS 15.7, `VNRecognizeTextRequest`,
genaue Stufe, ohne Sprachkorrektur). Was Vision je Foto gelesen hat, steht in
`vision-gelesen.json`; `MeterTextReaderVisionTests` hält daran fest, dass der
Leser nie etwas Falsches vorschlägt, auch ohne Mac.

| | richtig | teilweise | nichts | **falsch** |
|---|---|---|---|---|
| Erste Ablesung (ohne Bereich) | 1 | 0 | 14 | **0** |
| Zweite Ablesung (mit Bereich) | 1 | 1 | 13 | **0** |

*Teilweise:* der Siemens-Rollenzähler, `65521` mit Sicherheit 1,0; die rote 9 liest
Vision als eigenes Stück mit 0,3. Vorgeschlagen wird die Vorkommazahl mit dem
Kennzeichen, dass die rote Stelle fehlt.

**Was dahintersteckt**

- **Rollen liest Vision mit Sicherheit 1,0, Siebensegment mit 0,3.** Richtig gelesen
  sind `9023 kWh` (Aidon), `14426` (Kamstrup, mit zerlesener Einheit `:uh`), `00047,3 6 65`
  (Gas); falsch gelesen ist `1935**` statt `1936` (Foto 32). **Alle vier tragen 0,3.**
  Die Sicherheit trennt also Richtiges nicht von Falschem, und die Schwelle des
  Lesers hält die falsche Ziffer heraus, die richtigen mit. Das ist gewollt: Eine
  falsche Ziffer ist schlimmer als keine.
- **Ein ganzes Foto aus der Hand liest bei LCD-Zählern fast nichts.** Von 9 Fotos mit
  Stand wird eines ganz und eines teilweise vorgeschlagen. Stufe 1 trägt damit
  Rollenzähler und große Ziffern, nicht die LCD-Zähler, die in Deutschland am
  häufigsten hängen.
- **Das Datum im Display (Foto 01) liest Vision als `270822` mit 0,5**, ohne die
  Doppelpunkte, die Tesseract noch sah. Es bleibt trotzdem draußen: ohne Einheit,
  ohne Komma, ohne führende Null.
- **Der Weg zu LCD-Zählern ist nicht der Rahmen allein.** Siehe den nächsten Abschnitt.

## Gemessen: Vision nur auf dem Rahmen um das Display (21. Oktober 2026)

`kamera-messen --ausschnitt`: dasselbe, aber Vision bekommt nur das von Hand gesetzte
Rechteck um die Anzeige (`ausschnitt` in `fotos.json`), so wie ein Sucher es setzte.
Gelesen steht in `vision-ausschnitt-gelesen.json`.

| | richtig | teilweise | nichts | **falsch** |
|---|---|---|---|---|
| Erste Ablesung (ohne Bereich) | 1 | 0 | 14 | **0** |
| Zweite Ablesung (mit Bereich) | 1 | 1 | 13 | **0** |

**Dieselben Zahlen wie auf dem ganzen Foto.** Der Rahmen bringt für den Leser nichts.
Was Vision im Rahmen liest, zeigt warum:

| Foto | steht im Display | Vision im Rahmen |
|---|---|---|
| 32 grünes Display | 1936 | `1936` (0,5) **richtig**, auf dem ganzen Foto war es `1935**` |
| 29 Kamstrup | 14426 | `Đ0 19426 :WA` (0,3) — **eine Ziffer falsch** (4→9) |
| 02 Aidon | 9023 kWh | `E208` (0,3) — auf dem ganzen Foto stand `9023 kWh` |
| 25 Landis, 27 Meterus, 04 Logarex | 002426, 4,67, 000000 | **keine Ziffer** gelesen |
| 07 Siemens-Rollen | 65521,9 | `65521` (0,5), die rote Rolle fehlt |

**Das heißt:**

- **Vision ist für Siebensegment-Anzeigen kein verlässlicher Leser**, ob ganzes Foto oder
  Ausschnitt. Es liest sie mal richtig, mal gar nicht, mal mit einer falschen Ziffer,
  und die Sicherheit (0,3 bis 0,5) verrät nicht, welcher Fall vorliegt. Ein Rahmen
  macht es nicht besser, im Fall Aidon sogar schlechter (Vision braucht Umgebung).
- **Mehrere Bilder hintereinander** (Stufe 2) können das teilweise auffangen: Dieselbe
  Zahl in drei Bildern ist ein stärkeres Zeichen als eine Lesung mit 0,3. Aber auch das
  trägt nur, wo Vision überhaupt Ziffern liest; bei Landis, Meterus und Logarex las es
  keine.
- **Rollenzähler und große Ziffern liest Vision brauchbar** (Siemens, OpenWay, Gas),
  mit der Einschränkung, dass die roten Stellen oft als eigenes Stück oder gar nicht
  kommen.
- **Für die LCD-Zähler, die in Deutschland am häufigsten hängen, braucht es eine
  eigene Ziffernerkennung für Siebensegment** (Bildpunkte statt Text: Anzeige finden,
  Ziffernfelder trennen, je Feld die sieben Segmente prüfen). Das ist ein
  überschaubares, klassisches Verfahren; ob es auf diesen Fotos trägt, lässt sich wie
  Vision hier messen, **zuerst als Versuch unter Linux** in Python an den 15 Fotos,
  bevor etwas in Swift entsteht.

## Gemessen: das eigene Ziffernnetz (22. Oktober 2026)

Apples Texterkennung trägt Siebensegment-Anzeigen nicht (oben). Deshalb liest in der App ein
**eigenes Netz** (`DigitNet`, 250 000 Gewichte) den Ausschnitt im Rahmen, den der Nutzer im
Sucher auf die Ziffern legt. Es ist auf **nachgebauten** Anzeigen trainiert
(`scripts/kamera-netz/`) und an diesen Fotos nur **geprüft**; kein Foto hat je ein Gewicht
bewegt. Gemessen wird, was der Nutzer erlebt: sechs leicht verwackelte Sucherbilder, drei
gleiche nötig (`ReadingConsensus`), der Leser im Modus „eingerahmt“, je Foto 100 Versuche mit
anderem Rahmen (`scripts/kamera-netz/evaluate.py`, Rohdaten in `netz-messung.txt`).

| Foto | Anzeige | zweite Ablesung (Bereich um den Stand) | erste Ablesung (ohne Bereich) |
|---|---|---|---|
| 02 Aidon | `9023`, blass, grau | **99 / 100** richtig | 0, kein Merkmal (siehe unten) |
| 04 Logarex | `000000`, groß | **100 / 100** | **100 / 100** |
| 25 Landis | `002426`, Glanz | **97 / 100** | **95 / 100** |
| 28 Openway | `00000`, daneben `004` | **98 / 100** | **56 / 100** |
| 32 grünes Display | `1936`, schlechtes Licht | **99 / 100** | 0, kein Merkmal |
| 27 Meterus | `00004.67`, schräg, große Tarifziffer links | 0 (nichts gelesen) | 0 |
| 29 Kamstrup | `0014426`, klein, ungewöhnliche Schrift | 0 (nichts gelesen) | 0 |
| 01 Datum | `27:08:22` | nie ein Vorschlag | nie ein Vorschlag |
| 06 leeres Display | nichts | nie ein Vorschlag | nie ein Vorschlag |
| **zusammen (7 Fotos mit Stand)** | | **493 richtig, 0 falsch, 207 nichts** (von 700) | **251 richtig, 0 falsch, 649 nichts** (von 900) |

**Was das heißt**

- **Nie etwas Falsches in 1 600 Versuchen**, auch beim Datum und beim leeren Display. Das ist die
  Zusage der App. Eine Erkennungsquote von 100 % ist es nicht: **Fünf von sieben
  Anzeigen liest sie fast immer, zwei gar nicht.** Bei diesen beiden sagt die App nichts, und
  der Nutzer tippt.
- **Warum die erste Ablesung strenger ist.** Ohne Bereich zählt nur eine Zahl mit führender Null,
  Komma oder Einheit. Das Display zeigt auch Datum und Uhrzeit, und das Netz liest die
  Doppelpunkte nicht immer: `270822` wäre ein erfundener Stand von 270.822 kWh. Eine erste
  Ablesung tippt man einmal je Zähler; die Kamera hilft ab der zweiten. Aidon (`9023`) und das
  grüne Display (`1936`) haben kein Merkmal und fallen deshalb bei der ersten Ablesung heraus.
- **Ein verlorener Punkt macht aus 4,67 ein 467.** Das Netz las im Zwischenstand bei Meterus einmal
  `467` (Faktor 100). Seitdem gilt: Hat das Zählwerk Nachkommastellen und ist die gerahmte Zahl
  ohne Komma breiter als der Vorkommateil, schlägt die App nichts vor (Fälle `gerahmt-verlorener-punkt-…`
  in `vektoren.json`). Davor lag die Zahl bei einem falschen von 360.
- **Meterus und Kamstrup** scheitern an unterschiedlichem: Bei Meterus liest das Netz die große
  Tarifziffer links mit, bei Kamstrup stehen Einheit und Ziffern in einer Schrift, die kein
  Trainingsbild hatte. Beides sind Trainingsdaten, die fehlen, kein Fehler im Aufbau.
- **Gerechnet wurde auf Fotos von Wikimedia** (zum Teil 430 Punkte breit). Eine Kamera liefert die
  Ziffern in voller Auflösung; die Messung ist in dieser Hinsicht eher zu streng.
- **Ungeprüft: ein iPhone.** Die Rechnung ist in Swift ausgeschrieben und gegen Python
  geprüft (`DigitNetTests`, 18 Referenzbilder); wie scharf, hell und ruhig ein echtes Kamerabild
  im Rahmen ist, zeigt erst TestFlight.

**Was auf dem Weg gelernt wurde.** Handgebaute Bildverarbeitung (Schwelle, Komponenten, Segmentprobe)
las an denselben Fotos 0 von 9. Das Netz wurde erst gut, als im Generator die Nebenzeichen
dazukamen, die in echten Anzeigen neben der Zahl stehen (Einheit, Kennzahl `1.8.0`, kleine Ziffern,
eine große Tarifziffer, Symbole), dazu Datum und Uhrzeit mit Doppelpunkt, gedruckte Ziffern als
„nichts“ und Lücken in der Faltung entlang der Zeile (das Netz muss die ganze Zeile sehen, um
die kleine `004` neben der großen Zahl zu überhören). Nach jeder Messung wurden die Fehler angesehen
und der Generator geändert, nicht das Netz auf die Fotos zugeschnitten.

**Wiederholen.** `scripts/kamera-netz/README.md`.

## Die Regeln des Lesers (`MeterTextReader`)

Eingabe ist der Text, den die Texterkennung geliefert hat, dazu die Stellen des
Zählwerks und, wenn es einen letzten Stand gibt, der Bereich, in dem der neue
liegen kann. Ausgabe ist **ein** Vorschlag oder **keiner**, mit Grund.

1. **Was als Stand gilt:** nur Ziffern, höchstens ein Komma oder Punkt, höchstens
   eine Einheit dahinter, und es passt zum Zählwerk (nicht mehr Vorkomma- und
   nicht mehr Nachkommastellen). Buchstaben mittendrin, Schrägstrich, Bindestrich,
   Doppelpunkt, zwei Trennzeichen: Typenschild oder Kennzahl.
2. **Stark oder schwach:** stark ist eine Zahl so breit wie das Zählwerk (mit
   führenden Nullen) oder mit Einheit. Schwach (`1936`) wird nur mit Bereich
   vorgeschlagen, wenn sie darin die einzige ist, und braucht mehr Sicherheit.
3. **Ohne Bereich (erste Ablesung)** zählt zusätzlich nur, was Einheit, Komma
   oder führende Null hat. Eine sechsstellige Seriennummer sieht sonst aus wie
   ein Stand.
4. **Zwei verschiedene Zahlen im Rennen: kein Vorschlag.** Dieselbe Zahl zweimal
   gelesen ist keine Mehrdeutigkeit.
5. **Passt eine starke Zahl nicht in den Bereich, springt keine schwache ein.**
   Sonst würde die Kennzahl „180" (die OBIS-Kennung `1.8.0`, die manche Displays
   als „180" zeigen) zum Stand eines Zählers, der nur weiter gelaufen ist als erwartet.
6. **Siebensegment-Verwechslungen** (O/0, I/1, S/5, B/8, Z/2) werden nur dort
   korrigiert, wo der Rest klar nach Zahl aussieht.

Den Bereich berechnet der Aufrufer: vom letzten Stand bis zum Vierfachen des
üblichen Verbrauchs seit dann. Das ist dieselbe Grenze, ab der die Prüfung im
Ziffernblock fragt „Stimmt die Zahl?".

**Bekannte Grenze.** Die Stellenzahl des Zählwerks kommt aus den Einstellungen.
Steht ein Siemens-Zähler mit 5+1 Stellen auf der Voreinstellung 6+2, wird aus
`655219` ein Stand von 655.219. Beim ersten Stand fängt das niemand ab, danach
der Bereich. Die Kamera sollte deshalb bei der ersten Ablesung die Stellenzahl
mit dem Foto vergleichen und nachfragen, wenn die Ziffernzahl nicht passt.

## Was noch fehlt (Stand 0.138.0)

- **Meterus und Kamstrup** (oben): mehr Trainingsbilder dieser Art, am besten **echte Fotos von
  Testern**, damit auch das Netz an Anzeigen gemessen wird, die niemand nachgebaut hat. Die
  Fotos der Tester kommen **nicht** in die App und nicht ungefragt ins Repository.
- **Ein Kamerabild vom iPhone**: Erst ein Bau in TestFlight zeigt, ob Schärfe, Licht und
  Handzittern so sind wie im Versuch.
- **Datenschutzerklärung und Store-Texte** dürfen die Kamera erst nennen, wenn sie im Laden ist
  (CLAUDE.md, Regel 4a). Vor dem Einreichen von 1.6: Absatz zur Kamera in
  `docs/website/datenschutz.html` („Bilder werden nur auf dem Gerät ausgewertet, nicht gespeichert,
  nicht übertragen“) und in `09-appstore.md`. Technisch stimmt der Satz heute schon
  (`scripts/check-sicherheit.sh` hält ihn).
- **Der Kauf** (0,99 €, Teil von „Alles freischalten“): Die Kaufkennung ist in App Store Connect
  noch nicht angelegt. Bis dahin ist die Kamera in TestFlight für alle frei.

## Namensnennung

Alle Fotos von [Wikimedia Commons](https://commons.wikimedia.org/), jeweils mit
der angegebenen Lizenz. Verkleinert (900 Pixel Breite, JPEG); sonst unverändert.
Fotos unter CC BY-SA bleiben unter CC BY-SA, die Lizenztexte stehen bei der
Quelle.

| Datei | Art | Soll | Stellen | Quelle | Urheber | Lizenz |
|---|---|---|---|---|---|---|
| `fotos/01-landis-datum.jpg` | Strom, LCD zeigt das Datum | — | 6+0 | [Digital Economy 7 electricity meter.jpg](https://commons.wikimedia.org/wiki/File:Digital_Economy_7_electricity_meter.jpg) | NoahLovesNesquick | CC BY-SA 4.0 |
| `fotos/02-aidon-5530.jpg` | Strom, LCD | 9023 | 6+0 | [Electronic elecricity meter IMG 6895.JPG](https://commons.wikimedia.org/wiki/File:Electronic_elecricity_meter_IMG_6895.JPG) | Gegik | CC BY-SA 3.0 |
| `fotos/04-logarex-nullen.jpg` | Strom, LCD, neuer Zähler | 0 | 6+0 | [Logarex smart household electricity meter build year 2023.jpg](https://commons.wikimedia.org/wiki/File:Logarex_smart_household_electricity_meter_build_year_2023.jpg) | RobbieIanMorrison | CC BY 4.0 |
| `fotos/06-logarex-leer.jpg` | Strom, LCD ohne Anzeige | — | 6+0 | [Logarex smart household electricity meter build year 2023 no display.jpg](https://commons.wikimedia.org/wiki/File:Logarex_smart_household_electricity_meter_build_year_2023_no_display.jpg) | RobbieIanMorrison | CC BY 4.0 |
| `fotos/07-siemens-rollen.jpg` | Strom, Ferraris mit Rollenzählwerk | 65521.9 | 5+1 | [Siemens household electricity meter electromechanical induction type.jpg](https://commons.wikimedia.org/wiki/File:Siemens_household_electricity_meter_electromechanical_induction_type.jpg) | RobbieIanMorrison | CC BY 4.0 |
| `fotos/11-metrix-gas.jpg` | Gas, Rollenzählwerk | 47.36 | 5+2 | [20190918 192129 Gas meter in Lodz, Poland 2019.jpg](https://commons.wikimedia.org/wiki/File:20190918_192129_Gas_meter_in_Lodz,_Poland_2019.jpg) | Rakoon | CC0 |
| `fotos/13-gas-zeiger-1.jpg` | Gas, Zeigerzähler | — | 6+0 | [Gas-Meter-1785.jpg](https://commons.wikimedia.org/wiki/File:Gas-Meter-1785.jpg) | Loadmaster (David R. Tribble) | CC BY-SA 3.0 |
| `fotos/19-gas-zeiger-2.jpg` | Gas, Zeigerzähler | — | 6+0 | [Gas meter 2.jpg](https://commons.wikimedia.org/wiki/File:Gas_meter_2.jpg) | Tim36272 | CC BY-SA 3.0 |
| `fotos/24-sangamo-zeiger.jpg` | Strom, Zeigerzähler | — | 5+1 | [Mechanical electricity meter 1965 (1).jpg](https://commons.wikimedia.org/wiki/File:Mechanical_electricity_meter_1965_(1).jpg) | Mike1024 at English Wikipedia | Public domain |
| `fotos/25-landis-e320.jpg` | Strom, LCD | 2426 | 6+0 | [2024-SmartMeter.jpg](https://commons.wikimedia.org/wiki/File:2024-SmartMeter.jpg) | Achimsh | CC BY-SA 4.0 |
| `fotos/27-meterus.jpg` | Strom, LCD mit Dezimalpunkt | 4.67 | 5+2 | [Intelligenter zaehler- Smart meter.jpg](https://commons.wikimedia.org/wiki/File:Intelligenter_zaehler-_Smart_meter.jpg) | EVB Energy Ltd | CC BY-SA 3.0 |
| `fotos/28-openway.jpg` | Strom, LCD, neuer Zähler | 0 | 5+0 | [Itron OpenWay Electricity Meter with Two-Way Communications.JPG](https://commons.wikimedia.org/wiki/File:Itron_OpenWay_Electricity_Meter_with_Two-Way_Communications.JPG) | Dwight Burdette | CC BY 3.0 |
| `fotos/29-kamstrup.jpg` | Strom, LCD | 14426 | 7+0 | [Kamstrup Electricity meter 382.jpg](https://commons.wikimedia.org/wiki/File:Kamstrup_Electricity_meter_382.jpg) | Gert Skriver | CC BY 3.0 |
| `fotos/32-gruenes-display.jpg` | Strom, LCD, schlechtes Licht | 1936 | 6+0 | [Smart Electrical Meter.jpg](https://commons.wikimedia.org/wiki/File:Smart_Electrical_Meter.jpg) | Aliva Sahoo | CC BY-SA 4.0 |
| `fotos/43-badger-halbe-ziffer.jpg` | Wasser, Rollenzählwerk | — | 6+0 | [Water Meter USA.JPG](https://commons.wikimedia.org/wiki/File:Water_Meter_USA.JPG) | Stilfehler | Public domain |

### Zweite Sammlung (`fotos-lcd/`, nie zum Training benutzt)

Am 23. Oktober 2026 von Wikimedia Commons geholt, auf 960 Pixel Breite verkleinert, sonst unverändert. Die Rahmen und Soll-Texte stehen in `fotos-lcd.json`.

| Datei | Art | Soll | Stellen | Quelle | Urheber | Lizenz |
|---|---|---|---|---|---|---|
| `fotos-lcd/50-aclara-i210.jpg` | Strom, LCD, Aclara I-210+ | 74590 | 5+0 | [Aclara I-210+ single phase smart electricity meter.jpg](https://commons.wikimedia.org/wiki/File:Aclara_I-210%2B_single_phase_smart_electricity_meter.jpg) | 277volts | CC BY-SA 4.0 |
| `fotos-lcd/51-pel-fesco.jpg` | Strom, LCD, Drehstrom | 10 | 6+0 | [Digital Electric meter Erorr.jpg](https://commons.wikimedia.org/wiki/File:Digital_Electric_meter_Erorr.jpg) | KingWriter1245 | CC BY-SA 4.0 |
| `fotos-lcd/52-elster-r.jpg` | Strom, LCD, Elster | 1 | 5+0 | [Elster Type R15 electricity meter.jpeg](https://commons.wikimedia.org/wiki/File:Elster_Type_R15_electricity_meter.jpeg) | Zuzu | CC BY-SA 3.0 |
| `fotos-lcd/53-kaifa-ma105.jpg` | Strom, LCD, Kaifa MA105 | 134141 | 6+0 | [Kaifa MA105H2E AMS-måler.jpg](https://commons.wikimedia.org/wiki/File:Kaifa_MA105H2E_AMS-m%C3%A5ler.jpg) | Fredrik Lindseth | CC BY-SA 4.0 |
| `fotos-lcd/54-focus-axr.jpg` | Strom, LCD, Landis+Gyr Focus AXR | 0 | 5+0 | [Landis+Gyr FocusAXR-SD Hydro-Quebec.JPG](https://commons.wikimedia.org/wiki/File:Landis%2BGyr_FocusAXR-SD_Hydro-Quebec.JPG) | Bouchecl | CC BY-SA 4.0 |
| `fotos-lcd/55-flowiq-2200.jpg` | Wasser, LCD, Kamstrup flowIQ | 880.518 | 6+3 | [Digitaler Wasserzaehler.jpg](https://commons.wikimedia.org/wiki/File:Digitaler_Wasserzaehler.jpg) | HelgeRieder | CC0 |
| `fotos-lcd/56-aclara-leer.jpg` | Strom, LCD ohne Anzeige | — | 6+0 | [Aclara kV2c FITZALL 3-phase smart electricity meter.jpg](https://commons.wikimedia.org/wiki/File:Aclara_kV2c_FITZALL_3-phase_smart_electricity_meter.jpg) | 277volts | CC BY-SA 4.0 |
| `fotos-lcd/57-iskra-test.jpg` | Strom, LCD mit allen Segmenten | — | 6+0 | [Meterkast meter.jpg](https://commons.wikimedia.org/wiki/File:Meterkast_meter.jpg) | BAsta8 | CC BY-SA 4.0 |
| `fotos-lcd/58-iskra-leer.jpg` | Strom, LCD ohne Anzeige, Spiegelung | — | 6+0 | [Vorarlberger Kraftwerke-Energy meter (electro)-11ASD.jpg](https://commons.wikimedia.org/wiki/File:Vorarlberger_Kraftwerke-Energy_meter_(electro)-11ASD.jpg) | Asurnipal | CC BY-SA 4.0 |
