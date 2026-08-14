/* Prüft die Website headless — dieselbe Machart wie `check-prototype.mjs`.
 *
 * **Warum eine eigene Prüfung.** Diese vier Seiten sind das einzige Stück des
 * Projekts, an dem ein Fehler nicht nur ärgerlich, sondern teuer ist: Ein
 * toter Verweis aufs Impressum ist in Deutschland abmahnfähig, und eine
 * Datenschutz-Adresse, die ins Leere geht, lehnt Apple bei der Einreichung ab.
 *
 * Die wichtigste Prüfung ist die letzte: **null Anfragen an fremde Server.**
 * Ohne sie ist das Versprechen „keine Cookies, kein Zustimmungsfenster" eine
 * Behauptung. Eine eingebundene Schriftart genügt, um es zu brechen, und man
 * sieht ihr das nicht an — deshalb wird es gemessen und nicht gelesen.
 *
 * Läuft unter Linux und braucht keinen macOS-Läufer. Aufruf:
 *   node scripts/check-website.mjs [ordner]
 */
import { chromium } from "playwright";
import { readFileSync, readdirSync } from "node:fs";

const dir = process.argv[2] || "docs/website";
const base = "file://" + process.cwd() + "/" + dir + "/";

const seiten = ["index.html", "hilfe.html", "datenschutz.html", "impressum.html"];

const failures = [];
const note = (ok, text) => {
  console.log((ok ? "  ok   " : "  FEHL ") + text);
  if (!ok) failures.push(text);
};

// --- Ohne Browser: das, was im Quelltext stehen muss oder nicht darf

console.log("\nQuelltext");

for (const datei of seiten) {
  const html = readFileSync(`${dir}/${datei}`, "utf8");

  note(/<html lang="de">/.test(html), `${datei}: Sprache ist ausgezeichnet`);
  note(/<title>[^<]{10,70}<\/title>/.test(html), `${datei}: Titel vorhanden und in brauchbarer Länge`);

  const beschreibung = html.match(/<meta name="description" content="([^"]+)"/);
  note(!!beschreibung, `${datei}: Beschreibung vorhanden`);
  if (beschreibung) {
    const n = beschreibung[1].length;
    // Google schneidet bei rund 160 Zeichen ab; unter 70 verschenkt man die
    // einzige Zeile, mit der man in der Ergebnisliste um Aufmerksamkeit wirbt.
    note(n >= 70 && n <= 200, `${datei}: Beschreibung ${n} Zeichen (70–200)`);
  }

  // Verweise auf die Pflichtseiten von **jeder** Seite aus. Zwei Klicks sind
  // erlaubt, einer ist besser — und im Fuß steht er auf jeder Seite.
  for (const ziel of ["datenschutz.html", "impressum.html"]) {
    if (datei === ziel) continue;
    note(html.includes(`href="${ziel}"`), `${datei}: Verweis auf ${ziel}`);
  }

  // Keine fremde Quelle im Quelltext. Erlaubt sind Verweise (`href` auf eine
  // andere Website), verboten ist alles, was der Browser **nachlädt**.
  const geladen = [...html.matchAll(/\ssrc="(https?:)?\/\/[^"]+"/g)].map(m => m[0]);
  const stile = [...html.matchAll(/<link[^>]+rel="stylesheet"[^>]+href="(https?:)?\/\/[^"]+"/g)];
  note(geladen.length === 0 && stile.length === 0,
       `${datei}: nichts wird von fremden Servern nachgeladen`);
}

// Platzhalter sind ein **Hinweis**, kein Fehlschlag — solange die Seite nicht
// online ist. Sonst stünde die CI dauerhaft auf Rot für etwas, das nur der
// Gründer eintragen kann, und ein dauerhaft roter Lauf wird nach drei Tagen
// nicht mehr gelesen. Zum Fehlschlag wird es, sobald `PULSE_WEBSITE_LIVE=1`
// gesetzt ist — das gehört in den Veröffentlichungsschritt.
const platzhalter = seiten
  .filter(d => readFileSync(`${dir}/${d}`, "utf8").includes("PLATZHALTER"));
if (platzhalter.length === 0) {
  note(true, "Keine Platzhalter mehr im Quelltext");
} else if (process.env.PULSE_WEBSITE_LIVE === "1") {
  note(false, `Platzhalter offen in: ${platzhalter.join(", ")} — die Seite darf so nicht online`);
} else {
  console.log(`  offen  Platzhalter in ${platzhalter.join(", ")} — siehe ${dir}/EINTRAGEN.md`);
}

// --- Mit Browser

const browser = await chromium.launch({
  executablePath: process.env.PULSE_CHROMIUM || undefined
});

for (const scheme of ["light", "dark"]) {
  for (const breite of [320, 768, 1280]) {
    console.log(`\nErscheinungsbild ${scheme}, Breite ${breite}`);

    const page = await browser.newPage({
      viewport: { width: breite, height: 900 },
      colorScheme: scheme
    });

    const jsErrors = [];
    const fremd = [];
    page.on("pageerror", e => jsErrors.push(e.message));
    page.on("console", m => { if (m.type() === "error") jsErrors.push(m.text()); });
    page.on("request", r => { if (!r.url().startsWith("file:")) fremd.push(r.url()); });

    for (const datei of seiten) {
      await page.goto(base + datei);
      await page.waitForTimeout(120);

      const h1 = await page.locator("h1").first().textContent();
      note(!!h1 && h1.trim().length > 3, `${datei}: Überschrift „${(h1 || "").trim().slice(0, 40)}"`);

      // Horizontaler Überlauf. Bei 320 px fällt jede zu breite Tabelle und
      // jedes nicht umbrechende Wort auf — genau dort, wo es weh tut.
      const ueberlauf = await page.evaluate(() =>
        document.documentElement.scrollWidth - document.documentElement.clientWidth);
      note(ueberlauf <= 1, `${datei}: kein horizontaler Überlauf (${ueberlauf} px)`);

      // Jeder interne Verweis muss auf eine Datei zeigen, die es gibt.
      const ziele = await page.evaluate(() =>
        [...document.querySelectorAll("a[href]")]
          .map(a => a.getAttribute("href"))
          .filter(h => h && !/^(https?:|mailto:|#)/.test(h)));
      const vorhanden = readdirSync(dir);
      for (const z of new Set(ziele)) {
        const datei2 = z.split("#")[0].replace(/^\//, "") || "index.html";
        note(vorhanden.includes(datei2), `${datei}: Verweis „${z}" führt irgendwohin`);
      }

      // Bilder brauchen eine Beschreibung — sonst hört jemand mit VoiceOver
      // nur „Bild".
      const ohneText = await page.evaluate(() =>
        [...document.querySelectorAll("img")].filter(i => !i.alt || i.alt.length < 8).length);
      note(ohneText === 0, `${datei}: alle Bilder haben eine Beschreibung`);
    }

    note(jsErrors.length === 0,
         jsErrors.length === 0 ? "Keine JavaScript-Fehler" : `JavaScript-Fehler: ${jsErrors[0]}`);
    note(fremd.length === 0,
         fremd.length === 0
           ? "Keine einzige Anfrage an einen fremden Server"
           : `Fremde Anfrage: ${fremd[0]}`);

    await page.close();
  }
}

await browser.close();

console.log(`\n${failures.length === 0 ? "Alles grün" : failures.length + " Prüfung(en) gefallen"}`);
if (failures.length) {
  for (const f of failures) console.log("  · " + f);
  process.exit(1);
}
