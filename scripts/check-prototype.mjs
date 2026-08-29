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

/// Eine ganze Zahl so geschrieben, wie der Entwurf sie schreibt: mit Punkt als
/// Tausendertrenner. Nur zum Vergleichen einer angezeigten Zahl mit einer
/// gerechneten — nicht zum Formatieren.
const nfLike = value => Math.round(value).toLocaleString("de-DE");

const MONATSNAMEN = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli",
                     "August", "September", "Oktober", "November", "Dezember"];

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

  // --- Eine Zählerzeile geht überall auf, wo sie wie eine Zeile aussieht
  //
  // Nicht in die Mitte geklickt, sondern kurz vor den rechten Rand: In der App
  // war genau diese Fläche tot, weil der Knopf dort nichts zeichnete, und ein
  // Nutzer hat es beim dritten Tippversuch gemerkt (0.72.2). Der Entwurf hat es
  // richtig gemacht — ein echter Knopf über der ganzen Zeile —, und diese
  // Prüfung hält ihn dabei. Regel 2 gilt in beide Richtungen.
  await page.locator('[data-pane="meters"]').first().click();
  await page.waitForTimeout(200);
  const zeile = page.locator("[data-meter]").first();
  const kasten = await zeile.boundingBox();
  note(!!kasten && kasten.height >= 44,
       `Zählerzeile ist mindestens 44 Punkt hoch (${kasten ? Math.round(kasten.height) : 0})`);
  if (kasten) {
    await page.mouse.click(kasten.x + kasten.width * 0.85, kasten.y + kasten.height / 2);
    await page.waitForTimeout(300);
  }
  note(await page.locator("#ed-name").isVisible().catch(() => false),
       "Ein Klick neben den Namen öffnet den Zähler");
  // Über die eigene Funktion des Entwurfs schließen, nicht über einen Knopf:
  // `.first()` einer Sammelauswahl traf schon den Schließen-Knopf eines
  // anderen Blatts, und das offene Blatt fing danach jeden Klick ab.
  await page.evaluate(() => closeSheets());
  await page.waitForTimeout(250);

  // --- Eine erfasste Ablesung ändern und löschen
  //
  // Vom Nutzer verlangt: „ich benötige noch eine Option dass man historische
  // Zählerstände ändern und löschen kann." Wer sich vertippt, verschiebt beide
  // angrenzenden Zeiträume — und sah den falschen Wert bis 0.75.0 für immer.
  await page.locator('[data-pane="history"]').first().click();
  await page.waitForTimeout(250);
  // Zurück ins Diagramm: Ein früherer Abschnitt hat auf „Alle Zahlen"
  // umgeschaltet, und dort gibt es die Zeile „Alle Ablesungen" nicht.
  await page.locator('[data-mode="chart"]').first().click();
  await page.waitForTimeout(250);
  await page.locator('[data-open="readings"]').first().click();
  await page.waitForTimeout(300);
  const bestand = await page.evaluate(() => {
    const reg = METERS.find(m => m.id === histMeter).registers[0];
    return { anzahl: reg.readings.length, idx: reg.readings.length - 2 };
  });
  await page.locator(`[data-reading="${bestand.idx}"]`).click();
  await page.waitForTimeout(300);
  const imEditor = await page.evaluate(() => ({
    titel: document.getElementById("cap-title").textContent,
    ziffern: digits,
    loeschbar: !document.getElementById("cap-delete").hidden
  }));
  note(imEditor.titel === "Ablesung ändern" && imEditor.ziffern.length > 0,
       `Eine Zeile öffnet die Ablesung mit ihrem Wert („${imEditor.titel}“)`);
  note(imEditor.loeschbar, "Und bietet an, sie zu löschen");

  // Eine Ziffer ändern und sichern: Der Bestand wird nicht länger, und die
  // Reihe bleibt sortiert — sonst rechnete jeder Abschnitt danach falsch.
  await page.locator('[data-key="back"]').click();
  await page.locator('[data-key="9"]').click();
  await page.waitForTimeout(120);
  await page.locator("#save").click();
  await page.waitForTimeout(350);
  const nachAendern = await page.evaluate(() => {
    const reg = METERS.find(m => m.id === histMeter).registers[0];
    const serial = r => r.y * 10000 + r.m * 100 + r.d;
    return {
      anzahl: reg.readings.length,
      sortiert: reg.readings.every((r, i, a) => i === 0 || serial(a[i - 1]) <= serial(r))
    };
  });
  note(nachAendern.anzahl === bestand.anzahl,
       "Ändern legt keine zweite Ablesung an");
  note(nachAendern.sortiert, "Und die Reihe bleibt nach dem Tag geordnet");

  page.once("dialog", d => d.accept());
  await page.locator('[data-open="readings"]').first().click();
  await page.waitForTimeout(300);
  await page.locator(`[data-reading="${bestand.idx}"]`).click();
  await page.waitForTimeout(300);
  await page.locator("#cap-delete").click();
  await page.waitForTimeout(350);
  const nachLoeschen = await page.evaluate(() =>
    METERS.find(m => m.id === histMeter).registers[0].readings.length);
  note(nachLoeschen === bestand.anzahl - 1,
       `Löschen nimmt genau eine Ablesung weg (${bestand.anzahl} → ${nachLoeschen})`);

  // --- Eine Änderung erreicht auch die Ansicht, in der sie nicht passiert ist
  //
  // Vom Gerät verlangt: „stelle sicher dass die Zahlen und Grafiken sich auch
  // immer aktualisieren wenn neue Zähler eingaben kamen. egal ob einer aus der
  // historie gelöscht oder geändert wurde oder ein ganz neuer zählerstand hinzu
  // kommt."
  //
  // Der Entwurf hat das von jeher getan — er zeichnet nach jeder Änderung alles
  // neu. Die App tat es bis 0.78.0 nicht: Jeder Schirm lud nur für sich, und
  // eine im Verlauf gelöschte Ablesung erreichte die Übersichtskarte nie. Die
  // Prüfung steht trotzdem hier, und zwar deswegen: Was keine Prüfung festhält,
  // läuft irgendwann auseinander, und dann ist der Entwurf keine Vorlage mehr
  // (Regel 2).
  const ziel = await page.evaluate(() => {
    const m = activeMeters().find(x => x.registers.length === 1
                                    && x.registers[0].readings.length > 2);
    if (!m) return null;
    const rs = m.registers[0].readings;
    return { id: m.id, frac: m.frac, letzter: rs[rs.length - 1].value,
             anzahl: rs.length };
  });
  if (!ziel) {
    note(false, "Kein einfacher Zähler für die Aktualisierungsprüfung gefunden");
  } else {
    // Erst den Verlauf auf diesen Zähler stellen — über die Karte, wie ein
    // Nutzer es täte. Danach steht die Kopfzahl für denselben Zähler wie die
    // Karte, und beide müssen sich gemeinsam bewegen.
    await page.locator('[data-pane="home"]').first().click();
    await page.waitForTimeout(200);
    await page.locator(`[data-history="${ziel.id}"]`).click();
    await page.waitForTimeout(350);
    const vorher = await page.evaluate(id => ({
      kopf: document.getElementById("chart-total").textContent.trim(),
      karte: (() => {
        const el = document.querySelector(`[data-history="${id}"] .value`);
        return el ? el.textContent.trim() : "";
      })()
    }), ziel.id);

    // Ein neuer Stand, deutlich über dem letzten — auf der Übersicht
    // eingetragen, also nicht im Verlauf.
    await page.locator('[data-pane="home"]').first().click();
    await page.waitForTimeout(200);
    await page.locator(`[data-capture="${ziel.id}"]`).click();
    await page.waitForTimeout(300);
    const ziffern = String(Math.round((ziel.letzter + 250) * 10 ** ziel.frac));
    for (const z of ziffern) await page.locator(`#keys [data-key="${z}"]`).first().click();
    await page.waitForTimeout(150);
    await page.locator("#save").click();
    await page.waitForTimeout(400);

    const nachher = await page.evaluate(id => ({
      anzahl: METERS.find(m => m.id === id).registers[0].readings.length,
      karte: (() => {
        const el = document.querySelector(`[data-history="${id}"] .value`);
        return el ? el.textContent.trim() : "";
      })()
    }), ziel.id);
    note(nachher.anzahl === ziel.anzahl + 1,
         `Der neue Stand ist erfasst (${ziel.anzahl} → ${nachher.anzahl})`);
    note(nachher.karte !== vorher.karte && nachher.karte !== "",
         `Die Übersichtskarte zeigt ihn sofort (${vorher.karte} → ${nachher.karte})`);

    await page.locator('[data-pane="history"]').first().click();
    await page.waitForTimeout(350);
    const kopfNachher = await page.evaluate(() =>
      document.getElementById("chart-total").textContent.trim());
    note(kopfNachher !== vorher.kopf && kopfNachher !== "",
         `Und der Verlauf ebenso, ohne dass dort etwas angetippt wurde (${vorher.kopf} → ${kopfNachher})`);

    // Und rückwärts: Der Stand wird im Verlauf gelöscht, und die Karte auf der
    // Übersicht muss zurückgehen. Das ist der Weg, der in der App gefehlt hat.
    page.once("dialog", d => d.accept());
    await page.locator('[data-mode="chart"]').first().click();
    await page.waitForTimeout(200);
    await page.locator('[data-open="readings"]').first().click();
    await page.waitForTimeout(300);
    await page.locator(`[data-reading="${nachher.anzahl - 1}"]`).click();
    await page.waitForTimeout(300);
    await page.locator("#cap-delete").click();
    await page.waitForTimeout(400);
    await page.locator('[data-pane="home"]').first().click();
    await page.waitForTimeout(300);
    const zurueck = await page.evaluate(id => ({
      anzahl: METERS.find(m => m.id === id).registers[0].readings.length,
      karte: document.querySelector(`[data-history="${id}"] .value`)?.textContent.trim() ?? ""
    }), ziel.id);
    note(zurueck.anzahl === ziel.anzahl,
         "Der gelöschte Stand ist wieder fort");
    note(zurueck.karte === vorher.karte,
         `Und die Übersichtskarte steht wieder auf ${vorher.karte} (${zurueck.karte})`);
  }

  // --- Unter dem Jahr steht, woher es kommt
  //
  // Vom Gerät verlangt: „die Funktion bei Jahren unten ist nicht verständlich.
  // ich habe ja alle Informationen oben die mich auf Jahresbasis eigentlich
  // interessieren." An die Stelle des Jahresvergleichs treten die zwölf Monate.
  //
  // **Diese Prüfung schließt die Lücke, durch die 0.80.0 gefallen ist.** Bis
  // dahin blendete der Entwurf den Block im Jahresmaßstab aus — es gab dort
  // nichts zu prüfen, und deshalb konnte in der App fünf Versionen lang
  // „Jahresvergleich" über einem halben Jahr stehen.
  await page.locator('[data-pane="history"]').first().click();
  await page.waitForTimeout(200);
  await page.locator('[data-mode="chart"]').first().click();
  await page.waitForTimeout(200);
  await page.locator('[data-scale="year"]').first().click();
  await page.waitForTimeout(400);

  const jahresmonate = await page.evaluate(() => {
    const m = METERS.find(x => x.id === histMeter);
    const monate = [];
    for (let i = 1; i <= 12; i++) {
      const c = meterMonthConsumption(m, TODAY.y, i);
      monate.push(c && c.value !== null ? c.value : null);
    }
    const gemessen = monate.filter(v => v !== null);
    const sortiert = gemessen.slice().sort((a, b) => b - a).slice(0, 3);
    return {
      label: document.getElementById("cmp-label").textContent.trim(),
      sichtbar: document.getElementById("compare-block").style.display !== "none",
      treiber: document.getElementById("cmp-treiber")?.textContent.replace(/\s+/g, " ").trim() ?? "",
      balken: document.querySelectorAll("#compare svg rect").length,
      summe: gemessen.reduce((a, b) => a + b, 0),
      anteil: Math.round(sortiert.reduce((a, b) => a + b, 0) / gemessen.reduce((a, b) => a + b, 0) * 100),
      kopf: document.getElementById("chart-total").textContent.trim(),
      jahr: TODAY.y
    };
  });

  note(jahresmonate.sichtbar && jahresmonate.label === `Woher ${jahresmonate.jahr} kommt`,
       `Unter dem Jahr steht, woher es kommt („${jahresmonate.label}")`);
  note(jahresmonate.balken >= 12,
       `Zwölf Monate stehen als Balken da (${jahresmonate.balken} Flächen mit Vorjahr)`);

  // **Die Summe der Monate ist die Zahl über dem Diagramm.** Beide beschreiben
  // dasselbe Jahr — weichen sie ab, beschreibt eine von beiden etwas anderes,
  // und genau das ist die wiederkehrende Fehlerklasse dieses Projekts.
  // **Als Zahl vergleichen, nicht als Zeichenkette.** Der erste Anlauf verglich
  // Text und meldete „86 gegen ≈ 86,0 m³" als Fehler: Beim Wegwerfen der
  // Nicht-Ziffern wird aus „86,0" die 860. Die Zahlen stimmten, der Vergleich
  // nicht — und eine Prüfung, die auf Formatierung anschlägt, wird weggeklickt.
  const kopfZahl = parseFloat(jahresmonate.kopf
    .replace(/[^0-9,.]/g, "").replace(/\./g, "").replace(",", "."));
  note(Math.abs(kopfZahl - jahresmonate.summe) < 0.6,
       `Die Monate summieren sich auf die Kopfzahl (${jahresmonate.summe.toFixed(1)} gegen ${jahresmonate.kopf})`);

  note(jahresmonate.treiber.includes(`${jahresmonate.anteil} %`),
       `Der Satz nennt den gerechneten Anteil (${jahresmonate.anteil} %): „${jahresmonate.treiber}"`);

  // Ein angebrochenes Jahr darf nicht „des Jahres" sagen — es sind Prozent von
  // dem, was bisher gemessen ist.
  note(jahresmonate.treiber.includes("vom bisher Gemessenen"),
       "Und er nennt den Bezug, weil das Jahr noch läuft");

  // Der alte Jahresvergleich ist fort.
  note(!jahresmonate.label.includes("Jahre davor"),
       "Der Jahresvergleich steht dort nicht mehr");

  await page.locator('[data-scale="month"]').first().click();
  await page.waitForTimeout(300);

  // --- Die große Zahl über dem Diagramm folgt dem angetippten Monat
  //
  // Vom Gerät gemeldet: Wer einen Balken antippt, will oben sehen, was in dem
  // Monat zusammenkam. Vorher blieb dort die Jahressumme stehen.
  await page.locator('[data-pane="history"]').first().click();
  await page.waitForTimeout(250);
  const kopfOhne = await page.evaluate(() => {
    selMonth = null; renderChart();
    return { zahl: document.getElementById("chart-total").textContent,
             marke: document.getElementById("chart-label").textContent };
  });
  note(/1\. Januar/.test(kopfOhne.marke),
       `Ohne Auswahl steht die Summe des Jahres oben („${kopfOhne.marke}“)`);

  const kopfMaerz = await page.evaluate(() => {
    selMonth = 2; renderChart();
    return { zahl: document.getElementById("chart-total").textContent,
             marke: document.getElementById("chart-label").textContent };
  });
  note(/^März 2026/.test(kopfMaerz.marke),
       `Ein angetippter Monat steht oben („${kopfMaerz.marke}“)`);
  note(kopfMaerz.zahl !== kopfOhne.zahl && /\d/.test(kopfMaerz.zahl),
       `Und seine Zahl steht daneben („${kopfMaerz.zahl}“)`);

  // Der laufende Monat ist angebrochen — dann gehört dazu, aus wie vielen
  // Tagen die Zahl stammt. Ohne das verspricht „August" einen ganzen Monat.
  const kopfLaufend = await page.evaluate(() => {
    selMonth = TODAY.m - 1; renderChart();
    return { zahl: document.getElementById("chart-total").textContent,
             marke: document.getElementById("chart-label").textContent };
  });
  note(/ · aus \d+ von \d+ Tagen$/.test(kopfLaufend.marke),
       `Der angebrochene Monat sagt seine Tage („${kopfLaufend.marke}“)`);

  const kopfLeer = await page.evaluate(() => {
    selMonth = 10; renderChart();
    return { zahl: document.getElementById("chart-total").textContent,
             marke: document.getElementById("chart-label").textContent };
  });
  note(kopfLeer.zahl === "—" && /keine Ablesung$/.test(kopfLeer.marke),
       `Ein Monat ohne Ablesung zeigt keine Null („${kopfLeer.zahl}“)`);

  await page.evaluate(() => { selMonth = null; renderChart(); });
  await page.waitForTimeout(150);

  // --- Die Jahresansicht zeigt das laufende Jahr, keine Summe über alle Jahre
  //
  // Vom Gerät gemeldet: „auf Jahresbasis macht es keinen Sinn über alle Jahre
  // die Summe. damit fängt ja keiner was an." Verbrauch vergleicht man Jahr
  // gegen Jahr — dafür stehen die Balken nebeneinander.
  await page.locator('[data-scale="year"]').first().click();
  await page.waitForTimeout(300);
  const jahr = await page.evaluate(() => ({
    zahl: document.getElementById("chart-total").textContent,
    marke: document.getElementById("chart-label").textContent,
    gemessen: yearToDate(METERS.find(m => m.id === histMeter).registers[0]).value
  }));
  note(/^2026/.test(jahr.marke) && !/zusammen|bis/.test(jahr.marke),
       `Die Jahresansicht nennt das laufende Jahr („${jahr.marke}“)`);
  note(/ · aus \d+ von \d+ Tagen$/.test(jahr.marke),
       "Und sagt, aus wie vielen Tagen die Zahl stammt");
  note(jahr.zahl.includes(nfLike(jahr.gemessen)),
       `Die Zahl ist das Gemessene, nicht die Erwartung („${jahr.zahl}“)`);
  await page.locator('[data-scale="month"]').first().click();
  await page.waitForTimeout(250);

  // --- Von der Übersichtskarte in den Verlauf desselben Zählers
  //
  // Vom Gerät gemeldet: Auf der Übersicht passierte beim Antippen einer Karte
  // nichts, außer man traf „Stand eintragen". Geprüft wird die Zahl selbst,
  // nicht der Winkel daneben — sie ist das, was jemand ansieht, wenn er mehr
  // wissen will (Produktprinzip 4).
  await page.locator('[data-pane="home"]').first().click();
  await page.waitForTimeout(250);
  const zweiter = await page.evaluate(() => activeMeters()[1]?.id ?? null);
  if (zweiter) {
    await page.locator(`[data-history="${zweiter}"] .value`).first().click();
    await page.waitForTimeout(350);
    const angekommen = await page.evaluate(() => ({
      pane: document.getElementById("pane-history")?.classList.contains("on"),
      meter: histMeter,
      monat: selMonth
    }));
    note(angekommen.pane === true, "Ein Klick auf die Zahl führt in den Verlauf");
    note(angekommen.meter === zweiter,
         "Und zwar zum Zähler dieser Karte, nicht zum ersten der Liste");
    note(angekommen.monat === null,
         "Ohne einen Monat, der noch vom vorigen Zähler stammt");
    await page.locator('[data-pane="home"]').first().click();
    await page.waitForTimeout(200);
  }

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
    const leiste = document.getElementById("chart-forecast");
    const m = METERS.find(x => x.id === histMeter);
    const f = monthForecast(m, TODAY.y, TODAY.m);
    const gemessen = meterConsumption(m, { y: TODAY.y, m: TODAY.m, d: 1 }, TODAY);
    const voll = leiste.querySelector(".fc-voll");
    const spur = leiste.querySelector(".fc-spur");
    return {
      sichtbar: leiste.style.display !== "none" && leiste.innerText.trim().length > 0,
      text: leiste.innerText.trim(),
      links: (leiste.querySelector(".fc-ist") || {}).textContent || "",
      rechts: (leiste.querySelector(".fc-soll") || {}).textContent || "",
      erwartet: f ? f.value : null,
      gemessen: gemessen ? gemessen.value : null,
      anteil: voll && spur
        ? voll.getBoundingClientRect().width / spur.getBoundingClientRect().width : null
    };
  })()`);
  note(prognose.sichtbar, `Der laufende Monat sagt, was voraussichtlich zusammenkommt`);
  note(/gemessen/.test(prognose.links) && /erwartet/.test(prognose.rechts),
       `Beide Zahlen sind benannt („${prognose.links.trim()}" / „${prognose.rechts.trim()}")`);
  note(/≈/.test(prognose.rechts),
       `Die erwartete Zahl trägt ein ≈ — sie ist gerechnet, nicht gemessen`);
  note(/von \d+ Tagen/.test(prognose.text),
       `Und sie nennt, auf wie vielen Tagen sie steht`);
  note(/Vorjahres|Tagesschnitt/.test(prognose.text),
       "Die Grundlage der Hochrechnung steht dabei");
  note(prognose.erwartet !== null && prognose.gemessen !== null
       && prognose.erwartet >= prognose.gemessen,
       `Die Erwartung liegt nicht unter dem Gemessenen `
       + `(${Math.round(prognose.erwartet)} zu ${Math.round(prognose.gemessen)})`);

  // **Die Leiste zeigt dasselbe Verhältnis, das die Zahlen nennen.**
  //
  // Eine Leiste, die halb voll aussieht, während daneben ein Zehntel steht,
  // wäre schlimmer als gar keine — man glaubt dem Bild, nicht der Zahl.
  const sollAnteil = prognose.gemessen / prognose.erwartet;
  note(prognose.anteil !== null && Math.abs(prognose.anteil - sollAnteil) < 0.03,
       `Der volle Teil der Leiste passt zum Verhältnis der Zahlen `
       + `(${(prognose.anteil * 100).toFixed(0)} % zu ${(sollAnteil * 100).toFixed(0)} %)`);

  // **Im Diagramm selbst steht keine Ziffer.** Drei Anläufe, die Zahl an den
  // Balken zu hängen, sind an der Breite gescheitert: Ein Monatsbalken ist elf
  // Punkte breit, die Zahl dreißig. Sie hat dort nichts verloren.
  const imBild = await page.evaluate(`(() => {
    return [...document.querySelectorAll("#chart svg text")]
      .map(t => t.textContent.trim())
      .filter(t => /[0-9≈]/.test(t));
  })()`);
  note(imBild.length === 0,
       `Keine Zahl schwebt im Diagramm${imBild.length ? ` (gefunden: ${imBild.join(", ")})` : ""}`);

  // **Voll heißt gemessen, schraffiert heißt nicht gemessen.**
  //
  // Zwei Anläufe waren falsch, und der zweite ist der lehrreiche: blass im Ton
  // des Zählers las sich als „dasselbe, nur schwächer" — grau war schlimmer,
  // denn Grau heißt in diesem Bild schon „Vorjahr", und die Hochrechnung stand
  // ununterscheidbar neben den Vorjahresbalken.
  const toene = await page.evaluate(`(() => {
    const rects = [...document.querySelectorAll("#chart svg rect")]
      .map(r => ({ fill: r.getAttribute("fill"), op: r.getAttribute("opacity") }))
      .filter(r => r.fill && r.fill !== "transparent");
    return {
      schraffiert: rects.filter(r => /#hatch/.test(r.fill)).length,
      grau: rects.filter(r => /--ink-3/.test(r.fill)).length,
      farbig: rects.filter(r => /--(amber|green|blue|orange|red|teal)/.test(r.fill)).length,
      vorjahr: rects.filter(r => /--hairline-2/.test(r.fill)).length
    };
  })()`);
  note(toene.schraffiert === 1,
       `Die Erwartung ist schraffiert, nicht eingefärbt (${toene.schraffiert} Fläche)`);
  note(toene.grau === 0,
       `Und sie ist nicht grau — grau heißt hier Vorjahr (${toene.vorjahr} solche Balken)`);
  note(toene.farbig > 0, `Das Gemessene behält die Farbe des Zählers (${toene.farbig} Balken)`);

  const legende = await page.evaluate(`document.getElementById("lg-hatch").textContent`);
  note(/erwartet|geschätzt/.test(legende), `Die Legende benennt die Schraffur („${legende}")`);

  // --- Acht Monate gegen zwei Tage sind kein Prozentwert
  //
  // Auf dem Gerät des Gründers stand „≈ +8.657 % gegenüber Vorjahr": 1.532 kWh
  // aus acht Monaten 2026 gegen ≈ 18 kWh aus zwei Tagen 2025 — seiner ersten
  // Ablesung überhaupt. Beide Zahlen stimmen; die Zahl dazwischen ist die
  // wiederkehrende Fehlerklasse dieses Projekts.
  //
  // Der Fall steckt nicht in den Beispieldaten, also wird er hier gebaut: ein
  // Zähler, dessen Vorjahr nur zwei Tage des Ausschnitts abdeckt.
  const knapp = await page.evaluate(`(() => {
    const m = METERS.find(x => x.id === histMeter);
    const reg = m.registers[0];
    const sicherung = reg.readings.slice();
    // Zwei Ablesungen im Juli 2025, dann ein Jahr Pause, dann laufend 2026.
    const neu = [
      { y: 2025, m: 7, d: 20, value: 1000, origin: "manual" },
      { y: 2025, m: 7, d: 22, value: 1018, origin: "manual" }
    ];
    let stand = 1018;
    for (let mo = 1; mo <= 8; mo++) {
      stand += 190;
      neu.push({ y: 2026, m: mo, d: 1, value: stand, origin: "manual" });
    }
    reg.readings = neu;
    return { sicherung: sicherung.length };
  })()`);
  note(knapp.sicherung > 0, "Beispieldaten für den Grenzfall vorübergehend ersetzt");

  await page.locator('[data-scale="month"]').first().click();
  await page.waitForTimeout(300);
  await page.locator('[data-month="6"]').first().click();   // Juli
  await page.waitForTimeout(400);

  const grenzfall = await page.evaluate(`(() => {
    const c = document.getElementById("compare");
    return {
      kopf: (c.querySelector(".cmp-delta") || {}).textContent || "",
      zeilen: [...c.querySelectorAll(".cmp-row")].map(r => r.innerText.split("\\n").join(" "))
    };
  })()`);
  note(!/%/.test(grenzfall.kopf),
       `Kein Prozentwert aus acht Monaten gegen zwei Tage („${grenzfall.kopf.trim()}")`);
  note(/zu wenig Vorjahr/i.test(grenzfall.kopf),
       "Und es steht da, woran es liegt — nicht nur ein leerer Platz");
  note(grenzfall.zeilen.some(z => /von \d+ Tagen/.test(z)),
       `Die knappe Zeile sagt, wie viele Tage sie meint („${(grenzfall.zeilen.find(z => /von \d+ Tagen/.test(z)) || "—").trim()}")`);

  await page.evaluate(`(() => { location.reload(); })()`);
  await page.waitForTimeout(600);
  await page.locator('[data-pane="history"]').first().click();
  await page.waitForTimeout(300);

  // **Auch in der Jahresansicht steht die Leiste** — vom Gerät verlangt: „immer
  // den Ist darstellen und den Forecast." Sie spricht dort vom Jahr, nicht von
  // einem Monat; stünde dort ein Monatsname, wäre die Zahl daneben falsch
  // beschriftet.
  await page.locator('[data-scale="year"]').first().click();
  await page.waitForTimeout(300);
  const jahresLeiste = await page.evaluate(() => {
    const el = document.getElementById("chart-forecast");
    return { sichtbar: el.style.display !== "none", text: el.innerText.replace(/\s+/g, " ").trim() };
  });
  note(jahresLeiste.sichtbar, "Die Jahresansicht zeigt Ist und Erwartung als Leiste");
  note(/gemessen/.test(jahresLeiste.text) && /erwartet/.test(jahresLeiste.text),
       `Beide Zahlen sind benannt („${jahresLeiste.text.slice(0, 60)}…“)`);
  note(/2026 · \d+ von \d+ Tagen/.test(jahresLeiste.text)
       && !MONATSNAMEN.some(n => jahresLeiste.text.includes(n)),
       "Und sie spricht vom Jahr, nicht von einem Monat");
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
  note(/Freischalten · 1,99/.test(kaufseite.text),
       "Und den Preis dazu, bevor jemand tippt");
  note(/Alles freischalten/.test(kaufseite.text) && /4,99/.test(kaufseite.text),
       "Das Bündel steht darunter, nicht als Regal davor");
  // Seit 0.92.0 stehen dort Stichpunkte statt eines Absatzes — geprüft wird
  // deshalb die Sache, nicht der Wortlaut: Der freie Export ist Produktprinzip
  // 5, und der Abgleich gehört genannt, weil ihn sonst niemand bemerkt.
  const frei = kaufseite.text.replace(/\s+/g, " ");
  note(/Export/.test(frei) && /kostenlos/.test(frei),
       "Die Kaufseite sagt, was kostenlos bleibt");
  note(/iCloud/.test(frei),
       "Und nennt den Abgleich, den sonst niemand bemerkt");

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
  // **Ein kostenloser Nutzer sieht, dass es Kosten gibt — und was sie kosten.**
  //
  // Der Umschalter „Menge / Kosten" erscheint erst mit Tarifen, und Tarife
  // gibt es erst mit dem Kauf. Ohne diese Zeile hätte jemand ohne Kauf nie
  // erfahren, dass die App Beträge kann.
  //
  // Der Schalter für den Kaufzustand steht im Zähler-Schirm; von einem anderen
  // Tab aus ist er da, aber nicht sichtbar — und ein Klick darauf wartet
  // dreißig Sekunden ins Leere.
  await page.locator('[data-pane="meters"]').first().click();
  await page.waitForTimeout(250);
  await page.locator('[data-pro="0"]').first().click();
  await page.waitForTimeout(250);
  await page.locator('[data-pane="history"]').first().click();
  await page.waitForTimeout(250);
  const sperre = await page.evaluate(() => {
    const box = document.getElementById("cost-lock");
    return { sichtbar: box && box.style.display !== "none",
             text: box ? box.innerText.replace(/\s+/g, " ") : "" };
  });
  note(sperre.sichtbar, "Ohne Kauf steht im Verlauf, dass es Kosten gibt");
  note(/1,99/.test(sperre.text), `Und was sie kosten: ${sperre.text.slice(0, 60)}`);

  await page.locator('[data-pane="meters"]').first().click();
  await page.waitForTimeout(200);
  await page.locator('[data-pro="1"]').first().click();
  await page.waitForTimeout(250);
  const nachKauf = await page.evaluate(() => {
    const box = document.getElementById("cost-lock");
    return box ? box.style.display === "none" : false;
  });
  note(nachKauf, "Nach dem Kauf verschwindet sie — kein Banner, das bleibt");

  // **Den Zustand zurückstellen.** Die Prüfungen danach rechnen mit einem
  // Nutzer ohne Kauf — Bündel, Wasserzeichen, Preise. Ein Block, der den
  // Kaufzustand verstellt zurücklässt, macht die nächsten drei rot und
  // sieht dann aus wie drei neue Fehler.
  await page.locator('[data-pro="0"]').first().click();
  await page.waitForTimeout(250);

  // Das Einkaufssymbol an der Zeile zur Übersicht. Vom Gründer verlangt: Ohne
  // Zeichen liest sie sich wie eine weitere Einstellung.
  const symbol = await page.evaluate(() =>
    !!document.querySelector("#store-row svg circle"));
  note(symbol, "Die Zeile zur Übersicht trägt ein Einkaufssymbol");

  // **Die Zeile sagt in ganzen Worten, was sie tut.** Sie hieß „Was
  // PulseMeter noch kann" — eine Umschreibung, die alles Mögliche meinen kann,
  // und über ihr stand als Überschrift „FREISCHALTEN". Vom Gründer benannt:
  // „nenne das ‚Alle Funktionen freischalten'." Die Überschrift ist damit weg;
  // zweimal dasselbe ist nicht doppelt so deutlich, sondern nur doppelt.
  const beschriftung = await page.evaluate(() => {
    const zeile = document.querySelector("#store-row .rl");
    const klein = zeile?.querySelector("small");
    return {
      titel: (zeile?.firstChild?.textContent || "").trim(),
      ueberschrift: [...document.querySelectorAll('[data-pane="meters"] .section-label')]
        .map(x => x.textContent.trim().toLowerCase()),
      stand: (klein?.textContent || "").trim(),
    };
  });
  note(beschriftung.titel === "Alle Funktionen freischalten",
       `Die Zeile heißt „Alle Funktionen freischalten" (steht: „${beschriftung.titel}")`);
  note(!beschriftung.ueberschrift.includes("freischalten"),
       "Über der Zeile steht das Wort nicht noch einmal als Überschrift");
  note(beschriftung.stand.length > 0,
       "An der Zeile steht, wie viel schon freigeschaltet ist");

  // **Die Kaufübersicht ist erreichbar, ohne an eine Grenze zu stoßen.**
  //
  // Bis 0.92.0 öffnete sich die Kaufseite ausschließlich vor einer Sperre. Wer
  // wissen wollte, was die App überhaupt kann, fand nirgends eine Antwort.
  await page.locator('[data-pane="meters"]').first().click();
  await page.waitForTimeout(250);
  await page.locator("#store-row").first().click();
  await page.waitForTimeout(300);
  const laden = await page.evaluate(() => ({
    offen: document.getElementById("sheet-store").classList.contains("on"),
    karten: [...document.querySelectorAll("#store-body [data-karte]")].map(x => x.dataset.karte),
    // **Die Zahl kommt aus dem Modell, nicht aus dieser Datei.** Sie stand
    // hier als 4 und musste beim fünften Kauf von Hand nachgezogen werden —
    // die Prüfung schlug an, aber sie prüfte den Zähler statt die Sache.
    erwartet: PRODUCTS.length,
    punkte: document.querySelectorAll("#store-body ul.includes li").length,
    absatz: document.getElementById("store-body").innerText.split("\n")
              .filter(z => z.trim().length > 120).length,
    text: document.getElementById("store-body").innerText
  }));
  note(laden.offen, "Die Kaufübersicht öffnet sich über eine eigene Zeile");
  note(laden.karten.length === laden.erwartet,
       `Alle ${laden.erwartet} Einzelkäufe stehen darin: ${laden.karten.join(", ")}`);
  note(/Alles freischalten/.test(laden.text) && /4,99/.test(laden.text),
       "Das Bündel steht oben, mit Preis");
  note(laden.punkte >= 14,
       `Stichpunkte statt Absätze: ${laden.punkte} Zeilen`);
  // Vom Gründer verlangt: „nicht so viel Fließtext". Eine Zeile über 120
  // Zeichen ist ein Absatz, und davon darf hier keiner stehen.
  note(laden.absatz === 0, `Kein Fließtext in der Übersicht (${laden.absatz} lange Zeilen)`);
  note(/iCloud/.test(laden.text), "Der kostenlose Abgleich wird genannt");
  await page.locator("#sheet-store [data-close]").first().click();
  await page.waitForTimeout(250);
  await page.locator('[data-pane="history"]').first().click();
  await page.waitForTimeout(250);

  // **Der Bericht steht an genau einer Stelle.** Bis 0.92.0 lag er im Menü
  // *und* in der Zeile darunter — der Gründer: „das mit dem Bericht ist glaub
  // doppelt". Das Menü trägt jetzt Tabellen, der Bericht seine eigene Zeile.
  await page.locator('[data-open="download"]').first().click();
  await page.waitForTimeout(300);
  const auswahl = await page.evaluate(() =>
    [...document.querySelectorAll("#sheet-download .rowbtn .rl")]
      .map(x => x.childNodes[0].textContent.trim()));
  note(auswahl.length === 2 && auswahl.every(x => /CSV/.test(x)),
       `Hinter „Tabellen" stehen zwei Tabellen: ${auswahl.join(", ")}`);
  note(!auswahl.some(x => /PDF|Bericht/.test(x)),
       "Der Bericht steht nicht doppelt — er hat seine eigene Zeile");
  await page.locator("#sheet-download [data-close]").first().click();
  await page.waitForTimeout(250);
  await page.locator('[data-open="report"]').first().click();
  await page.waitForTimeout(250);
  await page.locator("#makereport").click();
  await page.waitForTimeout(350);
  const bericht = await page.evaluate(() => ({
    offen: document.getElementById("sheet-report").classList.contains("on"),
    wasserzeichen: document.getElementById("doc").innerHTML.includes("Zählora · Vorschau"),
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
