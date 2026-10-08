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
                "zaehlerstand-umzug.html", "ratgeber.html",
                "verbrauch-berechnen.html", "stromkosten-berechnen.html", "stromverbrauch-vergleichen.html", "jahresarbeitszahl-berechnen.html", "zaehlerstand-ablesen.html", "photovoltaik-eigenverbrauch.html", "strompreis-entwicklung.html", "datenschutz.html", "impressum.html", "404.html"];

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

// **Der Weg auf `entwicklung.html` zählt sich selbst nach.** Oben steht „6
// Fassungen im App Store", darunter je Fassung ein Eintrag. Kommt eine dazu
// und nur der Eintrag wird gepflegt, stimmt die große Zahl nicht mehr. Und
// was nur geplant ist, trägt kein Datum: Termine stehen öffentlich nie
// (`05-roadmap.md`, „Öffentlich und intern").
{
  const roh = readFileSync(`${dir}/entwicklung.html`, "utf8").replace(/<!--[\s\S]*?-->/g, " ");
  const zahl = Number((roh.match(/data-zahl="fassungen">(\d+)</) || [])[1]);
  const eintraege = (roh.match(/<li class="weg-laden">/g) || []).length;
  note(zahl === eintraege, `entwicklung.html: ${zahl} Fassungen oben, ${eintraege} Einträge im Weg`);
  const geplant = [...roh.matchAll(/<li class="weg-(?:spaeter|danach|naechstes)">([\s\S]*?)<\/li>\s*(?=<li class="weg-)/g)].map(m => m[1]);
  note(geplant.length === 3 && geplant.every(g => !/<time/.test(g)),
       `entwicklung.html: ${geplant.length} geplante Schritte, keiner mit Datum`);
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
  // Ein Ordner je Engine: `pruefen.sh` lässt Chromium und WebKit gleichzeitig
  // laufen, und in einem gemeinsamen Ordner räumte der eine weg, was der
  // andere gerade kopierte („cp: cannot create directory … File exists").
  const aus = `build/website-pruefung-${process.env.PULSE_ENGINE === "webkit" ? "webkit" : "chromium"}`;
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

  // Abschlag, seit 0.120.3 im Stromkostenrechner: Verbrauch × Arbeitspreis
  // + Grundpreis, auf zwölf Monate. Dieselben Zahlen wie vorher auf der
  // eigenen Seite, damit der Umzug nichts an der Rechnung ändert.
  await page.goto(base + "stromkosten-berechnen.html");
  await page.fill("#s-gp", "140"); await page.selectOption("#s-gpart", "jahr"); await page.fill("#s-ab", "130");
  note((await kachel("monat")).wert === "91,00 €" && (await kachel("monat")).name === "Passender Abschlag",
       `Abschlag: 2.800 kWh, 34 ct, 140 € im Jahr = 91,00 € im Monat`);
  note((await kachel("jahr")).wert === "1.092,00 €", `Abschlag: Kosten im Jahr 1.092,00 €`);
  const zuviel = await kachel("differenz");
  note(zuviel.name === "Zu viel im Jahr" && zuviel.wert === "468,00 €",
       `Abschlag: 130 € statt 91 € sind 468 € im Jahr zu viel („${zuviel.name}: ${zuviel.wert}")`);
  await page.selectOption("#s-gpart", "monat"); await page.fill("#s-gp", "11,50"); await page.fill("#s-ab", "80");
  const fehlt = await kachel("differenz");
  note((await kachel("monat")).wert === "90,83 €" && fehlt.name === "Fehlt im Jahr" && fehlt.wert === "130,00 €",
       `Abschlag: Grundpreis im Monat, zu wenig gezahlt („${fehlt.name}: ${fehlt.wert}")`);
  await page.check('input[value="staende"]');
  const geschaetzt = await kachel("differenz");
  note(/^≈ /.test(geschaetzt.wert), `Abschlag aus zwei Ständen beruht auf der Hochrechnung und trägt ein ≈ (${geschaetzt.wert})`);
  await page.check('input[value="jahr"]');
  await page.fill("#s-kwh", "");
  note(!(await kaputt("#s-ergebnis")), `Abschlag: ein leeres Feld ergibt keine kaputte Zahl`);

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

  // **Stromverbrauch im Vergleich**, mit den Grenzen des Stromspiegels 2025.
  // 1.900 kWh, zwei Personen, Wohnung, Warmwasser nicht über Strom: Klasse D
  // (C endet bei 1.700, D bei 2.000). Die Grenzen selbst sind gegen die
  // Tabelle auf derselben Seite geprüft, damit beides nicht auseinanderläuft.
  await page.goto(base + "stromverbrauch-vergleichen.html");
  note((await kachel("klasse")).wert === "D · mittel", `Stromvergleich: 1.900 kWh, 2 Personen, Wohnung = D · mittel (${(await kachel("klasse")).wert})`);
  note((await kachel("naechste")).wert === "200 kWh" && (await kachel("naechste")).name === "Bis Klasse C",
       `Stromvergleich: 200 kWh weniger bis Klasse C (${(await kachel("naechste")).wert})`);
  await page.fill("#sv-kwh", "1700");
  note((await kachel("klasse")).wert === "C · mittel", "Stromvergleich: „bis 1.700“ gehört noch zu C");
  await page.fill("#sv-kwh", "3001");
  note((await kachel("klasse")).wert === "G · sehr hoch", "Stromvergleich: über 3.000 kWh ist G");
  await page.check('input[name="sv-gebaeude"][value="haus"]'); await page.check('input[name="sv-wasser"][value="mit"]');
  await page.check('input[name="sv-personen"][value="5"]'); await page.fill("#sv-kwh", "10000");
  note((await kachel("klasse")).wert === "F · hoch", "Stromvergleich: Haus, Warmwasser über Strom, 5 Personen, 10.000 kWh = F");
  await page.fill("#sv-kwh", "500"); await page.check('input[name="sv-personen"][value="1"]');
  note((await kachel("klasse")).wert === "A · gering" && !(await page.$('[data-kachel="naechste"]')),
       "Stromvergleich: in Klasse A gibt es keine bessere Klasse");
  await page.fill("#sv-kwh", "");
  note(!(await kaputt("#sv-ergebnis")), "Stromvergleich: ein leeres Feld ergibt keine kaputte Zahl");
  const tabelle = await page.evaluate(() => {
    const G = window.STROMSPIEGEL, f = n => n.toLocaleString("de-DE");
    const spalten = [["wohnung", "ohne"], ["wohnung", "mit"], ["haus", "ohne"], ["haus", "mit"]];
    const falsch = [];
    [...document.querySelectorAll("table.werte tbody tr")].forEach((tr, p) => {
      [...tr.querySelectorAll("td")].forEach((td, i) => {
        const g = G[spalten[i][0]][spalten[i][1]][p];
        const soll = f(g[1] + 1) + " bis " + f(g[3]);
        if (td.textContent.trim() !== soll) falsch.push(`${p + 1}/${i}: ${td.textContent.trim()} statt ${soll}`);
      });
    });
    return falsch;
  });
  note(tabelle.length === 0, `Stromvergleich: die Tabelle „mittel“ nennt dieselben Grenzen wie der Rechner${tabelle.length ? " (" + tabelle.join("; ") + ")" : ""}`);

  // **Die Jahresarbeitszahl.** 13.200 kWh Wärme aus 4.000 kWh Strom sind 3,3.
  // Gegen den Schnitt von 3,4 im Feldtest von Fraunhofer ISE wären es
  // 3.882 kWh Strom gewesen, also 118 kWh mehr, bei 28 ct rund 33 €.
  await page.goto(base + "jahresarbeitszahl-berechnen.html");
  const jaz = await kachel("jaz");
  note(jaz.wert === "3,3" && jaz.zusatz === "unter dem Schnitt von 3,4",
       `Wärmepumpe: 13.200 kWh Wärme aus 4.000 kWh Strom = 3,3, unter dem Schnitt (${jaz.wert}, ${jaz.zusatz})`);
  note((await kachel("wkosten")).wert === "8,5 ct", `Wärmepumpe: eine kWh Wärme kostet 28 ct / 3,3 = 8,5 ct (${(await kachel("wkosten")).wert})`);
  const jv = await kachel("vergleich");
  note(jv.wert === "118 kWh" && jv.zusatz === "mehr Strom als mit 3,4, 33 €",
       `Wärmepumpe: 118 kWh mehr als mit 3,4, das sind 33 € (${jv.wert}, ${jv.zusatz})`);
  await page.check('input[name="jaz-art"][value="erde"]');
  note((await kachel("schnitt")).wert === "4,3" && (await kachel("vergleich")).wert === "930 kWh",
       `Wärmepumpe: Erdreich vergleicht mit 4,3, das sind 930 kWh (${(await kachel("vergleich")).wert})`);
  await page.check('input[name="jaz-art"][value="luft"]');
  await page.fill("#jaz-waerme", "13.600");
  note((await kachel("jaz")).zusatz === "genau der Schnitt im Feldtest" && !(await page.$('[data-kachel="vergleich"]')),
       "Wärmepumpe: genau 3,4 ist der Schnitt, und es gibt nichts zu vergleichen");
  await page.fill("#jaz-waerme", "20.000");
  note((await kachel("jaz")).zusatz === "höher als jede Luft-Wärmepumpe im Feldtest",
       "Wärmepumpe: 5,0 liegt über der Spanne bis 4,9");
  await page.fill("#jaz-strom", "13.200"); await page.fill("#jaz-waerme", "4.000");
  note((await text("#jaz-ergebnis")).includes("vertauscht"), "Wärmepumpe: Wärme kleiner als Strom ergibt einen Hinweis");
  await page.fill("#jaz-strom", "4.000"); await page.fill("#jaz-waerme", "13.200"); await page.fill("#jaz-preis", "");
  note(!(await page.$('[data-kachel="wkosten"]')) && (await kachel("vergleich")).zusatz === "mehr Strom als mit 3,4",
       "Wärmepumpe: ohne Strompreis keine Kosten, aber der Vergleich in kWh");
  await page.fill("#jaz-strom", "");
  note(!(await kaputt("#jaz-ergebnis")), "Wärmepumpe: ein leeres Feld ergibt keine kaputte Zahl");
  const feldtest = await page.evaluate(() => {
    const F = window.FELDTEST, f = n => n.toLocaleString("de-DE", { minimumFractionDigits: 1 });
    return [...document.querySelectorAll("#feldtest tbody tr")].filter(tr => {
      const g = F[tr.dataset.art], td = [...tr.querySelectorAll("td")].map(t => t.textContent.trim());
      return td[0] !== String(g.anlagen) || td[1] !== f(g.schnitt) || td[2] !== f(g.von) + " bis " + f(g.bis);
    }).length;
  });
  note(feldtest === 0, "Wärmepumpe: die Tabelle nennt dieselben Werte wie der Rechner");
  await page.fill("#jaz-strom", "4.000");
  note((await kachel("flaeche")).wert === "94 kWh" && (await kachel("flaeche")).zusatz === "im Feldtest Median 97",
       `Wärmepumpe: 13.200 kWh auf 140 m² sind 94 kWh je m² (${(await kachel("flaeche")).wert})`);
  await page.fill("#jaz-flaeche", "");
  note(!(await page.$('[data-kachel="flaeche"]')), "Wärmepumpe: ohne Fläche keine Kachel je m²");
  const m2 = await page.evaluate(() => ({ s: document.getElementById("m2-spanne").textContent, m: document.getElementById("m2-median").textContent, W: window.WAERME_JE_M2 }));
  note(m2.s === `${m2.W.von} und ${m2.W.bis}` && m2.m === String(m2.W.median), "Wärmepumpe: der Text nennt dieselben Werte je m² wie der Rechner");

  // **Photovoltaik.** 8.000 kWh erzeugt, 5.200 eingespeist: 2.800 selbst
  // verbraucht, 35 % des Solarstroms. Mit 2.900 kWh Bezug sind es 5.700 kWh
  // Verbrauch, davon 49 % vom Dach. Bei 28 ct nicht gekauft: 784 €.
  await page.goto(base + "photovoltaik-eigenverbrauch.html");
  const pvs = await kachel("selbst");
  note(pvs.wert === "2.800 kWh" && pvs.zusatz === "35 % deines Solarstroms",
       `Photovoltaik: 2.800 kWh selbst verbraucht, 35 % (${pvs.wert}, ${pvs.zusatz})`);
  const pva = await kachel("autarkie");
  note(pva.wert === "49 %" && pva.zusatz === "von 5.700 kWh Verbrauch", `Photovoltaik: 49 % vom Dach gedeckt (${pva.wert}, ${pva.zusatz})`);
  note((await kachel("gespart")).wert === "784 €" && !(await page.$('[data-kachel="verguetung"]')),
       "Photovoltaik: 784 € nicht gekauft, ohne Vergütung keine Kachel dafür");
  await page.fill("#pv-verguetung", "8");
  note((await kachel("verguetung")).wert === "416 €", `Photovoltaik: 5.200 kWh zu 8 ct sind 416 € (${(await kachel("verguetung")).wert})`);
  await page.fill("#pv-einspeisung", "9.000");
  note((await text("#pv-ergebnis")).includes("nicht mehr sein als erzeugt"), "Photovoltaik: mehr eingespeist als erzeugt ergibt einen Hinweis");
  await page.fill("#pv-einspeisung", "8.000"); await page.fill("#pv-bezug", "0");
  note((await kachel("autarkie")).wert === "0 %" && !(await kaputt("#pv-ergebnis")),
       "Photovoltaik: alles eingespeist und nichts bezogen ergibt 0 % ohne kaputte Zahl");
  await page.fill("#pv-erzeugt", "");
  note(!(await kaputt("#pv-ergebnis")), "Photovoltaik: ein leeres Feld ergibt keine kaputte Zahl");

  // **Die Grafik zum Strompreis.** Die Sätze und Kacheln stehen als Text in
  // der Seite, damit Google sie liest; die Zahlen dahinter kommen aus
  // `strompreis-holen.py`. Holt das Skript neue Werte, muss der Text folgen,
  // sonst stimmt die Seite nicht mehr mit ihrer eigenen Grafik überein.
  await page.goto(base + "strompreis-entwicklung.html");
  const sp = await page.evaluate(() => {
    const P = window.STROMPREISE, f = x => x.toLocaleString("de-DE", { minimumFractionDigits: 1, maximumFractionDigits: 1 });
    const t = id => document.getElementById(id).textContent.trim();
    const iMax = P.reduce((m, p, i) => p[1] > P[m][1] ? i : m, 0);
    const mitEu = P.filter(p => p[2] != null);
    const abstand = mitEu.reduce((m, p) => Math.max(m, p[1] - p[2]), 0);
    const falsch = [];
    if (t("fakt-anfang") !== f(P[0][1]) + " ct") falsch.push("Anfang");
    if (t("fakt-spitze") !== f(P[iMax][1]) + " ct") falsch.push("Spitze");
    if (t("fakt-zuletzt") !== f(P[P.length - 1][1]) + " ct") falsch.push("zuletzt");
    if (t("fakt-plus") !== String(Math.round((P[P.length - 1][1] / P[0][1] - 1) * 100))) falsch.push("Plus");
    if (t("fakt-runter") !== f(P[iMax][1] - P[P.length - 1][1])) falsch.push("runter");
    if (t("fakt-abstand") !== f(abstand)) falsch.push("Abstand");
    if (!mitEu.every(p => p[1] > p[2])) falsch.push("„in jedem Halbjahr teurer“");
    if (document.querySelectorAll("#preis-werte tbody tr").length !== P.length) falsch.push("Tabelle");
    if (!document.querySelector("#preis-flaeche svg path.linie-de")) falsch.push("Linie");
    return { n: P.length, falsch };
  });
  note(sp.n >= 30 && sp.falsch.length === 0,
       `Strompreis: ${sp.n} Halbjahre, Text und Grafik stimmen überein${sp.falsch.length ? " (falsch: " + sp.falsch.join(", ") + ")" : ""}`);

  // **Die Ablesehilfe zeigt immer genau einen Zähler**, und bei jedem passt
  // die Zahl unter dem Bild zu den umrandeten Ziffern im Bild.
  await page.goto(base + "zaehlerstand-ablesen.html");
  for (const fall of ["strom-alt", "strom-digital", "gas", "wasser"]) {
    await page.check(`input[name="zaehler"][value="${fall}"]`);
    const r = await page.evaluate(f => {
      const sichtbar = [...document.querySelectorAll(".ablese-fall")].filter(e => !e.hidden).map(e => e.dataset.fall);
      const el = document.querySelector(`.ablese-fall[data-fall="${f}"]`);
      const zaehlt = [...el.querySelectorAll(".rolle-zaehlt, .display-wert")].map(e => e.textContent).join("");
      return { sichtbar, zaehlt, steht: el.querySelector("figcaption b").textContent };
    }, fall);
    note(r.sichtbar.length === 1 && r.sichtbar[0] === fall && r.zaehlt === r.steht,
         `Ablesehilfe ${fall}: allein sichtbar, „${r.steht}“ steht im Bild`);
  }

  // **Ein Rechnerabschnitt auf der Startseite, nicht zwei.** Vom Gründer am
  // 4. Oktober gefunden: 0.120.0 setzte einen zweiten neben den vorhandenen.
  await page.goto(base + "index.html");
  const doppelt = await page.evaluate(() => {
    const ziele = [...document.querySelectorAll("main a.karte-verweis")].map(a => a.getAttribute("href"));
    return ziele.filter((z, i) => ziele.indexOf(z) !== i);
  });
  note(doppelt.length === 0, `Startseite: jeder Rechner hat genau eine Karte${doppelt.length ? " (doppelt: " + doppelt.join(", ") + ")" : ""}`);

  // **Stromkosten**, beide Wege. Nachgerechnet von Hand: 2.800 kWh × 0,34 €
  // = 952 €, dazu 12 € × 12 = 144 € Grundpreis, zusammen 1.096 €. Mit zwei
  // Ständen: 251 kWh × 0,34 € = 85,34 €, dazu 12 € × 12 ÷ 365 × 31 Tage =
  // 12,23 € Grundpreis, zusammen 97,57 € (taggenau wie CostEngine).
  await page.goto(base + "stromkosten-berechnen.html");
  note((await kachel("jahr")).wert === "1.096,00 €" && (await kachel("monat")).wert === "91,33 €",
       `Stromkostenrechner: 2.800 kWh, 34 ct, 12 € im Monat = 1.096,00 € im Jahr, 91,33 € im Monat (${(await kachel("jahr")).wert})`);
  note((await kachel("kwh")).wert === "39,1 ct" && (await kachel("grund")).wert === "144,00 €",
       `Stromkostenrechner: 39,1 ct je kWh mit Grundpreis, davon 144,00 € Grundpreis`);
  await page.selectOption("#s-gpart", "jahr");
  note((await kachel("jahr")).wert === "964,00 €", `Stromkostenrechner: 12 € Grundpreis im Jahr ergibt 964,00 € (${(await kachel("jahr")).wert})`);
  await page.selectOption("#s-gpart", "monat");
  await page.check('input[value="staende"]');
  note(await page.isHidden("#s-kwh") && await page.isVisible("#s-alt"), "Stromkostenrechner: der Umschalter zeigt die Felder für zwei Stände");
  const sz = await kachel("zeitraum");
  note(sz.wert === "97,57 €" && sz.zusatz === "251 kWh in 31 Tagen",
       `Stromkostenrechner: 251 kWh in 31 Tagen kosten 97,57 € mit taggenauem Grundpreis (${sz.wert}, ${sz.zusatz})`);
  note((await kachel("jahr")).wert === "≈ 1.148,81 €" && (await kachel("tag")).wert === "3,15 €",
       `Stromkostenrechner: hochgerechnet mit ≈, am Tag ohne (${(await kachel("jahr")).wert}, ${(await kachel("tag")).wert})`);
  await page.fill("#s-neu", "12.000");
  note((await text("#s-ergebnis")).includes("getauscht"), "Stromkostenrechner: ein kleinerer neuer Stand ergibt einen Hinweis");
  await page.fill("#s-neu", "12.731"); await page.fill("#s-ap", "");
  note(!(await kaputt("#s-ergebnis")), "Stromkostenrechner: ohne Arbeitspreis keine kaputte Zahl");

  // **Auf einen Blick.** Vom Gründer am 26. September: nicht zu viel Text,
  // klare Benennungen. Gezählt wird, was sonst schleichend wieder wächst:
  // der Hinweis unter einem Feld, der Text im Ergebnis, und wo der Rechner
  // steht.
  for (const datei of ["gas-in-kwh.html", "verbrauch-berechnen.html", "stromkosten-berechnen.html", "stromverbrauch-vergleichen.html", "jahresarbeitszahl-berechnen.html", "photovoltaik-eigenverbrauch.html"]) {
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
  for (const datei of ["gas-in-kwh.html", "verbrauch-berechnen.html", "stromkosten-berechnen.html", "stromverbrauch-vergleichen.html", "jahresarbeitszahl-berechnen.html", "photovoltaik-eigenverbrauch.html"]) {
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

  // **Gleich hohe Felder, gleich hohe Kacheln, Zahlen in einer Zeile.** Vom
  // Gründer am 3. Oktober: „hat verschiedene Größen der Boxen". Bis 0.119.2
  // war eine Auswahl 48 Pixel hoch, ein Zahlenfeld 52 und ein Datum 55, die
  // vierte Kachel stand allein in einer neuen Reihe, und auf dem Telefon brach
  // „2.702 kWh" mitten in der Zahl um. Gemessen breit und schmal.
  for (const breite of [1280, 390]) {
    await page.setViewportSize({ width: breite, height: 900 });
    for (const datei of ["gas-in-kwh.html", "verbrauch-berechnen.html", "stromkosten-berechnen.html", "stromverbrauch-vergleichen.html", "jahresarbeitszahl-berechnen.html", "photovoltaik-eigenverbrauch.html"]) {
      await page.goto(base + datei);
      const mass = await page.evaluate(() => {
        // Nur sichtbare: Der Stromkostenrechner blendet die Felder des anderen
        // Wegs aus, und die haben die Höhe null.
        const hoehen = [...document.querySelectorAll(".rechner .eingabe")].filter(e => e.offsetParent !== null)
          .map(e => Math.round(e.getBoundingClientRect().height));
        const neben = [...document.querySelectorAll(".kachel:not(.kachel-haupt)")].map(k => k.getBoundingClientRect());
        const reihen = {};
        for (const r of neben) (reihen[Math.round(r.top)] ||= []).push(Math.round(r.height));
        const ungleich = Object.values(reihen).some(r => Math.max(...r) - Math.min(...r) > 1);
        const umgebrochen = [...document.querySelectorAll(".kachel-wert")].filter(w => {
          const zeile = parseFloat(getComputedStyle(w).lineHeight) || parseFloat(getComputedStyle(w).fontSize) * 1.3;
          return w.getBoundingClientRect().height > zeile * 1.5;
        }).map(w => w.textContent);
        return { felder: hoehen.length, hoehen: [...new Set(hoehen)], ungleich, umgebrochen,
                 reihen: Object.keys(reihen).length, neben: neben.length };
      });
      note(mass.felder > 0 && mass.hoehen.length === 1, `${datei} bei ${breite} px: alle Felder gleich hoch (${mass.hoehen.join(", ")} px)`);
      note(!mass.ungleich, `${datei} bei ${breite} px: Kacheln einer Reihe gleich hoch`);
      note(mass.umgebrochen.length === 0, `${datei} bei ${breite} px: keine Zahl bricht um${mass.umgebrochen.length ? " (" + mass.umgebrochen.join(", ") + ")" : ""}`);
      if (breite === 1280) note(mass.reihen <= 1, `${datei}: die Nebenkacheln teilen sich eine Reihe (${mass.neben} in ${mass.reihen})`);
    }
  }
  // Das Protokoll passt auch auf dem Telefon in die Breite.
  await page.setViewportSize({ width: 390, height: 900 });
  await page.goto(base + "zaehlerstand-umzug.html");
  const blatt = await page.evaluate(() => {
    const t = document.querySelector(".protokoll-zaehler"), r = t.parentElement;
    return { tabelle: Math.round(t.scrollWidth), platz: Math.round(r.clientWidth),
             kopf: !!document.querySelector("#protokoll .blatt-kopf h2") };
  });
  note(blatt.tabelle <= blatt.platz + 1, `Protokoll bei 390 px: die Zählertabelle passt in die Breite (${blatt.tabelle} von ${blatt.platz} px)`);
  note(blatt.kopf, "Protokoll: das Blatt hat einen Kopf mit Titel");

  // **Groß genug für einen Daumen.** Wer mit der Rechnung in der einen Hand
  // tippt, trifft ein kleines Feld nicht.
  await page.setViewportSize({ width: 390, height: 900 });
  for (const datei of ["gas-in-kwh.html", "verbrauch-berechnen.html", "stromkosten-berechnen.html", "stromverbrauch-vergleichen.html", "jahresarbeitszahl-berechnen.html", "photovoltaik-eigenverbrauch.html", "zaehlerstand-umzug.html"]) {
    await page.goto(base + datei);
    const klein = await page.evaluate(() =>
      [...document.querySelectorAll(".rechner input, .rechner select, main button")]
        .filter(e => e.offsetParent !== null || e.type === "radio")
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
    // **Textgröße über „aA" in Safari.** Safari bricht die Seite dann um, als
    // wäre der Bildschirm um den Faktor schmaler. Bis 0.117.4 lief bei 200 %
    // jede Seite über den Rand, weil Rasterspalten ohne Untergrenze so breit
    // blieben wie ihr breitestes Wort und Felder ihre eigene Breite behielten.
    ["iPhone SE, Textgröße 200 %", 188, 334, true], ["iPhone SE, Textgröße 300 %", 125, 222, true],
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
          // Der Sprungverweis steht über dem Rand, bis er den Fokus bekommt.
          // Mit festem Versatz schaute er bei großer Textgröße heraus.
          sprung: (() => { const e = document.querySelector(".sprung"); return e ? Math.round(e.getBoundingClientRect().bottom) : 0; })(),
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
      if (r.sprung > 0) fehler.push(`${datei}: „Zum Inhalt springen" ragt ${r.sprung} px ins Bild`);
      if (r.pfadVersatz > 2) fehler.push(`${datei}: Pfad steht versetzt (${Math.round(r.pfadVersatz)} px)`);
    }
    note(fehler.length === 0, `${name} (${w} × ${h}): ${fehler.length ? fehler.slice(0, 2).join("; ") : "alle Seiten ohne Überlauf, lesbar, mit Zielen für den Finger"}`);
    await page.close();
  }

  // Und die Gegenprobe: Mit der Tabulatortaste kommt er ins Bild. Ein
  // Verweis, der nie erscheint, wäre versteckt statt nur weggeräumt.
  {
    const page = await browser.newPage({ viewport: { width: 188, height: 334 } });
    await page.goto(base + "index.html");
    await page.keyboard.press("Tab");
    const oben = await page.evaluate(() => {
      const e = document.querySelector(".sprung"), b = e.getBoundingClientRect();
      return { fokus: document.activeElement === e, top: Math.round(b.top), bottom: Math.round(b.bottom) };
    });
    note(oben.fokus && oben.top >= 0 && oben.bottom > 0,
         `„Zum Inhalt springen" erscheint mit der Tabulatortaste (${oben.top} bis ${oben.bottom} px)`);
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
  await alt.goto(base + "stromkosten-berechnen.html");
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

// --- Zählung auf dem Server
//
// Die Datenschutzerklärung sagt, was gezählt wird und was nicht. Diese
// Prüfung ruft die Funktion so auf, wie Cloudflare es tut, und liest mit, was
// sie schreibt. Steht darin je eine IP-Adresse, eine Browserkennung oder eine
// vollständige Herkunftsadresse, ist das Versprechen gebrochen, und genau
// daran soll es scheitern, nicht an einem Leser, der es bemerkt.
console.log("\nZählung");
{
  const z = await import(new URL("../docs/website-server/_middleware.js", import.meta.url));
  const IP = "203.0.113.42", KENNUNG = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) Mobile/15E148";
  const aufruf = async ({ pfad = "/stromkosten-berechnen", art = "text/html; charset=utf-8", status = 200,
                          verweis = "https://www.google.de/search?q=abschlag+zu+hoch", ua = KENNUNG,
                          bindung = true, wirft = false, adresse = "https://zaehlora.de" } = {}) => {
    const punkte = [];
    const antwort = await z.onRequest({
      request: new Request(adresse + pfad, { headers: {
        "referer": verweis, "user-agent": ua, "cf-connecting-ip": IP, "x-forwarded-for": IP } }),
      env: bindung ? { ZAEHLUNG: { writeDataPoint: p => { if (wirft) throw new Error("kaputt"); punkte.push(p); } } } : {},
      next: async () => new Response("<p>Seite</p>", { status, headers: { "content-type": art } }),
    });
    return { antwort, punkte };
  };

  const { antwort, punkte } = await aufruf();
  const zeile = JSON.stringify(punkte);
  note(punkte.length === 1 && JSON.stringify(punkte[0].blobs) === JSON.stringify(["/stromkosten-berechnen", "google", "", "Telefon", ""]),
       `Ein Seitenaufruf ergibt eine Zeile: ${JSON.stringify(punkte[0] && punkte[0].blobs)}`);
  note(!zeile.includes(IP) && !zeile.includes("Mozilla") && !zeile.includes("search?q"),
       "Keine IP-Adresse, keine Browserkennung, keine Suchanfrage in der Zeile");
  note(antwort.status === 200 && (await antwort.text()) === "<p>Seite</p>" && antwort.headers.get("x-content-type-options") === "nosniff",
       "Die Seite kommt unverändert an, mit den Sicherheitsangaben");

  note((await aufruf({ pfad: "/stil.css", art: "text/css" })).punkte.length === 0, "Stylesheet wird nicht gezählt");
  note((await aufruf({ pfad: "/wp-login.php", status: 404 })).punkte[0].blobs[0] === "404",
       "Eine unbekannte Adresse zählt als 404, nicht mit ihrem Namen");
  note((await aufruf({ pfad: "/irgendwas" })).punkte[0].blobs[0] === "andere", "Eine fremde Seite zählt als „andere“");
  note((await aufruf({ pfad: "/datenschutz.html" })).punkte[0].blobs[0] === "/datenschutz", "„.html“ und ohne zählen gleich");
  note((await aufruf({ pfad: "/?von=Reddit_Forum!" })).punkte[0].blobs[4] === "redditforum",
       "Eine selbst gesetzte Quelle wird auf ein Kennwort gekürzt");
  note((await aufruf({ verweis: "https://zaehlora.de/ratgeber" })).punkte[0].blobs[1] === "intern", "Klicks innerhalb der Seite heißen „intern“");

  // Die alte Adresse und `www` leiten weiter, mit Pfad und Zusatz, und
  // zählen dabei nicht: Gezählt wird der Aufruf, der danach kommt.
  for (const alt of ["https://zaehlora.pages.dev", "https://www.zaehlora.de"]) {
    const { antwort: weiter, punkte: gezaehlt } = await aufruf({ adresse: alt, pfad: "/hilfe?von=forum" });
    note(weiter.status === 301 && weiter.headers.get("location") === "https://zaehlora.de/hilfe?von=forum" && gezaehlt.length === 0,
         `${alt.slice(8)} leitet mit 301 auf zaehlora.de weiter, samt Pfad (${weiter.status} ${weiter.headers.get("location")})`);
  }
  note((await aufruf({ adresse: "https://abc123.zaehlora.pages.dev" })).antwort.status === 200,
       "Eine Vorschauadresse leitet nicht weiter");
  // Der frühere Abschlagsrechner zeigt auf seinen Nachfolger, auf jeder Adresse.
  for (const [adresse, pfad] of [["https://zaehlora.de", "/abschlag-zu-hoch"], ["https://zaehlora.de", "/abschlag-zu-hoch.html"],
                                 ["https://zaehlora.pages.dev", "/abschlag-zu-hoch.html"]]) {
    const { antwort: weiter } = await aufruf({ adresse, pfad });
    note(weiter.status === 301 && weiter.headers.get("location") === "https://zaehlora.de/stromkosten-berechnen#abschlag",
         `${adresse.slice(8)}${pfad} leitet auf den Stromkostenrechner (${weiter.status} ${weiter.headers.get("location")})`);
  }
  note((await aufruf({ verweis: "" })).punkte[0].blobs[1] === "direkt", "Ohne Herkunft heißt es „direkt“");
  note((await aufruf({ ua: "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" })).punkte[0].blobs[3] === "Bot: Google",
       "Googlebot wird als Bot gezählt, getrennt von Menschen");
  note(z.geraet("Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X)") === "Tablet" && z.geraet("Mozilla/5.0 (Windows NT 10.0; Win64; x64)") === "Rechner",
       "iPad als Tablet, Windows als Rechner");

  const ohne = await aufruf({ bindung: false });
  const kaputt = await aufruf({ wirft: true });
  note(ohne.antwort.status === 200 && kaputt.antwort.status === 200 && (await kaputt.antwort.text()) === "<p>Seite</p>",
       "Ohne Zählung oder mit kaputter Zählung wird die Seite trotzdem ausgeliefert");

  // Und dasselbe Versprechen im Text: Was die Funktion schreibt, steht in der
  // Datenschutzerklärung, und was dort ausgeschlossen ist, fehlt im Code.
  const erklaerung = readFileSync(`${dir}/datenschutz.html`, "utf8").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ");
  const quelltext = readFileSync(new URL("../docs/website-server/_middleware.js", import.meta.url), "utf8").replace(/\/\/.*$/gm, "");
  note(/zählt/.test(erklaerung) && /IP-Adresse/.test(erklaerung) && /drei Monate/.test(erklaerung),
       "Die Datenschutzerklärung beschreibt die Zählung, nennt die IP-Adresse und die Aufbewahrung");
  note(!/cf-connecting-ip|x-forwarded-for|\.ip\b|clientAddress/i.test(quelltext),
       "Die Funktion liest keine IP-Adresse aus");
}

await browser.close();
server.close();

console.log(`\n${failures.length === 0 ? "Alles grün" : failures.length + " Prüfung(en) gefallen"}`);
if (failures.length) {
  for (const f of failures) console.log("  · " + f);
  process.exit(1);
}
