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
  note(kaufseite.offen, "Die Grenze führt zur Kaufseite statt ins Leere");
  note(/Unbegrenzt viele Zähler/.test(kaufseite.erste),
       "Der Grund steht zuerst — wer am dritten Zähler hängt, liest nicht über PDF-Berichte");
  note(/Der Export\s+bleibt kostenlos/.test(kaufseite.text.replace(/\s+/g, " "))
       || /Export bleibt kostenlos/.test(kaufseite.text.replace(/\s+/g, " ")),
       "Die Kaufseite sagt, was kostenlos bleibt");

  // Nichts versprechen, was es noch nicht gibt: Foto-Belege und
  // Siri-Kurzbefehle sind aus 1.0 gestrichen (docs/07-v1-plan.md).
  const zuviel = ["Foto", "Beleg", "Siri", "Kurzbefehl"].filter(w => kaufseite.text.includes(w));
  note(zuviel.length === 0,
       `Die Kaufseite verspricht nichts aus 1.1${zuviel.length ? ": " + zuviel.join(", ") : ""}`);

  // Und der Kauf hebt sie auf.
  await page.locator("#pro-buy").click();
  await page.waitForTimeout(350);
  await page.locator("#add-meter").click();
  await page.waitForTimeout(300);
  note(await page.locator("#sheet-editor").evaluate(el => el.classList.contains("on")),
       "Nach dem Kauf öffnet derselbe Knopf wieder das Formular");
  await page.locator("#sheet-editor [data-close]").first().click();
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
