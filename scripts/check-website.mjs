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
import { chromium, webkit } from "playwright";
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { execFileSync } from "node:child_process";

const dir = process.argv[2] || "docs/website";
// **Über einen Webserver, nicht als Datei.** Bis 0.117.0 öffnete die Prüfung
// die Seiten mit `file://`. Mit absoluten Pfaden wie `/favicon.ico` zeigt das
// auf die Wurzel der Festplatte, und die Seite für unbekannte Adressen braucht
// genau solche Pfade. Ein kleiner Server auf dem eigenen Rechner liefert die
// Dateien so aus, wie Cloudflare es tut, und `fremd` heißt dann: nicht von
// diesem Server.
import { createServer } from "node:http";
import { extname, join, normalize } from "node:path";
const ARTEN = { ".html": "text/html; charset=utf-8", ".css": "text/css", ".svg": "image/svg+xml",
                ".png": "image/png", ".jpg": "image/jpeg", ".ico": "image/x-icon",
                ".xml": "application/xml", ".txt": "text/plain", ".js": "text/javascript" };
const server = createServer((req, res) => {
  const pfad = normalize(decodeURIComponent(req.url.split("?")[0])).replace(/^(\.\.[/\\])+/, "");
  const datei = join(dir, pfad.endsWith("/") ? pfad + "index.html" : pfad);
  if (!datei.startsWith(normalize(dir)) || !existsSync(datei)) {
    res.writeHead(404, { "Content-Type": ARTEN[".html"] });
    return res.end(existsSync(join(dir, "404.html")) ? readFileSync(join(dir, "404.html")) : "404");
  }
  res.writeHead(200, { "Content-Type": ARTEN[extname(datei)] || "application/octet-stream" });
  res.end(readFileSync(datei));
});
await new Promise(r => server.listen(0, "127.0.0.1", r));
const base = `http://127.0.0.1:${server.address().port}/`;

// Die Antwortseiten zählen mit: Sie sind der Teil, über den jemand die
// Website überhaupt findet (`docs/10-sichtbarkeit.md`, Abschnitt 7), und ein
// toter Verweis dorthin fällt sonst niemandem auf.
const seiten = ["index.html", "entwicklung.html", "hilfe.html", "gas-in-kwh.html",
                "abschlag-zu-hoch.html", "zaehlerstand-umzug.html", "ratgeber.html",
                "verbrauch-berechnen.html", "datenschutz.html", "impressum.html", "404.html"];

