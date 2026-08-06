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
    await page.locator("#save").click();
    await page.waitForTimeout(250);
    note((await page.locator("#save").textContent()) === "Sichern",
         "Beim letzten Zählwerk steht „Sichern“");
    await page.locator("#prefill").click();
    await page.locator("#save").click();
    await page.waitForTimeout(400);
    const nachher = await page.evaluate(id =>
      METERS.find(m => m.id === id).registers.map(r => r.readings.length), zweiId);
    note(nachher.every((n, i) => n === vorher[i] + 1),
         `Beide Zählwerke erfasst (${vorher} → ${nachher})`);
  }

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
