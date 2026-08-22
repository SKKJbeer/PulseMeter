/* Prüft den Klick-Dummy headless — die Wege, die ein Nutzer wirklich geht.
 *
 * **Warum das eine eigene Prüfung braucht.** Der Entwurf ist der produktivste
 * Fehlerfinder dieses Projekts, wurde aber nur geprüft, wenn ich daran dachte.
 * Der Fehler, der ihn ausgelöst hat, zeigt warum: Ein frisch angelegter Zähler
 * ließ sich nicht ablesen — der allererste Schritt eines neuen Nutzers —, und
 * gefunden hat es der Gründer beim Ausprobieren. Jeder Zähler im Entwurf hatte
 * zwei Jahre Historie; den Fall „noch nie abgelesen" gab es in der Erfassung
 * schlicht nicht.
 *
 * Läuft unter Linux und braucht keinen macOS-Läufer. Aufruf:
 *   node scripts/check-prototype.mjs [pfad-oder-url]
 */
import { chromium } from "playwright";

const target = process.argv[2] || "docs/prototype/index.html";
const url = target.startsWith("file:") || target.startsWith("http")
  ? target : "file://" + process.cwd() + "/" + target;

const failures = [];
const note = (ok, text) => {
  console.log((ok ? "  ok   " : "  FEHL ") + text);
  if (!ok) failures.push(text);
};

const browser = await chromium.launch({
  executablePath: process.env.PULSE_CHROMIUM || undefined
});

