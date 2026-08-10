#!/usr/bin/env node
/* Erzeugt das App-Icon in allen Fassungen, die iOS 18 kennt.
 *
 * **Warum ein Skript und keine Bilddatei im Repository.** Ein Icon ist an
 * einem Dutzend Stellen dasselbe Bild in verschiedenen Größen und
 * Erscheinungsbildern. Von Hand gepflegt laufen die Fassungen auseinander,
 * sobald sich eine Farbe ändert — und dann steht im Store ein anderes Zeichen
 * als auf dem Gerät. Hier ist die Zeichnung einmal beschrieben; alles Weitere
 * fällt daraus ab.
 *
 * **Warum Chromium und kein Bildwerkzeug.** Playwright ist ohnehin im Projekt,
 * weil der Klick-Dummy geprüft wird. Ein zweites Werkzeug nur fürs Rastern
 * wäre eine weitere Abhängigkeit, die auf einem frischen Rechner fehlen kann.
 *
 * Aufruf: node scripts/icon.mjs
 * Ergebnis: Assets.xcassets/AppIcon.appiconset/*.png
 */
import { chromium } from "playwright";
import { mkdirSync, writeFileSync } from "node:fs";

const OUT = "Assets.xcassets/AppIcon.appiconset";

/* Die Zeichnung.
 *
 * Der Name ist das Bild: ein **Meter** — der Bogen einer Skala — und ein
 * **Puls**, die Linie darin. Beides in einem Zeichen, damit es sich ohne
 * Beschriftung merken lässt.
 *
 * Entscheidungen, die auf 40 Punkt zielen und nicht auf 1024:
 * - Ein einziges Motiv. Zahlen, Ziffernrollen oder ein Zählergehäuse wären auf
 *   dem Startbildschirm ein Fleck.
 * - Bernstein auf warmem Dunkel. Die Kategorie ist blau und grün; ein warmer
 *   Ton fällt in der Liste auf, und es ist derselbe Akzent wie in der App
 *   (`PulseColor.tint`).
 * - Kein Rand, kein Schlagschatten, keine Schrift. iOS schneidet die Ecken
 *   selbst; alles, was den Rand berührt, sieht danach beschnitten aus.
 * - Die Pulslinie hat runde Enden und eine Spitze, die über den Bogen
 *   hinausragt. Ohne diesen Ausbruch wirkt das Zeichen wie ein Tachometer und
 *   damit wie hundert andere.
 */
function markup({ background, arc, pulse }) {
  return `<!doctype html><html><head><meta charset="utf-8"><style>
    html,body{margin:0;padding:0;width:1024px;height:1024px;overflow:hidden}
  </style></head><body>
  <svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <linearGradient id="ground" x1="0" y1="0" x2="0" y2="1">
        ${background}
      </linearGradient>
      <linearGradient id="sweep" x1="0" y1="0" x2="1" y2="1">
        ${arc}
      </linearGradient>
    </defs>

    <rect width="1024" height="1024" fill="url(#ground)"/>

    <!-- Der Bogen: eine Skala, offen nach unten. 270 Grad, weil ein
         geschlossener Kreis ein Knopf wäre und kein Messwerk. -->
    <path d="M 306 718 A 290 290 0 1 1 718 718"
          fill="none" stroke="url(#sweep)" stroke-width="86" stroke-linecap="round"/>

    <!-- Der Puls. Ein Ausschlag, kein Zickzack: Zwei Zacken lesen sich auf
         kleiner Fläche als Rauschen, einer als Ereignis.
         Die Linie endet innen und berührt den Bogen nicht — ein Zeichen, das
         seinen eigenen Rahmen anfasst, wirkt beschnitten. -->
    <path d="M 356 512 L 440 512 L 486 382 L 560 642 L 606 512 L 668 512"
          fill="none" stroke="${pulse}" stroke-width="56"
          stroke-linecap="round" stroke-linejoin="round"/>
  </svg></body></html>`;
}

/* Drei Fassungen, seit iOS 18 alle drei verlangt.
 *
 * Die getönte Fassung wird vom System eingefärbt und bekommt deshalb **keine**
 * eigenen Farben: iOS nimmt die Helligkeit als Maske. Alles, was hier grau
 * bleibt, verschwindet dort — deshalb steht das Zeichen dort auf Schwarz und
 * der Punkt am Ende der Linie entfällt, weil er in der Maske mit der Linie
 * verschmölze. */
const variants = {
  "icon-1024": {
    background: `<stop offset="0" stop-color="#241F16"/><stop offset="1" stop-color="#12100C"/>`,
    arc: `<stop offset="0" stop-color="#E8A93C"/><stop offset="1" stop-color="#B8670A"/>`,
    pulse: "#FDF8EF"
  },
  "icon-1024-dark": {
    background: `<stop offset="0" stop-color="#17150F"/><stop offset="1" stop-color="#0A0908"/>`,
    arc: `<stop offset="0" stop-color="#E0A040"/><stop offset="1" stop-color="#9A5608"/>`,
    pulse: "#F5F2EC"
  },
  "icon-1024-tinted": {
    background: `<stop offset="0" stop-color="#000000"/><stop offset="1" stop-color="#000000"/>`,
    arc: `<stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#9A9A9A"/>`,
    pulse: "#FFFFFF"
  }
};

mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.PULSE_CHROMIUM || undefined });
const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });

for (const [name, options] of Object.entries(variants)) {
  await page.setContent(markup(options));
  await page.screenshot({ path: `${OUT}/${name}.png`, omitBackground: false });
  console.log(`  ${OUT}/${name}.png`);
}
await browser.close();

/* Ein einziger Eintrag je Erscheinungsbild. Seit Xcode 14 rechnet das System
 * alle kleineren Größen selbst aus 1024 aus — die zwölf Einzelbilder von
 * früher waren zwölf Gelegenheiten, eines davon zu vergessen. */
writeFileSync(`${OUT}/Contents.json`, JSON.stringify({
  images: [
    { filename: "icon-1024.png", idiom: "universal", platform: "ios", size: "1024x1024" },
    { appearances: [{ appearance: "luminosity", value: "dark" }],
      filename: "icon-1024-dark.png", idiom: "universal", platform: "ios", size: "1024x1024" },
    { appearances: [{ appearance: "luminosity", value: "tinted" }],
      filename: "icon-1024-tinted.png", idiom: "universal", platform: "ios", size: "1024x1024" }
  ],
  info: { author: "xcode", version: 1 }
}, null, 2) + "\n");
console.log(`  ${OUT}/Contents.json`);
