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

// Die Antwortseiten zählen mit: Sie sind der Teil, über den jemand die
// Website überhaupt findet (`docs/10-sichtbarkeit.md`, Abschnitt 7), und ein
// toter Verweis dorthin fällt sonst niemandem auf.
const seiten = ["index.html", "hilfe.html", "gas-in-kwh.html",
                "abschlag-zu-hoch.html", "datenschutz.html", "impressum.html"];

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

  // **Kommentarzeichen müssen paarweise auftreten.**
  //
  // Beim Entfernen eines Platzhalters in 0.48.2 blieb die zweite Zeile eines
  // zweizeiligen Kommentars stehen — ein `-->` ohne Anfang. Der Browser zeigt
  // so etwas als **Text** an, mitten im Impressum, und keine der bisherigen
  // Prüfungen sah es: Überschrift, Verweise und Überlauf waren in Ordnung.
  const ohneKommentar = html.replace(/<!--[\s\S]*?-->/g, "");
  note(!ohneKommentar.includes("-->") && !ohneKommentar.includes("<!--"),
       `${datei}: keine losen Kommentarzeichen`);

  // **Jede eckige Klammer im Text ist ein Platzhalter — und muss als solcher
  // markiert sein.** Sonst rutscht ein `[USt-IdNr. eintragen]` durch, weil der
  // dazugehörige Kommentar beim Bearbeiten verlorenging: Die Zählung stünde auf
  // null, und im Impressum stünde trotzdem eine Klammer.
  //
  // **Skripte zählen nicht dazu.** Die strukturierten Daten für Suchmaschinen
  // stehen als JSON in der Seite, und eine Liste in JSON ist eine eckige
  // Klammer. Sie stand als „Platzhalter im Impressum" da, obwohl sie nichts
  // ist, was jemand liest — der Text zwischen den Klammern kommt ohnehin aus
  // der Hilfeseite. Geprüft wird, was im Browser als Text erscheint.
  const sichtbar = html
    .replace(/<!--[\s\S]*?-->/g, "")
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<[^>]+>/g, " ");
  const klammern = sichtbar.match(/\[[^\]]{3,}\]/g) || [];
  const markiert = (html.match(/PLATZHALTER/g) || []).length;
  note(klammern.length === 0 || markiert > 0,
       klammern.length === 0
         ? `${datei}: keine offenen Klammern im Text`
         : `${datei}: ${klammern[0]} steht ohne PLATZHALTER-Kommentar da`);

  // Keine fremde Quelle im Quelltext. Erlaubt sind Verweise (`href` auf eine
  // andere Website), verboten ist alles, was der Browser **nachlädt**.
  const geladen = [...html.matchAll(/\ssrc="(https?:)?\/\/[^"]+"/g)].map(m => m[0]);
  const stile = [...html.matchAll(/<link[^>]+rel="stylesheet"[^>]+href="(https?:)?\/\/[^"]+"/g)];
  note(geladen.length === 0 && stile.length === 0,
       `${datei}: nichts wird von fremden Servern nachgeladen`);
}

// Alle Seiten müssen auf **dieselbe** Adresse zeigen. Eine halb umgestellte
// Website ist schlimmer als eine mit der falschen Adresse: Suchmaschinen
// halten `canonical` für die Wahrheit und werfen weg, was auf eine fremde
// Adresse verweist. `scripts/domain-setzen.sh` stellt um, das hier merkt, wenn
// es jemand doch von Hand versucht hat.
const adressen = new Set(seiten.map(d => {
  const m = readFileSync(`${dir}/${d}`, "utf8").match(/rel="canonical" href="https:\/\/([^/"]+)/);
  return m ? m[1] : "—";
}));
// Sitemap und robots.txt müssen auf dieselbe Adresse zeigen wie die Seiten.
// Eine Sitemap mit fremdem Namen wird verworfen, und dann ist sie schlimmer
// als keine: Man hält sie für erledigt.
// Der Namensraum der Sitemap heißt `sitemaps.org` — mit s. Beim ersten
// Schreiben stand hier `sitemap.org`, und damit hätte Google die Datei
// verworfen, ohne sich zu beschweren.
{
  const xml = readFileSync(`${dir}/sitemap.xml`, "utf8");
  note(xml.includes('xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"'),
       "sitemap.xml: richtiger Namensraum");
  const zahl = (xml.match(/<loc>/g) || []).length;
  note(zahl >= 5, `sitemap.xml führt ${zahl} Adressen`);
}

for (const datei of ["robots.txt", "sitemap.xml"]) {
  const inhalt = readFileSync(`${dir}/${datei}`, "utf8");
  const fremde = [...inhalt.matchAll(/https:\/\/([^/\s<"]+)/g)].map(m => m[1]);
  note(fremde.length > 0 && fremde.every(h => h === [...adressen][0]),
       `${datei}: nennt ${[...new Set(fremde)].join(", ") || "keine Adresse"}`);
}

note(adressen.size === 1,
     adressen.size === 1
       ? `Alle Seiten zeigen auf ${[...adressen][0]}`
       : `Die Seiten zeigen auf verschiedene Adressen: ${[...adressen].join(", ")}`);

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
