/* Packt die Website in **eine** Datei, damit sie sich als Artifact ansehen lässt.
 *
 * **Warum das nötig ist.** Ein Artifact ist eine einzige Seite hinter einer
 * strengen Inhaltsrichtlinie: Nichts wird von außen nachgeladen — keine
 * Stildatei, kein Bild. Die Website besteht aber aus sechs Seiten, einer
 * gemeinsamen `stil.css` und sechs Fotos. Also wird alles hineingezogen: der
 * Stil in ein `<style>`, jedes Bild als Datenadresse, und die sechs Seiten
 * hintereinander in je einen Abschnitt. Verweise zwischen den Seiten werden zu
 * Sprungmarken.
 *
 * Was dabei bewusst verlorengeht: die Adresszeile, `canonical`, die Sitemap.
 * Das Bündel ist eine Vorschau zum Ansehen, nicht die Website. Was online
 * geht, ist `docs/website/` — unverändert.
 *
 * Aufruf:  node scripts/website-buendeln.mjs <zieldatei>
 */
import { readFileSync, writeFileSync } from "node:fs";

const dir = "docs/website";
const ziel = process.argv[2];
if (!ziel) {
  console.error("Aufruf: node scripts/website-buendeln.mjs <zieldatei.html>");
  process.exit(1);
}

// Reihenfolge wie im Fuß der Seite: erst das Angebot, dann die Antworten,
// zuletzt das Pflichtprogramm.
const seiten = [
  ["index.html", "v-start"],
  ["hilfe.html", "v-hilfe"],
  ["gas-in-kwh.html", "v-gas"],
  ["abschlag-zu-hoch.html", "v-abschlag"],
  ["datenschutz.html", "v-datenschutz"],
  ["impressum.html", "v-impressum"],
];
const marke = Object.fromEntries(seiten.map(([d, id]) => [d, id]));

const bildCache = new Map();
const bild = (pfad) => {
  if (!bildCache.has(pfad)) {
    const roh = readFileSync(`${dir}/${pfad}`);
    const typ = pfad.endsWith(".png") ? "png" : "jpeg";
    bildCache.set(pfad, `data:image/${typ};base64,${roh.toString("base64")}`);
  }
  return bildCache.get(pfad);
};

const stil = readFileSync(`${dir}/stil.css`, "utf8");

const kopfQuelle = readFileSync(`${dir}/index.html`, "utf8");
const titel = kopfQuelle.match(/<title>([^<]+)<\/title>/)[1];
const beschreibung = kopfQuelle.match(/<meta name="description" content="([^"]+)"/)[1];

const teile = [];

for (const [datei, id] of seiten) {
  const html = readFileSync(`${dir}/${datei}`, "utf8");
  let koerper = html.slice(html.indexOf("<body>") + 6, html.indexOf("</body>"));

  // Bilder hineinziehen — `src` **und** `srcset`. Die dunklen Fassungen hängen
  // an `<source srcset=…>`; wer nur `src` ersetzt, veröffentlicht ein Bündel,
  // das im dunklen Erscheinungsbild drei leere Rahmen zeigt.
  koerper = koerper.replace(/(src|srcset)="(bilder\/[^"]+)"/g,
    (_, attr, p) => `${attr}="${bild(p)}"`);

  // Verweise auf andere Seiten werden zu Sprungmarken. `/` ist der Anfang.
  koerper = koerper.replace(/href="\/"/g, `href="#v-start"`);
  koerper = koerper.replace(/href="([a-z-]+\.html)(#[^"]*)?"/g, (ganz, d) =>
    marke[d] ? `href="#${marke[d]}"` : ganz);

  // Nur die erste Seite behält den Sprunglink und die Kopfzeile; sechsmal
  // dieselbe Navigationsleiste untereinander wäre in einem Bündel Unsinn.
  if (datei !== "index.html") {
    koerper = koerper.replace(/<a class="sprung"[\s\S]*?<\/a>/, "");
    koerper = koerper.replace(/<header class="kopf">[\s\S]*?<\/header>/, "");
    koerper = koerper.replace(/<footer[\s\S]*?<\/footer>/, "");
  }

  // Doppelte `id`-Werte über sechs Seiten hinweg: Nur die erste Seite darf
  // `inhalt` heißen, sonst springt der Sprunglink an die falsche Stelle.
  if (datei !== "index.html") {
    koerper = koerper.replace(/ id="inhalt"/g, "");
  }

  teile.push(`<section id="${id}" class="v-seite">\n${koerper}\n</section>`);
}

const seite = `<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${titel}</title>
<meta name="description" content="${beschreibung}">
<meta name="theme-color" content="#FBFAF8" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#0F0E0C" media="(prefers-color-scheme: dark)">
<style>
${stil}

/* Nur für das Bündel: Die sechs Seiten liegen untereinander und werden durch
   eine Linie getrennt, damit man sieht, wo die eine aufhört. */
.v-seite + .v-seite { border-top: 1px solid var(--linie, rgba(128,128,128,.25)); }
</style>
</head>
<body>
${teile.join("\n\n")}
</body>
</html>
`;

writeFileSync(ziel, seite);
console.log(`${ziel} — ${(seite.length / 1024 / 1024).toFixed(2)} MB, ${seiten.length} Seiten, ${bildCache.size} Bilder`);
