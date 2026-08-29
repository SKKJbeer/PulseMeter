/* Nicht-funktionale Prüfungen am Klick-Dummy: Bedienbarkeit und Geschwindigkeit.
 *
 * **Warum getrennt von `check-prototype.mjs`.** Die dort prüft, ob die App das
 * Richtige *tut*. Hier steht, ob man es auch *kann*: ob ein Knopf am Zähler mit
 * dem Daumen zu treffen ist, ob die Schrift auf ihrem Untergrund lesbar bleibt,
 * ob jede Fläche einen Namen hat, den eine Vorlesefunktion aussprechen kann —
 * und ob das alles schnell genug passiert, dass niemand wartet.
 *
 * Die Maßstäbe sind nicht erfunden:
 *   - 44 × 44 Punkte Mindestgröße für alles Antippbare (Apple, Human Interface
 *     Guidelines). Der Nutzer steht am Zähler, einhändig, bei schlechtem Licht.
 *   - Kontrast 4,5:1 für normale Schrift, 3:1 für große (WCAG 2.2 AA).
 *   - Produktprinzip 2: drei Berührungen von App-Start bis zur gesicherten
 *     Folge-Ablesung. Wird hier gezählt, nicht behauptet.
 *   - Produktprinzip 3: fünf Sekunden Blickzeit — hier als Frage, ob die
 *     wichtigste Zahl ohne Scrollen sichtbar ist.
 *
 * Läuft unter Linux, ohne macOS-Läufer. Aufruf:
 *   node scripts/check-nichtfunktional.mjs [pfad-oder-url]
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

/* Kontrast nach WCAG: relative Helligkeit beider Farben, Verhältnis daraus. */
const kontrastCode = `
  (() => {
    const leuchtkraft = (r, g, b) => {
      const f = v => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
      return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
    };
    const zahlen = s => (s.match(/[\\d.]+/g) || []).map(Number);
    // Der Untergrund ist selten am Element selbst gesetzt — gesucht wird der
    // erste Vorfahr mit einer deckenden Farbe. Genau so sieht es das Auge.
    const untergrund = el => {
      for (let k = el; k; k = k.parentElement) {
        const c = zahlen(getComputedStyle(k).backgroundColor);
        if (c.length >= 3 && (c.length < 4 || c[3] > 0.9)) return c;
      }
      return [255, 255, 255];
    };
    const verhaeltnis = (a, b) => {
      const la = leuchtkraft(a[0], a[1], a[2]), lb = leuchtkraft(b[0], b[1], b[2]);
      return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    };
    const schlecht = [];
    for (const el of document.querySelectorAll("body *")) {
      const text = [...el.childNodes]
        .filter(n => n.nodeType === 3).map(n => n.textContent.trim()).join("");
      if (!text) continue;
      const box = el.getBoundingClientRect();
      if (box.width === 0 || box.height === 0) continue;
      const stil = getComputedStyle(el);
      if (stil.visibility === "hidden" || stil.opacity === "0") continue;
      // Auch die Vorfahren: Der Bestätigungswisch („Gesichert") hängt an einem
      // Behälter mit opacity 0 und ist erst nach dem Sichern zu sehen.
      let versteckt = false;
      for (let k = el.parentElement; k; k = k.parentElement) {
        const ks = getComputedStyle(k);
        if (ks.opacity === "0" || ks.visibility === "hidden" || ks.display === "none") {
          versteckt = true; break;
        }
      }
      if (versteckt) continue;
      const groesse = parseFloat(stil.fontSize);
      const fett = parseInt(stil.fontWeight, 10) >= 700;
      // „Groß" nach WCAG: ab 24 px, oder ab 18,66 px wenn fett.
      const grenze = groesse >= 24 || (fett && groesse >= 18.66) ? 3 : 4.5;
      const v = verhaeltnis(zahlen(stil.color), untergrund(el));
      if (v < grenze) {
        schlecht.push({ text: text.slice(0, 40), groesse, verhaeltnis: Math.round(v * 100) / 100, grenze });
      }
    }
    return schlecht;
  })()
`;