// Was nicht in den Index soll: das Impressum (erreichbar, nicht auffindbar)
// und die Seite für unbekannte Adressen. Beide tragen `noindex`, keine steht
// in der Sitemap, und die Seite für unbekannte Adressen hat keine kanonische
// Adresse, weil sie unter jeder beliebigen antwortet.
const ohneIndex = d => /<meta name="robots" content="noindex">/.test(readFileSync(`${dir}/${d}`, "utf8"));

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
const adressen = new Set(seiten.filter(d => d !== "404.html").map(d => {
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

// **Wie ein Mensch, nicht wie eine Werbeagentur.**
//
// Vom Gründer am 28. August verlangt: „Die Texte dürfen nicht nach KI oder
// Werbeagentur klingen. Schreibe so, wie ein Mensch einem anderen Menschen die
// App erklären würde."
//
// Zwei Dinge lassen sich zählen, und beide waren der Grund für die Ansage:
//
// 1. **Der Gedankenstrich.** Die Startseite hatte 25 auf 1150 Wörter, einen
//    alle 46. Er schiebt einen Nachsatz an jeden Satz und lässt den Text
//    atemlos klingen. Ein Punkt oder ein Doppelpunkt tut es fast immer.
// 2. **Wörter, die nichts sagen.** „smart", „intelligent", „nahtlos",
//    „mühelos", „erlebe", „entdecke". Sie passen auf jede App und sagen über
//    keine etwas.
//
// Die Schwelle liegt bei einem Strich je 250 Wörter. Das ist keine Null: Als
// Trenner in einem Titel ist er richtig, und ein echter Einschub darf sein.
//
// **Die Liste steht in `scripts/floskeln.txt`, nicht hier.** Seit 0.111.0 liest
// sie auch `check-store-texte.py` — dieselben Wörter dürfen im App Store so
// wenig stehen wie auf der Website, und eine zweite Kopie wäre die vierte
// Stelle in diesem Projekt, an der zwei Fassungen auseinanderlaufen.
const VERBOTEN = readFileSync(
  new URL("floskeln.txt", import.meta.url), "utf8")
  .split("\n")
  .map(z => z.trim())
  .filter(z => z && !z.startsWith("#"));

for (const datei of seiten) {
  const roh = readFileSync(`${dir}/${datei}`, "utf8");
  // Titel und Fußzeile benutzen den Strich als **Trenner** — „Hilfe —
  // PulseMeter". Das ist Typografie und kein Tick, also fallen beide vor dem
  // Zählen heraus. Im ersten Anlauf tat das nur der Kommentar und nicht der
  // Code, und die Prüfung schlug auf vier Seiten wegen ihrer eigenen Titel an.
  const sichtbar = roh
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<title>[\s\S]*?<\/title>/gi, " ")
    .replace(/<footer[\s\S]*?<\/footer>/gi, " ")
    .replace(/<[^>]+>/g, " ");
  const woerter = sichtbar.split(/\s+/).filter(Boolean).length;
  const striche = (sichtbar.match(/\w\s—\s\w/g) || []).length;
  const erlaubt = Math.max(1, Math.round(woerter / 250));
  note(striche <= erlaubt,
       `${datei}: ${striche} Gedankenstriche auf ${woerter} Wörter (bis ${erlaubt})`);

  const klein = sichtbar.toLowerCase();
  const gefunden = VERBOTEN.filter(w => klein.includes(w));
  note(gefunden.length === 0,
       gefunden.length === 0
         ? `${datei}: keine Wörter, die auf jede App passen`
         : `${datei}: ${gefunden.join(", ")} — sagt über diese App nichts`);
}

// **Die Seite darf sich nicht selbst widersprechen, was den Laden angeht.**
//
// `appstore-knopf.sh` legt genau **einen** Block um: das Abzeichen. Die drei
// Sätze drumherum — „Die App ist noch nicht im App Store", „Kaufen kann man
// noch nichts", „die geplanten Preise" — hat es nie angefasst, und daran hat
// auch nie jemand gedacht. Ergebnis am 5. September: Ein Abzeichen, das in den
// Laden führt, direkt über einem Absatz, der sagt, dort sei nichts. Aufgefallen
// ist es dem Gründer, nicht der Prüfsuite.
//
// Geprüft wird deshalb die **Übereinstimmung**, nicht der einzelne Satz: Führt
// das Abzeichen in den Laden, darf kein Satz das Gegenteil behaupten. Steht es
// auf „Bald", darf umgekehrt kein Preis als gültig angekündigt sein.
{
  const roh = readFileSync(`${dir}/index.html`, "utf8");
  const sichtbar = roh.replace(/<!--[\s\S]*?-->/g, " ");
  const imLaden = /class="apfel"\s+href="https:\/\/apps\.apple\.com/.test(sichtbar);
  const wartet = sichtbar.includes("apfel-wartet");

  note(imLaden !== wartet,
       imLaden !== wartet
         ? `Das Abzeichen ist eindeutig: ${imLaden ? "führt in den Laden" : "wartet"}`
         : "Das Abzeichen ist weder Verweis noch Wartezustand — appstore-knopf.sh hat halb gewirkt");

  // Sätze, die nur stimmen, solange die App **nicht** zu haben ist.
  const NUR_VOR_DEM_LADEN = [
    "noch nicht im App Store", "nicht im App Store", "nicht im Store",
    "Kaufen kann man noch nichts", "geplanten Preise", "Bald im App Store",
  ];
  const widerspruch = imLaden
    ? NUR_VOR_DEM_LADEN.filter(satz => sichtbar.includes(satz))
    : [];
  note(widerspruch.length === 0,
       widerspruch.length === 0
         ? "Kein Satz widerspricht dem Abzeichen"
         : `Das Abzeichen führt in den Laden, im Text steht aber: „${widerspruch.join("\", \"")}"`);
}

// **Kein Verweis auf ein Arbeitsmittel.**
//
// Auf der Startseite führte „Jetzt ausprobieren" auf den Klick-Dummy bei
// `claude.ai`. Das war richtig, solange es nichts zu laden gab. Seit die App im
// Laden steht, sind es zwei Aufforderungen nebeneinander, und die auffälligere
// führt in einen Entwurf. Der Klick-Dummy ist Arbeitsmittel im Repository,
// kein Angebot an Käufer.
for (const datei of seiten) {
  const roh = readFileSync(`${dir}/${datei}`, "utf8").replace(/<!--[\s\S]*?-->/g, " ");
  const treffer = [...roh.matchAll(/href="(https?:\/\/[^"]*claude\.ai[^"]*)"/g)].map(m => m[1]);
  note(treffer.length === 0,
       treffer.length === 0
         ? `${datei}: kein Verweis auf ein Arbeitsmittel`
         : `${datei}: verweist auf ${treffer.join(", ")} — das ist der Entwurf, nicht das Produkt`);
}

// **Jede benutzte CSS-Variable muss es geben.**
//
// `var(--bg)` stand im Stil des App-Store-Abzeichens, und die Datei kennt nur
// `--ground`, `--raised` und `--surface`. Ein unbekannter Name ist im Browser
// keine Fehlermeldung, sondern ein Rückfall auf den geerbten Wert — im Dunkeln
// also fast dasselbe Weiß wie der Grund. Auf dem Telefon des Gründers stand
// ein leerer grauer Kasten, und keine der 393 Prüfungen sah etwas: Der Text
// war da, nur unsichtbar.
{
  // Ohne Kommentare: Der Hinweis, warum `var(--bg)` hier einmal stand, ist
  // kein Gebrauch der Variable — sonst schlägt die Prüfung auf ihrer eigenen
  // Begründung an.
  const css = readFileSync(`${dir}/stil.css`, "utf8").replace(/\/\*[\s\S]*?\*\//g, " ");
  const definiert = new Set([...css.matchAll(/(--[a-z0-9-]+)\s*:/g)].map(m => m[1]));
  const benutzt = new Set([...css.matchAll(/var\((--[a-z0-9-]+)/g)].map(m => m[1]));
  const fehlend = [...benutzt].filter(name => !definiert.has(name));
  note(fehlend.length === 0,
       fehlend.length === 0
         ? `Alle ${benutzt.size} benutzten CSS-Variablen sind definiert`
         : `Nicht definiert: ${fehlend.join(", ")} — der Browser meldet das nicht, er erbt`);
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


// --- Aufbau: Was es an Seiten gibt, muss überall bekannt sein
//
// **Eine neue Seite, die hier fehlt, wird nie geprüft.** Die Liste oben ist
// von Hand gepflegt; mit 0.116.7 kamen zwei Seiten dazu, und ob sie in der
// Liste standen, hing daran, dass jemand daran dachte. Jetzt muss jede Datei
// im Ordner in der Liste stehen, und jede außer dem Impressum in der Sitemap.
console.log("\nAufbau");
{
  const imOrdner = readdirSync(dir).filter(d => d.endsWith(".html")).sort();
  const fehlend = imOrdner.filter(d => !seiten.includes(d));
  note(fehlend.length === 0,
       fehlend.length === 0 ? `Alle ${imOrdner.length} Seiten stehen in der Prüfliste`
                            : `Nicht in der Prüfliste: ${fehlend.join(", ")}`);
  const xml = readFileSync(`${dir}/sitemap.xml`, "utf8");
  const angemeldet = [...xml.matchAll(/<loc>https:\/\/[^/]+\/([^<]*)<\/loc>/g)]
    .map(m => m[1] || "index.html");
  const soll = imOrdner.filter(d => !ohneIndex(d));
  const nichtAngemeldet = soll.filter(d => !angemeldet.includes(d));
  const zuviel = angemeldet.filter(d => !imOrdner.includes(d));
  note(nichtAngemeldet.length === 0 && zuviel.length === 0,
       nichtAngemeldet.length || zuviel.length
         ? `Sitemap: fehlt ${nichtAngemeldet.join(", ") || "nichts"}, zu viel ${zuviel.join(", ") || "nichts"}`
         : `Sitemap führt genau die ${soll.length} Seiten, die in den Index sollen`);
}

// **Strukturierte Daten müssen gültig sein und dasselbe sagen wie die Seite.**
// Ein Komma zu viel im JSON, und Google verwirft den ganzen Block, ohne dass es
// jemand merkt. Und ein Pfad im Markup, der nicht sichtbar auf der Seite
// steht, gilt bei Google als irreführend.
const artikel = [];
for (const datei of seiten) {
  const html = readFileSync(`${dir}/${datei}`, "utf8");
  const bloecke = [...html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)];
  for (const [, roh] of bloecke) {
    let daten = null;
    try { daten = JSON.parse(roh); } catch (e) { note(false, `${datei}: strukturierte Daten sind kein gültiges JSON (${e.message})`); continue; }
    note(true, `${datei}: strukturierte Daten sind gültiges JSON`);
    const knoten = daten["@graph"] || [daten];
    if (knoten.some(k => k["@type"] === "Article")) artikel.push(datei);
    const pfad = knoten.find(k => k["@type"] === "BreadcrumbList");
    if (pfad) {
      const imMarkup = pfad.itemListElement.map(e => e.name);
      const sichtbar = [...html.matchAll(/<nav class="pfad"[\s\S]*?<\/nav>/g)]
        .flatMap(m => [...m[0].matchAll(/<li[^>]*>([\s\S]*?)<\/li>/g)])
        .map(m => m[1].replace(/<[^>]+>/g, "").trim());
      note(JSON.stringify(imMarkup) === JSON.stringify(sichtbar),
           `${datei}: Pfad sichtbar wie im Markup (${sichtbar.join(" › ") || "keiner sichtbar"})`);
    }
  }
}

// **Jeder Artikel ist erreichbar: von der Startseite und aus dem Ratgeber.**
// Google findet eine Seite über Verweise. Eine Seite, auf die nichts zeigt,
// steht in der Sitemap und sonst nirgends.
{
  const start = readFileSync(`${dir}/index.html`, "utf8");
  const ratgeber = readFileSync(`${dir}/ratgeber.html`, "utf8");
  for (const datei of artikel) {
    note(start.includes(`href="${datei}"`), `${datei}: von der Startseite verlinkt`);
    note(ratgeber.includes(`href="${datei}"`), `${datei}: aus dem Ratgeber verlinkt`);
  }
}

// **Dieselbe Kopfleiste auf jeder Seite.** Bis 0.116.8 hatte die Startseite
// fünf Einträge und die Unterseiten drei, ohne Ratgeber und ohne Entwicklung.
// Wer über Google auf einer Unterseite ankam, fand den Rest der Website nicht.
{
  const leiste = d => {
    const m = readFileSync(`${dir}/${d}`, "utf8").match(/<nav aria-label="Bereiche">([\s\S]*?)<\/nav>/);
    return m ? [...m[1].matchAll(/>([^<]+)<\/a>/g)].map(x => x[1].trim()) : [];
  };
  const vorbild = leiste("index.html");
  for (const datei of seiten) {
    const hier = leiste(datei);
    note(JSON.stringify(hier) === JSON.stringify(vorbild),
         `${datei}: Kopfleiste wie auf der Startseite (${hier.join(", ")})`);
    const html = readFileSync(`${dir}/${datei}`, "utf8");
    if (html.includes(`<nav aria-label="Bereiche">`) && new RegExp(`href="${datei}"`).test(html.match(/<nav aria-label="Bereiche">[\s\S]*?<\/nav>/)[0])) {
      note(new RegExp(`href="${datei}" aria-current="page"`).test(html),
           `${datei}: die Kopfleiste zeigt, wo man ist`);
    }
  }
}

// **Der alte Name kommt nirgends vor, auch nicht in einer Bildbeschreibung.**
// Seit dem 28. August heißt die App Zählora. Im Repository heißt noch vieles
// PulseMeter, und das ist Absicht; auf der Website hat es nichts zu suchen.
for (const datei of seiten) {
  const html = readFileSync(`${dir}/${datei}`, "utf8").replace(/<!--[\s\S]*?-->/g, " ");
  note(!/PulseMeter/i.test(html), `${datei}: kein „PulseMeter"`);
}


// --- Suchmaschinen: was Google braucht, um die Seite ordentlich zu führen
//
// **Gemessen an der ausgelieferten Seite am 25. September:** Jede unbekannte
// Adresse lieferte die Startseite mit Status 200, `/favicon.ico` ebenfalls, und
// das Symbol stand nur eingebettet in der Seite. Für Google heißt das: beliebig
// viele Kopien der Startseite und kein Symbol in der Trefferliste. Keine der
// Prüfungen oben hatte danach gefragt.
console.log("\nSuchmaschinen");
{
  const indexierbar = seiten.filter(d => !ohneIndex(d));
  const kopf = d => readFileSync(`${dir}/${d}`, "utf8");
  const titel = d => (kopf(d).match(/<title>([^<]+)<\/title>/) || [])[1];
  const beschr = d => (kopf(d).match(/<meta name="description" content="([^"]+)"/) || [])[1];
  const doppelt = xs => xs.filter((x, i) => x && xs.indexOf(x) !== i);
  note(doppelt(indexierbar.map(titel)).length === 0, "Jeder Titel kommt nur einmal vor");
  note(doppelt(indexierbar.map(beschr)).length === 0, "Jede Beschreibung kommt nur einmal vor");

  for (const d of seiten) {
    const html = kopf(d);
    if (ohneIndex(d)) {
      note(!/<[^>]+max-image-preview/.test(html), `${d}: noindex und sonst keine Robots-Angabe`);
    } else {
      note(/<meta name="robots" content="max-image-preview:large">/.test(html),
           `${d}: große Bildvorschau in den Suchergebnissen erlaubt`);
      const eigene = d === "index.html" ? "" : d;
      note(new RegExp(`rel="canonical" href="https://[^/"]+/${eigene.replace(".", "\\.")}"`).test(html),
           `${d}: kanonische Adresse ist die eigene`);
    }
    // Das Symbol als Datei, nicht eingebettet: Google holt es sich über die
    // Adresse und zeigt es neben dem Treffer.
    note(/<link rel="icon" href="\/favicon\.ico" sizes="48x48">/.test(html) && !/rel="icon" href="data:/.test(html),
         `${d}: Symbol als Datei verlinkt`);
    const og = (html.match(/<meta property="og:image" content="https:\/\/[^/]+\/([^"]+)"/) || [])[1];
    if (og) note(existsSync(`${dir}/${og}`), `${d}: Vorschaubild ${og} liegt vor`);
  }

  // Die Symbole selbst: vorhanden, im richtigen Format, in der richtigen Größe.
  const png = f => { const b = readFileSync(`${dir}/${f}`); return b.readUInt32BE(0) === 0x89504e47 ? [b.readUInt32BE(16), b.readUInt32BE(20)] : null; };
  const ico = readFileSync(`${dir}/favicon.ico`);
  note(ico.readUInt16LE(2) === 1 && ico[6] === 48 && ico[7] === 48, "favicon.ico ist eine ICO-Datei mit 48 × 48");
  note(JSON.stringify(png("apple-touch-icon.png")) === "[180,180]", "apple-touch-icon.png hat 180 × 180");
  note(JSON.stringify(png("icon-512.png")) === "[512,512]", "icon-512.png hat 512 × 512 (Logo in den strukturierten Daten)");
  note(existsSync(`${dir}/favicon.svg`) && /<svg/.test(readFileSync(`${dir}/favicon.svg`, "utf8")), "favicon.svg liegt vor");

  // Das Vorschaubild zum Teilen hat die Maße, die in der Seite stehen.
  {
    const b = readFileSync(`${dir}/bilder/teilen.jpg`);
    let i = 2, masse = null;
    while (i < b.length) {
      const marke = b[i + 1], laenge = b.readUInt16BE(i + 2);
      if (marke >= 0xc0 && marke <= 0xc3) { masse = [b.readUInt16BE(i + 7), b.readUInt16BE(i + 5)]; break; }
      i += 2 + laenge;
    }
    const start = kopf("index.html");
    const w = +(start.match(/og:image:width" content="(\d+)"/) || [])[1];
    const h = +(start.match(/og:image:height" content="(\d+)"/) || [])[1];
    note(masse && masse[0] === w && masse[1] === h && w === 1200 && h === 630,
         `Vorschaubild zum Teilen: ${masse ? masse.join(" × ") : "?"}, angegeben ${w} × ${h}`);
  }

  // Die Seite für unbekannte Adressen antwortet unter jeder Adresse, auch
  // unter `/ratgeber/xyz`. Ein relativer Verweis auf das Stylesheet ginge dort
  // ins Leere.
  {
    const html = kopf("404.html");
    note(ohneIndex("404.html") && !/rel="canonical"/.test(html), "404.html: noindex, keine kanonische Adresse");
    const relativ = [...html.matchAll(/<link[^>]+href="([^"]+)"/g)].map(m => m[1]).filter(h => !h.startsWith("/") && !h.startsWith("http"));
    note(relativ.length === 0, `404.html: Stil und Symbole mit absolutem Pfad${relativ.length ? " (relativ: " + relativ.join(", ") + ")" : ""}`);
  }

  // Jede Adresse in der Sitemap sagt, wann sie sich zuletzt geändert hat.
  {
    const xml = readFileSync(`${dir}/sitemap.xml`, "utf8");
    const eintraege = xml.match(/<url>[\s\S]*?<\/url>/g) || [];
    note(eintraege.length > 0 && eintraege.every(e => /<lastmod>\d{4}-\d{2}-\d{2}<\/lastmod>/.test(e)),
         "Sitemap: jede Adresse mit Datum");
  }

  // Die Startseite beschreibt sich als Website, Herausgeber und App.
  {
    const roh = (kopf("index.html").match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/) || [])[1];
    const g = roh ? (JSON.parse(roh)["@graph"] || []) : [];
    const typ = t => g.find(k => k["@type"] === t);
    note(!!typ("WebSite") && !!typ("Organization") && !!typ("SoftwareApplication"),
         "Startseite: strukturierte Daten für Website, Herausgeber und App");
    const app = typ("SoftwareApplication") || {};
    note(/apps\.apple\.com\/de\/app\/id\d+/.test(app.installUrl || ""), "Startseite: die App verweist auf ihren Eintrag im App Store");
    note(!app.aggregateRating, "Startseite: keine Sternebewertung im Markup, solange es keine zehn echten gibt");
  }

  // Bilder: Das erste lädt sofort und zuerst, alles unterhalb des ersten
  // Bildschirms erst, wenn man hinscrollt.
  {
    const bilder = [...kopf("index.html").matchAll(/<img[^>]*>/g)].map(m => m[0]);
    note(/fetchpriority="high"/.test(bilder[0]) && !/loading="lazy"/.test(bilder[0]),
         "Startseite: das erste Bild lädt zuerst und nicht verzögert");
    const unten = bilder.slice(3);
    note(unten.length > 0 && unten.every(b => /loading="lazy"/.test(b)),
         `Startseite: ${unten.length} Bilder unterhalb des ersten Bildschirms laden erst beim Scrollen`);
  }

  // IndexNow: Der Schlüssel liegt als Datei vor, und die Datei enthält ihn.
  {
    const dateien = readdirSync(dir).filter(d => /^[0-9a-f]{32}\.txt$/.test(d));
    note(dateien.length === 1 && readFileSync(`${dir}/${dateien[0]}`, "utf8").trim() === dateien[0].slice(0, 32),
         "IndexNow: genau ein Schlüssel, und die Datei enthält ihn");
  }
}

// --- Auslieferung: was wirklich ins Netz geht
//
// `website-fertig.sh` lief bis 0.117.0 nur beim Veröffentlichen. Was es
// umschreibt, hat keine Prüfung je gesehen; ein Verweis `index.html#preise`
// blieb deshalb unbemerkt relativ. Jetzt läuft es hier mit, in einen
// Wegwerfordner, und das Ergebnis wird angesehen.
if (dir === "docs/website") {
  console.log("\nAuslieferung");
  const aus = "build/website-pruefung";
  execFileSync("scripts/website-fertig.sh", [aus], { stdio: "pipe" });
  const html = readdirSync(aus).filter(d => d.endsWith(".html"));
  const relativ = html.flatMap(d => [...readFileSync(`${aus}/${d}`, "utf8").matchAll(/href="([a-z0-9-]+\.html[^"]*)"/g)].map(m => `${d}: ${m[1]}`));
  note(relativ.length === 0, relativ.length ? `Relativer Seitenverweis nach dem Umschreiben: ${relativ[0]}` : "Alle Seitenverweise sind absolut, auch die mit Sprungmarke");
  const headers = readFileSync(`${aus}/_headers`, "utf8");
  note(/\/bilder\/\*\s*\n\s*Cache-Control: public, max-age=604800/.test(headers), "Bilder dürfen eine Woche im Browser bleiben");
  note(/X-Content-Type-Options: nosniff/.test(headers), "Sicherheitsangaben stehen weiter drin");
  note(existsSync(`${aus}/404.html`) && existsSync(`${aus}/favicon.ico`), "404-Seite und Symbol werden mit ausgeliefert");
  note(readdirSync(aus).every(d => !d.endsWith(".md")), "Keine Markdown-Datei im Auslieferordner");
  const sm = readFileSync(`${aus}/sitemap.xml`, "utf8");
  note(!/\.html</.test(sm), "Die ausgelieferte Sitemap nennt die Adressen ohne .html");
}


// --- Ältere Geräte: was Safari vor iOS 17 nicht kann
//
// Ein iPhone 7 oder 8 bleibt bei iOS 15 oder 16 stehen, und sein Safari
// kennt manches nicht, was hier benutzt wird. Gemessen am 26. September:
// `color-mix()` erst ab iOS 16.2, und die Kopfleiste war ohne Rückfall
// durchsichtig. `hyphens` nur mit Präfix vor iOS 17. `inset` erst ab 14.5.
console.log("\nÄltere Geräte");
{
  const css = readFileSync(`${dir}/stil.css`, "utf8").replace(/\/\*[\s\S]*?\*\//g, " ");
  const bloecke = [...css.matchAll(/([^{}]+)\{([^{}]*)\}/g)];
  const ohne = [];
  for (const [, wahl, inhalt] of bloecke) {
    const zeilen = inhalt.split(";").map(z => z.trim()).filter(Boolean);
    zeilen.forEach((z, i) => {
      const [eig] = z.split(":");
      if (!/color-mix\(/.test(z) || !/^(background|background-color|border-color|color)$/.test(eig.trim())) return;
      const vorher = zeilen.slice(0, i).some(v => v.split(":")[0].trim() === eig.trim() && !/color-mix\(/.test(v));
      if (!vorher) ohne.push(`${wahl.trim()} { ${eig.trim()} }`);
    });
  }
  note(ohne.length === 0, ohne.length ? `color-mix() ohne Rückfall: ${ohne.join("; ")}` : "Jede Farbe aus color-mix() hat einen Rückfall für Safari vor iOS 16.2");
  note(!/(^|[^-])hyphens:/m.test(css.replace(/-webkit-hyphens:[^;]*;\s*hyphens:/g, "")),
       "hyphens steht nie ohne -webkit-hyphens davor");
  note(!/\binset:/.test(css), "kein inset (Safari erst ab iOS 14.5)");
  note(!/(^|[^-])backdrop-filter:/m.test(css.replace(/backdrop-filter:[^;]*;\s*-webkit-backdrop-filter:/g, "")),
       "backdrop-filter nie ohne -webkit-backdrop-filter");
}

// --- Mit Browser

// **WebKit, die Engine von Safari, auf Zuruf.** Jedes iPhone und jedes iPad
// zeigt die Website mit WebKit, egal welcher Browser drübersteht. Chromium
// allein prüft also nicht, was die Zielgruppe sieht. `PULSE_ENGINE=webkit`
// nimmt WebKit; die CI tut das in einem eigenen Schritt.
const ENGINE = process.env.PULSE_ENGINE === "webkit" ? "webkit" : "chromium";
console.log(`\nEngine: ${ENGINE}`);
const browser = ENGINE === "webkit"
  ? await webkit.launch()
  : await chromium.launch({ executablePath: process.env.PULSE_CHROMIUM || undefined });

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
    page.on("request", r => { if (!r.url().startsWith(base)) fremd.push(r.url()); });

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


// --- Verhalten: Was die neuen Teile können müssen
//
// Die Prüfungen oben sehen, ob eine Seite da ist und nicht überläuft. Ob der
// Rechner richtig rechnet, sehen sie nicht. Beim ersten Nachrechnen von Hand
// kam „1.267 m³" als 14 kWh heraus; das hätte keine Prüfung gemerkt.
console.log("\nVerhalten");
{
  const page = await browser.newPage({ viewport: { width: 390, height: 900 } });
  const fehler = [];
  page.on("pageerror", e => fehler.push(e.message));
  const text = async sel => (await page.textContent(sel)).replace(/\s+/g, " ").trim();

  // **Ergebnisse stehen als Kacheln: Name, Zahl, Bezug.** Gelesen wird über
  // die Kennung der Kachel, nicht über den Wortlaut, damit eine bessere
  // Beschriftung die Prüfung nicht bricht.
  const kachel = async k => {
    const e = await page.$(`[data-kachel="${k}"]`);
    if (!e) return { name: "", wert: "", zusatz: "" };
    // Beträge stehen mit geschütztem Leerzeichen vor dem €; verglichen wird
    // mit einem gewöhnlichen.
    return e.evaluate(el => {
      const t = s => ((el.querySelector(s) || {}).textContent || "").replace(/\u00a0/g, " ");
      return { name: t(".kachel-name"), wert: t(".kachel-wert"), zusatz: t(".kachel-zusatz") };
    });
  };
  const kaputt = async sel => /NaN|Infinity|undefined/.test(await text(sel));

  // Gas: dieselbe Rechnung wie GasConversion.energy in PulseCore.
  await page.goto(base + "gas-in-kwh.html");
  note((await kachel("kwh")).wert === "2.702 kWh", `Gasrechner: 250 m³ × 0,9650 × 11,2 = 2.702 kWh (${(await kachel("kwh")).wert})`);
  note((await kachel("kosten")).wert === "324,24 €", `Gasrechner: 2.702 kWh zu 12 ct = 324,24 €`);
  note((await kachel("faust")).wert === "2.500 kWh" && /202 kWh zu wenig/.test((await kachel("faust")).zusatz),
       `Gasrechner: „mal zehn“ ergibt 2.500 kWh, 202 kWh zu wenig`);
  await page.fill("#g-m3", "1.267"); await page.fill("#g-z", "0,9523"); await page.fill("#g-b", "11,4");
  note((await kachel("kwh")).wert === "13.755 kWh", `Gasrechner: „1.267" ist eintausendzweihundertsiebenundsechzig (${(await kachel("kwh")).wert})`);
  await page.fill("#g-m3", "1267,5");
  note((await kachel("kwh")).wert === "13.760 kWh", `Gasrechner: Komma als Dezimalzeichen`);
  await page.fill("#g-z", "");
  note(!(await kaputt("#gas-ergebnis")) && (await text("#gas-ergebnis")).includes("Trag"),
       `Gasrechner: ein leeres Feld ergibt einen Hinweis, keine kaputte Zahl`);
  await page.fill("#g-z", "abc");
  note(!(await kaputt("#gas-ergebnis")), `Gasrechner: Buchstaben ergeben keine kaputte Zahl`);

  // Abschlag: Verbrauch × Arbeitspreis + Grundpreis, auf zwölf Monate.
  await page.goto(base + "abschlag-zu-hoch.html");
  note((await kachel("passend")).wert === "91,00 €" && (await kachel("passend")).zusatz === "im Monat",
       `Abschlagsrechner: 2.800 kWh, 34 ct, 140 € im Jahr = 91,00 € im Monat`);
  note((await kachel("kosten")).wert === "1.092,00 €", `Abschlagsrechner: Kosten im Jahr 1.092,00 €`);
  const zuviel = await kachel("differenz");
  note(zuviel.name === "Zu viel im Jahr" && zuviel.wert === "468,00 €",
       `Abschlagsrechner: 130 € statt 91 € sind 468 € im Jahr zu viel („${zuviel.name}: ${zuviel.wert}")`);
  await page.selectOption("#a-gpart", "monat"); await page.fill("#a-gp", "11,50"); await page.fill("#a-ab", "80");
  const fehlt = await kachel("differenz");
  note((await kachel("passend")).wert === "90,83 €" && fehlt.name === "Fehlt im Jahr" && fehlt.wert === "130,00 €",
       `Abschlagsrechner: Grundpreis im Monat, zu wenig gezahlt („${fehlt.name}: ${fehlt.wert}")`);
  await page.fill("#a-kwh", "");
  note(!(await kaputt("#a-ergebnis")), `Abschlagsrechner: ein leeres Feld ergibt keine kaputte Zahl`);

  // **Verbrauch aus zwei Ständen.** 12.480 am 1. August, 12.731 am
  // 1. September: 251 kWh in 31 Tagen, 8,1 am Tag, aufs Jahr gerechnet
  // 2.955. Monat und Jahr sind hochgerechnet und tragen deshalb ein ≈.
  await page.goto(base + "verbrauch-berechnen.html");
  const menge = await kachel("menge");
  note(menge.wert === "251 kWh" && menge.zusatz === "in 31 Tagen", `Verbrauchsrechner: 251 kWh in 31 Tagen (${menge.wert}, ${menge.zusatz})`);
  note((await kachel("tag")).wert === "8,1 kWh", `Verbrauchsrechner: 8,1 kWh am Tag`);
  note((await kachel("monat")).wert === "≈ 246 kWh", `Verbrauchsrechner: ≈ 246 kWh im Monat (${(await kachel("monat")).wert})`);
  note((await kachel("jahr")).wert === "≈ 2.955 kWh", `Verbrauchsrechner: ≈ 2.955 kWh im Jahr (${(await kachel("jahr")).wert})`);
  note(!/≈/.test(menge.wert) && !/≈/.test((await kachel("tag")).wert),
       "Verbrauchsrechner: Gemessenes ohne ≈, Hochgerechnetes mit");
  await page.selectOption("#v-einheit", "m³");
  await page.fill("#v-alt", "412,5"); await page.fill("#v-neu", "418,7");
  note((await kachel("menge")).wert === "6,2 m³" && (await kachel("tag")).wert === "0,20 m³",
       `Verbrauchsrechner: Wasser in m³ mit Kommastellen (${(await kachel("menge")).wert}, ${(await kachel("tag")).wert} am Tag)`);
  await page.fill("#v-neu", "400");
  note((await text("#v-ergebnis")).includes("kleiner") && !(await kaputt("#v-ergebnis")),
       "Verbrauchsrechner: ein kleinerer neuer Stand ergibt einen Hinweis statt eines negativen Verbrauchs");
  await page.fill("#v-neu", "418,7"); await page.fill("#v-neu-tag", "2026-07-01");
  note((await text("#v-ergebnis")).includes("Datum"), "Verbrauchsrechner: ein Datum vor dem früheren ergibt einen Hinweis");
  await page.fill("#v-neu-tag", "2026-09-01"); await page.selectOption("#v-einheit", "m³ Gas");
  note(await page.$('#v-ergebnis a[href="gas-in-kwh.html"]') !== null, "Verbrauchsrechner: bei Gas der Verweis aufs Umrechnen");

  // **Auf einen Blick.** Vom Gründer am 26. September: nicht zu viel Text,
  // klare Benennungen. Gezählt wird, was sonst schleichend wieder wächst:
  // der Hinweis unter einem Feld, der Text im Ergebnis, und wo der Rechner
  // steht.
  for (const datei of ["gas-in-kwh.html", "abschlag-zu-hoch.html", "verbrauch-berechnen.html"]) {
    await page.goto(base + datei);
    const blick = await page.evaluate(() => {
      const erg = document.querySelector(".rechner-ergebnis");
      const kacheln = [...erg.querySelectorAll(".kachel")];
      const lose = [...erg.childNodes].filter(n => !(n.nodeType === 1 && n.classList.contains("kacheln")))
        .map(n => n.textContent).join(" ").trim();
      const hinweise = [...document.querySelectorAll(".rechner small")].map(s => s.textContent.trim().split(/\s+/).length);
      const vorDemRechner = (() => {
        let n = 0, e = document.querySelector("h1").nextElementSibling;
        while (e && !e.matches("form.rechner")) { if (e.matches("h2")) n++; e = e.nextElementSibling; }
        return n;
      })();
      return {
        kacheln: kacheln.length,
        benannt: kacheln.every(k => k.querySelector(".kachel-name")?.textContent.trim() && k.querySelector(".kachel-wert")?.textContent.trim()),
        worte: lose ? lose.split(/\s+/).length : 0,
        hinweisMax: Math.max(0, ...hinweise),
        vorDemRechner,
      };
    });
    note(blick.kacheln >= 2 && blick.benannt, `${datei}: Ergebnis in ${blick.kacheln} Kacheln, jede mit Name und Zahl`);
    note(blick.worte <= 15, `${datei}: neben den Kacheln höchstens 15 Wörter (${blick.worte})`);
    note(blick.hinweisMax <= 5, `${datei}: jeder Hinweis unter einem Feld höchstens fünf Wörter (längster: ${blick.hinweisMax})`);
    note(blick.vorDemRechner === 0, `${datei}: der Rechner steht direkt unter der Überschrift`);
  }

  // **Felder einer Reihe stehen auf einer Höhe.** Ein zweizeiliger Hinweis
  // neben einem einzeiligen hat die Felder um acht Punkte versetzt; gesehen
  // habe ich es erst auf dem Bildschirmfoto.
  await page.setViewportSize({ width: 1280, height: 900 });
  for (const datei of ["gas-in-kwh.html", "abschlag-zu-hoch.html", "verbrauch-berechnen.html"]) {
    await page.goto(base + datei);
    const versatz = await page.evaluate(() => {
      const reihen = {};
      for (const l of document.querySelectorAll(".rechner label")) {
        const top = Math.round(l.getBoundingClientRect().top);
        const feld = l.querySelector("input, select").getBoundingClientRect().top;
        (reihen[top] ||= []).push(feld);
      }
      return Math.max(0, ...Object.values(reihen).map(r => Math.max(...r) - Math.min(...r)));
    });
    note(versatz <= 1, `${datei}: Felder einer Reihe stehen auf einer Höhe (Versatz ${Math.round(versatz)} px)`);
  }

  // **Groß genug für einen Daumen.** Wer mit der Rechnung in der einen Hand
  // tippt, trifft ein kleines Feld nicht.
  await page.setViewportSize({ width: 390, height: 900 });
  for (const datei of ["gas-in-kwh.html", "abschlag-zu-hoch.html", "verbrauch-berechnen.html", "zaehlerstand-umzug.html"]) {
    await page.goto(base + datei);
    const klein = await page.evaluate(() =>
      [...document.querySelectorAll(".rechner input, .rechner select, main button")]
        .filter(e => e.getBoundingClientRect().height < 44).map(e => e.id || e.textContent.trim()));
    note(klein.length === 0, `${datei}: jedes Feld und jeder Knopf mindestens 44 Punkte hoch${klein.length ? " (zu klein: " + klein.join(", ") + ")" : ""}`);
  }

  // **Gedruckt wird nur das Protokoll.** Kopf, Fuß, Pfad und Erklärtext
  // gehören nicht aufs Blatt, das jemand am Übergabetag unterschreibt.
  await page.goto(base + "zaehlerstand-umzug.html");
  await page.emulateMedia({ media: "print" });
  const druck = await page.evaluate(() => {
    const zu = s => [...document.querySelectorAll(s)].every(e => getComputedStyle(e).display === "none");
    const tabellen = [...document.querySelectorAll("#protokoll table")];
    return {
      versteckt: zu(".kopf") && zu(".fuss") && zu(".nicht-drucken") && zu(".pfad"),
      sichtbar: getComputedStyle(document.querySelector("#protokoll")).display !== "none",
      zeilen: document.querySelectorAll("#protokoll tbody tr").length,
      unterschriften: document.querySelectorAll(".unterschriften div").length,
      tabellen: tabellen.length,
    };
  });
  await page.emulateMedia({ media: "screen" });
  note(druck.versteckt, "Protokoll: Kopf, Fuß, Pfad und Erklärtext werden nicht gedruckt");
  note(druck.sichtbar && druck.tabellen === 2 && druck.zeilen >= 10 && druck.unterschriften === 3,
       `Protokoll: zwei Tabellen, ${druck.zeilen} Zeilen, ${druck.unterschriften} Unterschriften auf dem Blatt`);

  // **Das Bild füllt den Telefonrahmen.** Bis 0.116.8 blieb rechts in jedem
  // Rahmen ein weißer Streifen, weil das Bild 460 Punkte breit war und der
  // Rahmen breiter.
  for (const breite of [390, 1280]) {
    await page.setViewportSize({ width: breite, height: 900 });
    await page.goto(base + "index.html");
    const luecke = await page.evaluate(() =>
      Math.max(0, ...[...document.querySelectorAll(".geraet")]
        .filter(g => g.offsetParent !== null)
        .map(g => g.clientWidth - g.querySelector("img").getBoundingClientRect().width)));
    note(luecke <= 1, `Startseite ${breite} px: jedes Bild füllt seinen Telefonrahmen (Lücke ${Math.round(luecke)} px)`);
    // Ein Telefon neben einem Text bleibt telefongroß.
    const hoehe = await page.evaluate(() =>
      Math.max(0, ...[...document.querySelectorAll(".paar > .geraet")].map(g => g.getBoundingClientRect().height)));
    note(hoehe <= 800, `Startseite ${breite} px: kein Telefonbild höher als 800 px (${Math.round(hoehe)} px)`);
  }

  // **Text unter einem Kartenraster klebt nicht daran.** Unter „Deine Daten"
  // stand der Absatz direkt an der letzten Kartenreihe, null Punkte Abstand.
  for (const datei of ["index.html", "ratgeber.html"]) {
    await page.goto(base + datei);
    const knapp = await page.evaluate(() =>
      [...document.querySelectorAll(".karten + *")]
        .map(e => e.getBoundingClientRect().top - e.previousElementSibling.getBoundingClientRect().bottom)
        .filter(a => a < 24).length);
    note(knapp === 0, `${datei}: unter jedem Kartenraster mindestens 24 px Luft`);
  }

  // **Die Botschaft steht oben, nicht irgendwo.** Vom Gründer am
  // 26. September: Verbrauch sichtbar machen, nicht nur Abschlag und Kosten,
  // und stärker herausstellen, dass wir keine Zählerstände haben. Geprüft
  // wird die Reihenfolge, weil sie beim nächsten Umbau am leichtesten
  // verrutscht.
  await page.goto(base + "index.html");
  const oben = await page.evaluate(() => ({
    abschnitte: [...document.querySelectorAll("main > section")].map(x => x.id || ""),
    zusage: (document.querySelector(".zusagen li") || {}).textContent || "",
    daten: (document.querySelector("#daten h2") || {}).textContent || "",
    dunkel: document.querySelector("#daten")?.classList.contains("abschnitt-dunkel"),
  }));
  note(oben.abschnitte[0] === "funktionen" && oben.abschnitte[1] === "daten",
       `Startseite: erst Verbrauch, dann Datenschutz (${oben.abschnitte.slice(0, 3).join(", ")})`);
  note(/Zählerstände/.test(oben.zusage) && /nie|nicht/.test(oben.zusage),
       `Startseite: die erste Zusage ganz oben sagt, dass wir die Zählerstände nicht sehen („${oben.zusage}")`);
  note(/haben wir nicht|sehen wir nie/.test(oben.daten) && oben.dunkel,
       `Startseite: der Datenschutz-Abschnitt ist als einziger dunkel („${oben.daten}")`);

  // **Eine Karte, die woanders hinführt, ist als Ganzes anklickbar.**
  await page.goto(base + "ratgeber.html");
  const karten = await page.evaluate(() => [...document.querySelectorAll("main .karte")].map(k => k.tagName));
  note(karten.length >= 4 && karten.every(t => t === "A"),
       `Ratgeber: ${karten.length} Karten, jede als Ganzes ein Verweis`);

  note(fehler.length === 0, fehler.length ? `JavaScript-Fehler beim Rechnen: ${fehler[0]}` : "Keine JavaScript-Fehler beim Rechnen und Drucken");
  await page.close();
}


// --- Geräte: vom iPhone SE der ersten Generation bis zum iPad Pro quer
//
// Bis 0.117.1 prüfte die Seite drei Breiten. Die Kopfleiste stand aber
// nur auf den schmalen iPhones 124 Punkte hoch, und die Ziele im Fuß waren
// nur mit Fingerbedienung zu klein. Beides sieht man erst, wenn das Gerät
// stimmt: Größe, Pixeldichte, Fingerbedienung.
console.log("\nGeräte");
{
  const GERAETE = [
    ["iPhone SE (1. Gen.)", 320, 568, true], ["iPhone SE (2./3. Gen.), 8", 375, 667, true],
    ["iPhone 11, XR", 414, 896, true], ["iPhone 15 Pro Max", 430, 932, true],
    ["iPhone SE quer", 667, 375, true], ["iPad mini", 744, 1133, true],
    ["iPad 10,2 Zoll", 810, 1080, true], ["iPad Pro 12,9 Zoll", 1024, 1366, true],
    ["iPad Pro 12,9 Zoll quer", 1366, 1024, true], ["Desktop", 1920, 1080, false],
  ];
  for (const [name, w, h, finger] of GERAETE) {
    const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 2, isMobile: finger && w < 1024, hasTouch: finger });
    const fehler = [];
    for (const datei of seiten) {
      await page.goto(base + datei);
      const r = await page.evaluate(({ finger }) => {
        const sichtbar = e => e.offsetParent !== null && e.getBoundingClientRect().height > 0;
        const kopf = document.querySelector(".kopf");
        const klebt = kopf && getComputedStyle(kopf).position === "sticky";
        return {
          ueber: document.documentElement.scrollWidth - document.documentElement.clientWidth,
          klein: [...document.querySelectorAll("p, li, a, span, small, label, td, th, b, h3")]
            .filter(e => sichtbar(e) && e.textContent.trim() && parseFloat(getComputedStyle(e).fontSize) < 12)
            .map(e => e.textContent.trim().slice(0, 20)),
          ziele: finger ? [...document.querySelectorAll(".kopf nav a, .fuss nav a, .pfad a, a[href^='mailto:'], button, input, select")]
            .filter(e => sichtbar(e) && e.getBoundingClientRect().height < 44)
            .map(e => `${(e.textContent.trim() || e.tagName).slice(0, 18)} ${Math.round(e.getBoundingClientRect().height)}`) : [],
          kopfAnteil: klebt ? kopf.getBoundingClientRect().height / innerHeight : 0,
          // Die Einträge im Pfad stehen auf einer Linie, wenn sie in eine
          // Zeile passen. Gemessen wird die Mitte, nicht die Oberkante.
          pfadVersatz: (() => {
            const li = [...document.querySelectorAll(".pfad li")];
            if (li.length < 2) return 0;
            const mitte = e => { const r = e.getBoundingClientRect(); return (r.top + r.bottom) / 2; };
            const zeilen = {};
            for (const e of li) { const k = Math.round(e.getBoundingClientRect().top / 30); (zeilen[k] ||= []).push(mitte(e)); }
            return Math.max(0, ...Object.values(zeilen).filter(z => z.length > 1).map(z => Math.max(...z) - Math.min(...z)));
          })(),
        };
      }, { finger });
      if (r.ueber > 1) fehler.push(`${datei}: ${r.ueber} px Überlauf`);
      if (r.klein.length) fehler.push(`${datei}: Schrift unter 12 px („${r.klein[0]}")`);
      if (r.ziele.length) fehler.push(`${datei}: Ziel unter 44 px (${r.ziele[0]})`);
      if (r.kopfAnteil > 0.18) fehler.push(`${datei}: stehende Kopfleiste nimmt ${Math.round(r.kopfAnteil * 100)} % der Höhe`);
      if (r.pfadVersatz > 2) fehler.push(`${datei}: Pfad steht versetzt (${Math.round(r.pfadVersatz)} px)`);
    }
    note(fehler.length === 0, `${name} (${w} × ${h}): ${fehler.length ? fehler.slice(0, 2).join("; ") : "alle Seiten ohne Überlauf, lesbar, mit Zielen für den Finger"}`);
    await page.close();
  }

  // **Ein altes Safari, nachgestellt.** Das Stylesheet wird ohne color-mix()
  // ausgeliefert, so wie ein Safari vor iOS 16.2 es liest: Die Angabe fällt
  // weg, und es gilt, was davor steht. Dann muss die Kopfleiste trotzdem
  // deckend sein und die hervorgehobene Kachel trotzdem hervorgehoben.
  const alt = await browser.newPage({ viewport: { width: 375, height: 667 }, isMobile: true, hasTouch: true });
  await alt.route("**/stil.css", async route => {
    // Erst die Kommentare weg: Einer davon erklärt color-mix(), und der
    // Ausdruck darunter hätte von dort bis zur Rückfall-Zeile gegriffen und
    // genau die mit entfernt, um die es geht.
    const css = readFileSync(`${dir}/stil.css`, "utf8")
      .replace(/\/\*[\s\S]*?\*\//g, "")
      .replace(/[a-z-]+:[^;{}]*color-mix\([^;{}]*;/g, "");
    await route.fulfill({ status: 200, contentType: "text/css", body: css });
  });
  await alt.goto(base + "abschlag-zu-hoch.html");
  const altBild = await alt.evaluate(() => {
    const k = document.querySelector(".kopf"), h = document.querySelector(".kachel-haupt");
    const hg = getComputedStyle(k).backgroundColor;
    const art = document.querySelector(".art");
    return {
      kopf: hg, deckend: !/rgba\(0, 0, 0, 0\)|transparent/.test(hg),
      kachel: h ? getComputedStyle(h).borderTopColor : "", kachelNormal: h ? getComputedStyle(h.nextElementSibling || h).borderTopColor : "",
      art: art ? getComputedStyle(art).backgroundColor : "rgb(1, 1, 1)",
    };
  });
  note(altBild.deckend, `Altes Safari: Kopfleiste deckend (${altBild.kopf})`);
  note(altBild.kachel && altBild.kachel !== altBild.kachelNormal, `Altes Safari: die Hauptkachel hebt sich ab (${altBild.kachel} gegen ${altBild.kachelNormal})`);
  note(!/rgba\(0, 0, 0, 0\)/.test(altBild.art), `Altes Safari: die Art auf den Karten hat einen Hintergrund (${altBild.art})`);
  await alt.close();
}

await browser.close();
server.close();

console.log(`\n${failures.length === 0 ? "Alles grün" : failures.length + " Prüfung(en) gefallen"}`);
if (failures.length) {
  for (const f of failures) console.log("  · " + f);
  process.exit(1);
}