for (const scheme of ["light", "dark"]) {
  console.log(`\nErscheinungsbild: ${scheme}`);
  const page = await browser.newPage({ viewport: { width: 440, height: 1300 }, colorScheme: scheme });
  const jsErrors = [];
  page.on("pageerror", e => jsErrors.push(e.message));
  page.on("console", m => { if (m.type() === "error") jsErrors.push(m.text()); });
  await page.goto(url);
  await page.waitForTimeout(400);

  // --- Hauptflüsse erreichbar
  for (const [sel, label] of [['[data-pane="history"]', "Verlauf"],
                              ['[data-mode="table"]', "Tabelle"],
                              ['[data-pane="meters"]', "Zähler"],
                              ['[data-pane="home"]', "Übersicht"]]) {
    const l = page.locator(sel).first();
    note(await l.count() > 0, `${label} erreichbar`);
    if (await l.count()) { await l.click(); await page.waitForTimeout(200); }
  }

  // --- Der Weg eines neuen Nutzers: Zähler anlegen, ersten Stand eintragen
  await page.locator('[data-pane="meters"]').first().click();
  await page.waitForTimeout(200);
  await page.locator("#add-meter").click();
  await page.waitForTimeout(200);
  await page.locator("#ed-name").fill("Prüfzähler");
  await page.locator("#ed-save").click();
  await page.waitForTimeout(350);

  const neu = await page.evaluate(() => {
    const m = METERS.find(x => x.name === "Prüfzähler");
    if (!m) return null;
    const r = m.registers[0];
    return { id: m.id, hatStellen: r.int !== undefined && r.frac !== undefined };
  });
  note(!!neu, "Zähler lässt sich anlegen");
  note(!!neu && neu.hatStellen, "Das neue Zählwerk kennt seine Stellen");

  if (neu) {
    await page.locator('[data-pane="home"]').first().click();
    await page.waitForTimeout(250);
    await page.locator(`[data-capture="${neu.id}"]`).first().click();
    await page.waitForTimeout(250);
    for (const k of ["1", "2", "3"]) await page.locator(`[data-key="${k}"]`).first().click();
    await page.waitForTimeout(200);

    const zustand = await page.evaluate(() => ({
      gesperrt: document.getElementById("save").disabled,
      urteil: document.getElementById("verdict").innerText.trim()
    }));
    note(!zustand.gesperrt, "Erster Stand lässt sich sichern");
    note(/[Ee]rste Ablesung/.test(zustand.urteil),
         `Ohne Vorgänger sagt die Prüfung das auch („${zustand.urteil}“)`);

    if (!zustand.gesperrt) {
      await page.locator("#save").click();
      await page.waitForTimeout(350);
      const n = await page.evaluate(() =>
        METERS.find(x => x.name === "Prüfzähler").registers[0].readings.length);
      note(n === 1, "Der erste Stand ist gespeichert");
    }
  }

  // --- Zwei Zählwerke in einem Vorgang
  await page.locator('[data-pane="home"]').first().click();
  await page.waitForTimeout(200);
  const zweiId = await page.evaluate(() =>
    (METERS.find(m => m.registers.length > 1) || {}).id || null);
  if (zweiId) {
    const vorher = await page.evaluate(id =>
      METERS.find(m => m.id === id).registers.map(r => r.readings.length), zweiId);
    await page.locator(`[data-capture="${zweiId}"]`).first().click();
    await page.waitForTimeout(250);
    note((await page.locator("#save").textContent()) === "Weiter",
         "Beim ersten von zwei Zählwerken steht „Weiter“");
    await page.locator("#prefill").click();
    const ersteEingabe = await page.evaluate(() => digits);
    await page.locator("#save").click();
    await page.waitForTimeout(250);
    note((await page.locator("#save").textContent()) === "Sichern",
         "Beim letzten Zählwerk steht „Sichern“");

    // Prinzip 4 — keine Sackgasse: Wer sich beim ersten Zählwerk vertippt hat,
    // muss zurück können, ohne den ganzen Vorgang zu verlieren.
    note((await page.locator("#cap-back").textContent()) === "Zurück",
         "Beim zweiten Zählwerk führt ein Weg zurück");
    note(await page.locator("#cap-cancel").isVisible(),
         "Abbrechen bleibt daneben erreichbar");
    await page.locator("#cap-back").click();
    await page.waitForTimeout(250);
    const zurueck = await page.evaluate(() => ({
      eingabe: digits,
      knopf: document.getElementById("save").textContent,
      schritt: document.getElementById("cap-meta").innerText
    }));
    note(zurueck.knopf === "Weiter" && /1 von 2/.test(zurueck.schritt),
         "Zurück landet wieder beim ersten Zählwerk");
    note(zurueck.eingabe === ersteEingabe,
         `Der eingetippte Wert steht wieder da (${zurueck.eingabe})`);
    await page.locator("#save").click();
    await page.waitForTimeout(250);
    await page.locator("#prefill").click();
    await page.locator("#save").click();
    await page.waitForTimeout(400);
    const nachher = await page.evaluate(id =>
      METERS.find(m => m.id === id).registers.map(r => r.readings.length), zweiId);
    note(nachher.every((n, i) => n === vorher[i] + 1),
         `Beide Zählwerke erfasst (${vorher} → ${nachher})`);
  }

  // --- Der laufende Monat: was voraussichtlich zusammenkommt
  //
  // Der Wunsch dahinter: „ich will sehen, wie viel man wahrscheinlich im
  // laufenden Monat verbrauchen wird." Geprüft wird nicht nur, dass eine Zahl
  // dasteht, sondern dass sie **gekennzeichnet** ist und ihre Grundlage nennt —
  // Produktprinzip 7. Eine Hochrechnung ohne ≈ wäre schlimmer als keine.
  await page.locator('[data-pane="history"]').first().click();
  await page.waitForTimeout(300);
  await page.locator('[data-mode="chart"]').first().click();
  await page.waitForTimeout(300);
  const prognose = await page.evaluate(`(() => {
    const zeile = document.getElementById("chart-forecast");
    const m = METERS.find(x => x.id === histMeter);
    const f = monthForecast(m, TODAY.y, TODAY.m);
    const gemessen = meterConsumption(m, { y: TODAY.y, m: TODAY.m, d: 1 }, TODAY);
    return {
      sichtbar: zeile.style.display !== "none" && zeile.innerText.trim().length > 0,
      text: zeile.innerText.trim(),
      erwartet: f ? f.value : null,
      gemessen: gemessen ? gemessen.value : null
    };
  })()`);
  note(prognose.sichtbar, `Der laufende Monat sagt, was voraussichtlich zusammenkommt`);
  note(/≈/.test(prognose.text), `Die Zahl trägt ein ≈ — sie ist gerechnet, nicht gemessen`);
  note(/von \d+ Tagen/.test(prognose.text),
       `Und sie nennt, auf wie vielen Tagen sie steht („${prognose.text.slice(-32)}")`);
  note(/Vorjahres|Tagesschnitt/.test(prognose.text),
       "Die Grundlage der Hochrechnung steht dabei");
  note(prognose.erwartet !== null && prognose.gemessen !== null
       && prognose.erwartet >= prognose.gemessen,
       `Die Erwartung liegt nicht unter dem Gemessenen `
       + `(${Math.round(prognose.erwartet)} zu ${Math.round(prognose.gemessen)})`);

  // **Die Zahl steht auch im Bild.**
  //
  // „ich will dass man das voraussichtliche des monats in dem balken grafik
  // direkt sehen kann." Ein Satz unter der Karte ist nicht dasselbe wie eine
  // Zahl am Balken — wer aufs Diagramm schaut, schaut nicht nach unten.
  const amBalken = await page.evaluate(`(() => {
    const texte = [...document.querySelectorAll("#chart svg text")]
      .map(t => t.textContent.trim());
    return { alle: texte, mitZeichen: texte.filter(t => t.startsWith("≈")) };
  })()`);
  note(amBalken.mitZeichen.length === 1,
       `Genau eine erwartete Zahl steht am Balken („${amBalken.mitZeichen[0] ?? "—"}")`);
  note(prognose.erwartet !== null && amBalken.mitZeichen.length === 1
       && Math.abs(Number(amBalken.mitZeichen[0].replace(/[^\d,.-]/g, "")
                          .replace(/\./g, "").replace(",", ".")) - prognose.erwartet) < 1.5,
       "Und es ist dieselbe Zahl wie im Satz darunter");

  // In der Jahresansicht hat die Zeile keinen Ort: Dort stehen drei Jahre
  // nebeneinander, und die Hochrechnung steckt schon im Balken von 2026.
  await page.locator('[data-scale="year"]').first().click();
  await page.waitForTimeout(300);
  note(await page.evaluate(`document.getElementById("chart-forecast").style.display === "none"`),
       "In der Jahresansicht steht die Monatszeile nicht");
  await page.locator('[data-scale="month"]').first().click();
  await page.waitForTimeout(250);

  // --- Datum und Uhrzeit: zwei Ablesungen an einem Tag, rückwirkend eintragen
  //
  // Der Wunsch dahinter: morgens und abends ablesen und beides behalten. Geprüft
  // wird deshalb nicht der Eingabeknopf, sondern was danach in der Reihe steht —
  // die Reihenfolge entscheidet über jeden gerechneten Verbrauch.
  await page.locator('[data-pane="home"]').first().click();
  await page.waitForTimeout(200);
  const zeitId = await page.evaluate(() =>
    (METERS.find(m => m.registers.length === 1 && m.registers[0].readings.length > 2) || {}).id || null);
  if (zeitId) {
    // **Einen Tag vor der letzten vorhandenen Ablesung**, nicht einfach
    // „gestern": Läge das Datum nach der letzten, stünde der Eintrag zu Recht
    // hinten, und die Prüfung würde nichts prüfen.
    const stand = await page.evaluate(id => {
      const rs = METERS.find(m => m.id === id).registers[0].readings;
      const letzte = rs[rs.length - 1];
      const tag = new Date(Date.UTC(letzte.y, letzte.m - 1, letzte.d - 1));
      return {
        anzahl: rs.length,
        davor: tag.toISOString().slice(0, 10),
        letzterTag: letzte.y * 10000 + letzte.m * 100 + letzte.d
      };
    }, zeitId);
    const vorher = stand.anzahl;
    await page.locator(`[data-capture="${zeitId}"]`).first().click();
    await page.waitForTimeout(250);
    note(await page.locator("#cap-date").isVisible() && await page.locator("#cap-time").isVisible(),
         "Datum und Uhrzeit stehen unter dem Sichern-Knopf");
    await page.locator("#cap-date").fill(stand.davor);
    await page.locator("#cap-time").fill("07:00");
    await page.locator("#prefill").click();
    await page.locator("#save").click();
    await page.waitForTimeout(400);
    const reihe = await page.evaluate(id => {
      const rs = METERS.find(m => m.id === id).registers[0].readings;
      const tage = rs.map(r => r.y * 10000 + r.m * 100 + r.d);
      return {
        anzahl: rs.length,
        sortiert: tage.every((t, i) => i === 0 || tage[i - 1] <= t),
        mitZeit: rs.filter(r => r.t != null).length,
        letzter: tage[tage.length - 1]
      };
    }, zeitId);
    note(reihe.anzahl === vorher + 1, `Die nachgetragene Ablesung ist gespeichert (${reihe.anzahl})`);
    note(reihe.sortiert, "Die Reihe bleibt nach Tagen geordnet — sonst rechnet jeder Abschnitt danach falsch");
    note(reihe.mitZeit === 1, `Genau die neue Ablesung trägt eine Uhrzeit (${reihe.mitZeit})`);
    note(reihe.letzter === stand.letzterTag,
         "Ein nachgetragener Eintrag hängt nicht hinten an, sondern rückt an seinen Platz");

    // Und die Uhrzeit steht auch da, wo jemand sie sucht. Der Verlauf steht an
    // dieser Stelle in der Tabellenansicht; „Alle Ablesungen" hängt am Diagramm.
    await page.locator('[data-pane="history"]').first().click();
    await page.waitForTimeout(250);
    await page.locator(`#picker [data-pick="${zeitId}"]`).first().click();
    await page.waitForTimeout(250);
    await page.locator('[data-mode="chart"]').first().click();
    await page.waitForTimeout(300);
    await page.locator('[data-open="readings"]').first().click();
    await page.waitForTimeout(300);
    const liste = await page.evaluate(() => document.getElementById("readings").innerText);
    note(/07:00 Uhr/.test(liste), "Die Uhrzeit steht in der Liste der Ablesungen");
    await page.locator("#sheet-readings [data-close]").first().click();
    await page.waitForTimeout(250);
  }

  // --- Export: Ein Zähler mit zwei Zahlen darf keine davon verlieren
  const csv = await page.evaluate(() => {
    const m = METERS.find(x => x.registers.length > 1);
    if (!m) return null;
    histMeter = m.id;
    return { id: m.id, text: buildCsv("readings") };
  });
  if (csv) {
    const zeilen = csv.text.split("\n");
    const namen = new Set(zeilen.slice(1).map(z => z.split(";")[1]).filter(Boolean));
    note(zeilen[0].includes("Bezeichnung"),
         "Der Export benennt, welche Zahl in der Zeile steht");
    note(namen.size >= 2,
         `Beide Zählwerke stehen im Export (${[...namen].join(", ")})`);
    note(!zeilen.slice(1).some(z => z && z.split(";")[1] === ""),
         "Keine Zeile ohne Bezeichnung — ein leeres Feld wäre eine Frage");
    note(!csv.text.includes("Zählwerk"),
         "Das Wort aus der Wortliste steht auch im Export nicht");
  }

  // --- Die Grenze zwischen Kostenlos und Pro
  //
  // Geprüft wird nicht, dass etwas gesperrt ist, sondern dass die Sperre
  // **erklärt** und weiterführt: ein Knopf, der in eine Sackgasse läuft, wäre
  // schlimmer als gar keine Grenze (Produktprinzip 4).
  await page.locator('[data-pane="meters"]').first().click();
  await page.waitForTimeout(200);
  await page.locator('[data-pro="0"]').first().click();
  await page.waitForTimeout(250);

  const grenze = await page.evaluate(() => ({
    hinweis: document.getElementById("limit-note").textContent.trim(),
    zaehler: METERS.length
  }));
  note(grenze.zaehler > 2 && /Kostenlos sind 2 Zähler/.test(grenze.hinweis),
       `Die Grenze steht da, bevor jemand dagegenläuft („${grenze.hinweis}“)`);

  await page.locator("#add-meter").click();
  await page.waitForTimeout(300);
  const kaufseite = await page.evaluate(() => ({
    offen: document.getElementById("sheet-pro").classList.contains("on"),
    text: document.getElementById("pro-body").innerText,
    erste: (document.querySelector("#pro-body .rl") || {}).innerText || ""
  }));
  note(kaufseite.offen, "Die Grenze führt zum Kaufblatt statt ins Leere");
  // Seit 0.40.0 ein Blatt je Funktion statt einer Liste: Wer am dritten Zähler
  // hängt, bekommt den dritten Zähler angeboten — mit Preis, nicht mit Regal.
  note(/Kostenlos sind zwei/.test(kaufseite.text),
       "Das Kaufblatt zeigt die eine Sache, an der es hakte");
  note(/Freischalten · 2,99/.test(kaufseite.text),
       "Und den Preis dazu, bevor jemand tippt");
  note(/Alles freischalten/.test(kaufseite.text) && /9,99/.test(kaufseite.text),
       "Das Bündel steht darunter, nicht als Regal davor");
  note(/Der Export\s+bleibt kostenlos/.test(kaufseite.text.replace(/\s+/g, " "))
       || /Export bleibt kostenlos/.test(kaufseite.text.replace(/\s+/g, " ")),
       "Die Kaufseite sagt, was kostenlos bleibt");

  // Nichts versprechen, was es noch nicht gibt: Foto-Belege und
  // Siri-Kurzbefehle sind aus 1.0 gestrichen (docs/07-v1-plan.md).
  const zuviel = ["Foto", "Beleg", "Siri", "Kurzbefehl"].filter(w => kaufseite.text.includes(w));
  note(zuviel.length === 0,
       `Die Kaufseite verspricht nichts aus 1.1${zuviel.length ? ": " + zuviel.join(", ") : ""}`);

  // Der Bericht ist nie gesperrt — ungekauft trägt er ein Wasserzeichen.
  // Diese Prüfung hält fest, dass er sich öffnen lässt und dass der Schriftzug
  // dabei wirklich auf dem Papier liegt, nicht nur im Kopf des Entwicklers.
  // Gezielt das offene Blatt schließen, nicht irgendeines: `[data-close]`
  // trifft auch die Knöpfe der verdeckten Blätter, und ein Klick darauf landet
  // im Nichts.
  await page.locator("#sheet-pro [data-close]").first().click();
  await page.waitForTimeout(250);
  await page.locator('[data-pane="history"]').first().click();
  await page.waitForTimeout(250);
  // Der Weg zum Bericht führt über „Herunterladen". Ein Knopf, drei Einträge —
  // und der Bericht ist einer davon, weil er genauso ein Download ist.
  await page.locator('[data-open="download"]').first().click();
  await page.waitForTimeout(300);
  const auswahl = await page.evaluate(() =>
    [...document.querySelectorAll("#sheet-download .rowbtn .rl")]
      .map(x => x.childNodes[0].textContent.trim()));
  note(auswahl.length === 3 && auswahl.every(x => /CSV|PDF/.test(x)),
       `Hinter „Herunterladen" stehen drei Dateien: ${auswahl.join(", ")}`);
  await page.locator('#sheet-download [data-open="report"]').first().click();
  await page.waitForTimeout(250);
  await page.locator("#makereport").click();
  await page.waitForTimeout(350);
  const bericht = await page.evaluate(() => ({
    offen: document.getElementById("sheet-report").classList.contains("on"),
    wasserzeichen: document.getElementById("doc").innerHTML.includes("PulseMeter · Vorschau"),
    inhalt: document.getElementById("doc").innerText.length
  }));
  note(bericht.offen, "Der Bericht lässt sich auch ungekauft öffnen");
  note(bericht.wasserzeichen, "Und trägt dann ein Wasserzeichen");
  note(bericht.inhalt > 200,
       `Der Inhalt bleibt lesbar (${bericht.inhalt} Zeichen) — sonst wäre es eine Sperre mit Umweg`);
  await page.locator("#sheet-report [data-close]").first().click();
  await page.waitForTimeout(300);
  await page.locator('[data-pane="meters"]').first().click();
  await page.waitForTimeout(200);
  await page.locator("#add-meter").click();
  await page.waitForTimeout(300);

  // Und der Kauf hebt sie auf.
  await page.locator("#pro-buy").click();
  await page.waitForTimeout(350);
  await page.locator("#add-meter").click();
  await page.waitForTimeout(300);
  note(await page.locator("#sheet-editor").evaluate(el => el.classList.contains("on")),
       "Nach dem Kauf öffnet derselbe Knopf wieder das Formular");
  await page.locator("#sheet-editor [data-close]").first().click();
  await page.waitForTimeout(250);

  // --- Die Hochrechnung und ihre Grundlage
  //
  // **Warum das hier geprüft wird und nicht nur in PulseCore.** Regel 2 sagt,
  // dass Entwurf und Rechenkern dieselbe Rechnung machen. Die Referenzprofile
  // stehen an zwei Stellen — hier und in `SeasonalProfile.swift` —, und zwei
  // Fassungen laufen auseinander. Geprüft werden deshalb die Zahlen, die aus
  // den veröffentlichten Quellen folgen und die ein Tippfehler zerstören
  // würde.
  const profile = await page.evaluate(() => ({
    summen: [PROFILES.heating, PROFILES.household, PROFILES.solar]
      .map(p => p.reduce((a, b) => a + b, 0)),
    heizJanuarZuJuli: PROFILES.heating[0] / PROFILES.heating[6],
    stromJanuarZuJuli: PROFILES.household[0] / PROFILES.household[6],
    solarJuniZuDezember: PROFILES.solar[5] / PROFILES.solar[11],
    winterquartal: profileShare(PROFILES.heating, { y: 2026, m: 1, d: 1 }, { y: 2026, m: 4, d: 1 })
  }));
  note(profile.summen.every(s => Math.abs(s - 1) < 1e-9),
       "Jedes Referenzprofil summiert sich auf ein Jahr");
  note(profile.heizJanuarZuJuli > 5 && profile.heizJanuarZuJuli < 7,
       `Heizen: Januar zu Juli wie ${profile.heizJanuarZuJuli.toFixed(1)} zu 1`);
  note(profile.stromJanuarZuJuli > 1.2 && profile.stromJanuarZuJuli < 1.6,
       `Haushaltsstrom: Januar zu Juli wie ${profile.stromJanuarZuJuli.toFixed(2)} zu 1`);
  note(profile.solarJuniZuDezember > 6,
       `Photovoltaik läuft gegenläufig (Juni zu Dezember ${profile.solarJuniZuDezember.toFixed(1)} zu 1)`);
  note(profile.winterquartal > 0.40 && profile.winterquartal < 0.46,
       `Januar bis März tragen ${(profile.winterquartal * 100).toFixed(1)} % des Heizjahres`);

  // Und die Grundlage steht auf dem Schirm, nicht nur im Code.
  await page.locator('[data-pane="home"]').first().click();
  await page.waitForTimeout(200);
  await page.locator('[data-explain]').first().click();
  await page.waitForTimeout(300);
  const erklaerung = await page.evaluate(() =>
    document.getElementById("ex-body").innerText);
  note(/Hochrechnung aufs Jahr/.test(erklaerung), "Die Erklärung nennt die Hochrechnung");
  note(/nach dem Verlauf|typischen Jahresverlauf|Tagesschnitt/.test(erklaerung),
       "Und sie sagt, worauf die Zahl beruht");
  await page.locator("#sheet-explain [data-close]").first().click();
  await page.waitForTimeout(200);

  // --- Keine Taste, die nichts tut
  //
  // Auf dem Ziffernblock stand ein Kamerasymbol als Platzhalter für
  // Belegfotos. Die sind für 1.0 gestrichen; ein angekündigter Knopf ohne
  // Wirkung ist eine Sackgasse, und für jemanden, der die Tasten nur hört,
  // eine besonders ärgerliche.
  await page.locator('[data-pane="home"]').first().click();
  await page.waitForTimeout(200);
  await page.locator("[data-capture]").first().click();
  await page.waitForTimeout(250);
  const tasten = await page.evaluate(() => ({
    tot: document.querySelectorAll('#keys [data-key="photo"]').length,
    ziffern: document.querySelectorAll('#keys [data-key]').length
  }));
  note(tasten.tot === 0, "Keine Taste auf dem Ziffernblock, die nichts tut");

  // --- Die Zahl läuft von rechts ein
  //
  // Seit 0.46.0 steht dort eine Zahl statt sechs Walzen. Geprüft wird, was
  // beim Tippen wirklich dasteht: Tausenderpunkte an der richtigen Stelle,
  // zwei rote Nachkommastellen, und die noch nicht getippten Stellen blass
  // statt gar nicht. Eine Zahl, die um eine Stelle verrutscht, ist der
  // teuerste Fehler, den diese Ansicht machen kann.
  for (const z of "4131274") await page.locator(`#keys [data-key="${z}"]`).first().click();
  await page.waitForTimeout(200);
  const stand = await page.evaluate(() => document.querySelector("#counter .num").textContent.trim());
  // Die führende Null steht blass **da** und fehlt nicht: Man soll sehen, wie
  // viele Stellen das Gerät hat. Sie zählt deshalb im Text mit.
  note(stand === "041.312,74", `Der Stand liest sich als ${stand}`);
  const blass = await page.evaluate(() =>
    document.querySelectorAll("#counter .num .leer").length);
  note(blass === 1, `Eine noch offene Stelle steht blass da (${blass})`);
  const rot = await page.evaluate(() =>
    document.querySelector("#counter .num .dec")?.textContent.trim());
  note(rot === ",74", `Die Nachkommastellen stehen rot: ${rot}`);

  // Löschen bringt die blassen Stellen zurück — und den blinkenden Strich.
  for (let i = 0; i < 7; i++) await page.locator('#keys [data-key="back"]').first().click();
  await page.waitForTimeout(200);
  const leer = await page.evaluate(() => ({
    blass: document.querySelectorAll("#counter .num .leer").length,
    strich: document.querySelectorAll("#counter .num .caret").length
  }));
  // Acht Stellen und der Tausenderpunkt, der ohne Zahl ebenfalls blass bleibt.
  note(leer.blass === 9, `Leer steht alles blass (${leer.blass} Zeichen)`);
  note(leer.strich === 1, "Der Strich zeigt, wo die nächste Ziffer landet");
  for (const z of "4131274") await page.locator(`#keys [data-key="${z}"]`).first().click();
  await page.waitForTimeout(150);
  note(tasten.ziffern === 11,
       `Zehn Ziffern und das Löschen stehen weiter (${tasten.ziffern} Tasten)`);
  await page.locator("#cap-back").click();
  await page.waitForTimeout(250);

  // --- Darstellung
  const overflow = await page.evaluate(() =>
    document.documentElement.scrollWidth > document.documentElement.clientWidth);
  note(!overflow, "Kein horizontaler Überlauf");
  note(jsErrors.length === 0, `Keine JS-Fehler${jsErrors.length ? ": " + jsErrors.join("; ") : ""}`);

  await page.close();
}

await browser.close();
console.log(failures.length
  ? `\n${failures.length} Prüfung(en) gefallen.`
  : "\nAlle Prüfungen des Entwurfs sind durchgelaufen.");
process.exit(failures.length ? 1 : 0);