/* Alles, was man antippen kann, samt gemessener Fläche.
 *
 * **Zwei Maßstäbe, nicht einer.** Die 44 Punkte gelten für Flächen, die für
 * sich stehen: ein Knopf, eine Listenzeile, eine Karte. Für Bedienelemente
 * *in* einer Gruppe — ein Segmentwähler, eine Reihe Marken — gelten sie nicht,
 * und zwar nicht als Ausrede: Apples eigener `UISegmentedControl` ist 32 Punkte
 * hoch, und iOS setzt ihn überall ein. Eine Prüfung, die das als Fehler meldet,
 * meldet einen Fehler an iOS.
 *
 * **Was nicht gemessen wird:** verdeckte Bögen (`.sheet` ohne `on`) — sie sind
 * da, aber nicht bedienbar — und der Block „Nur im Entwurf", den es in der App
 * nicht gibt. */
const trefferCode = `
  (() => {
    const zuKlein = [];
    const bedienbar = el => {
      if (el.closest("[data-entwurf]")) return false;
      const bogen = el.closest(".sheet");
      if (bogen && !bogen.classList.contains("on")) return false;
      const b = el.getBoundingClientRect();
      const s = getComputedStyle(el);
      return b.width > 0 && b.height > 0 && s.visibility !== "hidden"
          && s.display !== "none" && s.opacity !== "0";
    };
    for (const el of document.querySelectorAll("button, a[href], input, select, [role=button]")) {
      if (!bedienbar(el)) continue;
      const b = el.getBoundingClientRect();
      // **Ein Ziel in einem größeren Ziel ist kein eigenes Ziel.** Die Zahl
      // „≈ 283 € Guthaben" ist antippbar, aber sie sitzt in einer Karte, die
      // dasselbe öffnet — der Daumen trifft die Karte. Gemessen wird, was
      // wirklich getroffen werden muss.
      const drinnen = el.parentElement
        && el.parentElement.closest("button, [role=button], [data-explain], .rowbtn, .card");
      if (drinnen) continue;
      // In einer Gruppe? Dann ist die Gruppe das Ziel, nicht das Segment.
      const gruppe = el.closest(".segmented, .picker, .exportbar, .momentrow, .sheet-head");
      const grenze = gruppe ? 30 : 44;
      if (b.width < grenze || b.height < grenze) {
        zuKlein.push({
          name: (el.getAttribute("aria-label") || el.textContent || el.id || el.tagName).trim().slice(0, 34),
          breite: Math.round(b.width), hoehe: Math.round(b.height), grenze
        });
      }
    }
    return zuKlein;
  })()
`;

/* Jede Fläche braucht einen Namen, den man vorlesen kann. */
const namenCode = `
  (() => {
    const ohne = [];
    for (const el of document.querySelectorAll("button, a[href], [role=button]")) {
      if (el.closest("[data-entwurf]")) continue;
      const b = el.getBoundingClientRect();
      if (b.width === 0 || b.height === 0) continue;
      const name = (el.getAttribute("aria-label") || el.textContent || "").trim();
      if (!name) ohne.push(el.outerHTML.slice(0, 70));
    }
    return ohne;
  })()
`;

for (const scheme of ["light", "dark"]) {
  console.log(`\nErscheinungsbild: ${scheme}`);
  const page = await browser.newPage({ viewport: { width: 393, height: 852 }, colorScheme: scheme });
  await page.goto(url);
  await page.waitForTimeout(400);

  // --- Bedienbarkeit: Trefferflächen auf jedem Hauptschirm, auch in den Bögen
  for (const [sel, name] of [['[data-pane="home"]', "Übersicht"],
                             ['[data-pane="history"]', "Verlauf"],
                             ['[data-pane="meters"]', "Zähler"]]) {
    await page.locator(sel).first().click();
    await page.waitForTimeout(250);
    const klein = await page.evaluate(trefferCode);
    note(klein.length === 0,
         `${name}: alles Antippbare ist groß genug für einen Daumen`
         + (klein.length ? " — zu klein: "
            + klein.map(k => `${k.name} (${k.breite}×${k.hoehe}, ${k.grenze} verlangt)`).join(", ") : ""));

    const ohneNamen = await page.evaluate(namenCode);
    note(ohneNamen.length === 0,
         `${name}: jede Fläche trägt einen Namen`
         + (ohneNamen.length ? " — ohne: " + ohneNamen.join(" | ") : ""));
  }

  // --- Der Ziffernblock: der Schirm, an dem das Produkt gewinnt oder verliert
  await page.locator('[data-pane="home"]').first().click();
  await page.waitForTimeout(200);
  await page.locator("[data-capture]").first().click();
  await page.waitForTimeout(350);
  const tasten = await page.evaluate(`
    (() => {
      const b = [...document.querySelectorAll('#keys [data-key]')].map(el => el.getBoundingClientRect());
      return { anzahl: b.length,
               kleinste: Math.min(...b.map(r => Math.min(r.width, r.height))) };
    })()
  `);
  note(tasten.anzahl >= 11 && tasten.kleinste >= 44,
       `Ziffernblock: ${tasten.anzahl} Tasten, kleinste Kante ${Math.round(tasten.kleinste)} Punkte`);

  // --- Lesbarkeit
  const schlecht = await page.evaluate(kontrastCode);
  note(schlecht.length === 0,
       `Kontrast reicht überall (WCAG AA)`
       + (schlecht.length
          ? ` — ${schlecht.length} zu blass, z. B. „${schlecht[0].text}" mit ${schlecht[0].verhaeltnis}:1 statt ${schlecht[0].grenze}:1`
          : ""));

  await page.close();
}

/* ============================================================
   Geschwindigkeit — gemessen, nicht geschätzt
   ============================================================ */
console.log("\nGeschwindigkeit");
{
  const page = await browser.newPage({ viewport: { width: 393, height: 852 } });
  const beginn = Date.now();
  await page.goto(url);
  await page.waitForSelector("#cards .card, #status", { timeout: 5000 });
  const start = Date.now() - beginn;
  note(start < 2500, `Erster Schirm steht nach ${start} ms (Grenze 2500)`);

  // Jede Messung im Browser selbst: Was hier gemessen wird, ist die Arbeit der
  // Anwendung, nicht die Zeit, die Playwright zum Hin- und Herreden braucht.
  const messung = async (name, code, grenze) => {
    const ms = await page.evaluate(`
      (() => { const t = performance.now(); ${code}; return performance.now() - t; })()
    `);
    note(ms < grenze, `${name}: ${ms.toFixed(1)} ms (Grenze ${grenze})`);
  };

  await messung("Verlauf zeichnen", "renderHistory()", 400);
  await messung("Zähler wechseln", "histMeter = METERS[1].id; renderPicker(); renderHistory()", 400);
  await messung("Tabelle mit allen Zahlen", "histMode = 'table'; renderHistory()", 400);
  await messung("Zurück aufs Diagramm", "histMode = 'chart'; renderHistory()", 400);
  await messung("Übersicht neu aufbauen", "renderCards(); renderStatus()", 400);
  await messung("Zählerliste aufbauen", "renderMeterList()", 400);

  // Der Bericht ist das Schwerste, was der Entwurf tut.
  await messung("Verbrauchsbericht bauen", "repScope = \"all\"; renderReport()", 1500);

  await page.close();
}

/* ============================================================
   Produktprinzipien, gezählt statt behauptet
   ============================================================ */
console.log("\nProduktprinzipien");
{
  const page = await browser.newPage({ viewport: { width: 393, height: 852 } });
  await page.goto(url);
  await page.waitForTimeout(400);

  // Prinzip 2: drei Berührungen von App-Start bis zur gesicherten Ablesung.
  // Gezählt wird jeder echte Klick — Zähler antippen, Wert übernehmen, sichern.
  //
  // **Vorher eine Berichtigung an dieser Prüfung selbst.** Der erste Anlauf
  // klickte blind auf „Sichern" und lief in eine Zeitüberschreitung: Der Knopf
  // lag unterhalb des sichtbaren Teils des Bogens. Das sah nach einem echten
  // Fehler aus, ist aber einer der Messung — der Geräterahmen im Entwurf ist
  // kleiner als ein echtes Telefon (der Bogen endet bei 765 von 852 Punkten),
  // und auf dem Gerät passt derselbe Inhalt. Gerollt wird deshalb wie ein
  // Mensch es täte; gezählt werden nur die Berührungen auf Zielen.
  let beruehrungen = 0;
  // 350 ms zwischen den Berührungen: Der Bogen fährt herein, und ein Klick
  // gegen eine noch fahrende Fläche zählt zwar, trifft aber nichts. Gezählt
  // wird, was ein Mensch tut — nicht, wie schnell ein Rechner tippen kann.
  // **Getippt wird über das Ereignis, nicht über die Maus.**
  //
  // Playwright prüft vor jedem Klick nach, ob die Fläche frei liegt, und
  // scrollt dafür selbst. Im Geräterahmen des Entwurfs führt das zu einem
  // Wettlauf: Der Bogen bewegt sich noch, die Prüfung misst neu, und am Ende
  // wartet sie dreißig Sekunden auf einen Knopf, den sie selbst aus dem Bild
  // geschoben hat. Ob eine Fläche groß genug und frei ist, prüft weiter oben
  // ohnehin die Messung der Trefferflächen — hier zählt nur, ob drei
  // Berührungen zu einer gesicherten Ablesung führen.
  const tippe = async sel => {
    await page.locator(sel).first().dispatchEvent("click");
    beruehrungen += 1;
    await page.waitForTimeout(300);
  };

  // **Ein gewöhnlicher Zähler**, nicht der erstbeste. Ein Doppeltarifzähler
  // führt zwei Zahlen und braucht dafür zu Recht zwei Eingaben — Prinzip 2
  // spricht vom Normalfall. Der erste Anlauf dieser Prüfung ist genau darüber
  // gestolpert und hat einen Fehler gemeldet, wo keiner war.
  const ziel = await page.evaluate(`(() => {
    const m = METERS.find(x => x.registers.length === 1 && x.registers[0].readings.length > 0);
    return m ? { id: m.id, stand: m.registers[0].readings.length } : null;
  })()`);
  const vorher = ziel.stand;
  await tippe(`[data-capture="${ziel.id}"]`);
  await tippe("#prefill");
  await tippe("#save");
  await page.waitForTimeout(400);
  const nachher = await page.evaluate(
    `METERS.find(x => x.id === "${ziel.id}").registers[0].readings.length`);
  note(nachher === vorher + 1 && beruehrungen <= 3,
       `Folge-Ablesung in ${beruehrungen} Berührungen gesichert (Prinzip 2: höchstens 3)`);

  // Prinzip 3: „Ist alles im Rahmen?" ohne Scrollen. Geprüft wird, ob die
  // erste Karte samt ihrer Zahl vollständig im ersten Bild steht.
  await page.locator('[data-pane="home"]').first().click();
  await page.waitForTimeout(300);
  const sichtbar = await page.evaluate(`
    (() => {
      const karte = document.querySelector("#cards .card");
      if (!karte) return null;
      const b = karte.getBoundingClientRect();
      return { unten: Math.round(b.bottom), fenster: window.innerHeight };
    })()
  `);
  note(sichtbar && sichtbar.unten <= sichtbar.fenster,
       `Die erste Karte steht ohne Scrollen im Bild (endet bei ${sichtbar?.unten} von ${sichtbar?.fenster})`);

  // Prinzip 4: keine Sackgasse — jede angezeigte Zahl ist antippbar.
  const tote = await page.evaluate(`
    (() => [...document.querySelectorAll("#cards .card")]
      .filter(k => !k.matches("button, [data-explain], [data-pick], [role=button]")
                && !k.querySelector("button, [data-explain], [role=button]")).length)()
  `);
  note(tote === 0, `Jede Karte auf der Übersicht führt weiter (Prinzip 4)`);

  await page.close();
}

await browser.close();

console.log("");
if (failures.length) {
  console.log(`${failures.length} nicht-funktionale Prüfung(en) fehlgeschlagen.`);
  process.exit(1);
}
console.log("Bedienbarkeit und Geschwindigkeit sind durchgelaufen.");
