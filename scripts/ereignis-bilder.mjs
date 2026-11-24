#!/usr/bin/env node
/* Die zwei Bilder für das Ereignis „Winter-Check“ im App Store.
 *
 * Apple verlangt für ein Ereignis ein Bild für die Karte (1920 × 1080, quer)
 * und eines für die Seite dahinter (1080 × 1920, hoch). Auf beide legt Apple
 * Name und Kurzbeschreibung selbst, unten und über das Bild. Deshalb steht hier
 * **kein Text**: Er stünde doppelt da, und der untere Teil bleibt ruhig, damit
 * Apples Schrift lesbar bleibt.
 *
 * Gezeigt wird, was die App zeigt: der Vergleich vorher und nachher aus dem
 * Simulator (`store-wp-vergleich`, `run.sh`), im selben warmen Dunkel und
 * Gerätrahmen wie die Store-Bilder (`store-shots.mjs`). Nichts ist gemalt
 * oder nachgerechnet.
 *
 * Aufruf:
 *     node scripts/ereignis-bilder.mjs [eingang] [ausgang]
 * Vorgabe: build/store → build/ereignis. Eingang wie bei `store-shots.mjs`,
 * die Bilder in voller Größe aus dem Zweig `screenshots`.
 */
import { chromium } from "playwright";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const IN = process.argv[2] || "build/store";
const OUT = process.argv[3] || "build/ereignis";
const QUELLE = join(IN, "store-wp-vergleich.jpg");
const SYMBOL = "Assets.xcassets/AppIcon.appiconset/icon-1024.png";

/* Die Maße stehen bei Apple fest; ein anderes Maß nimmt die Schnittstelle
 * nicht an. `asc-schaufenster.py` lädt die Dateien unter genau diesen Namen. */
const BILDER = [
  { datei: "karte.jpg", art: "EVENT_CARD", w: 1920, h: 1080 },
  { datei: "seite.jpg", art: "EVENT_DETAILS_PAGE", w: 1080, h: 1920 },
];

function seite(b, bild, symbol) {
  const quer = b.w > b.h;
  // Quer: Gerät rechts, oben angeschnitten nicht, unten aus dem Bild laufend,
  // links das Symbol. Hoch: Gerät mittig im oberen Teil. In beiden Fällen
  // bleibt das untere Drittel dunkel und frei für Apples Schrift.
  const geraet = quer
    ? `width: 560px; position: absolute; right: 230px; top: 90px;`
    : `width: 640px; position: absolute; left: 220px; top: 150px;`;
  const marke = quer
    ? `width: 300px; position: absolute; left: 260px; top: 230px;`
    : `display: none;`;
  return `<!doctype html><html lang="de"><head><meta charset="utf-8"><style>
  html, body { margin: 0; }
  body {
    width: ${b.w}px; height: ${b.h}px; overflow: hidden; position: relative;
    background:
      radial-gradient(70% 70% at ${quer ? "70% 20%" : "50% 15%"}, #5A4026 0%, rgba(90,64,38,0) 70%),
      linear-gradient(180deg, #221A12 0%, #110D09 100%);
  }
  .geraet { ${geraet} padding: 16px; border-radius: 86px; background: #0A0806;
            box-shadow: 0 60px 160px rgba(0,0,0,0.65), inset 0 0 0 3px #3B3127; }
  .geraet img { display: block; width: 100%; border-radius: 70px; }
  .marke { ${marke} border-radius: 22.5%; box-shadow: 0 40px 120px rgba(0,0,0,0.55); }
  /* Der ruhige Grund für Apples Schrift. */
  .schatten { position: absolute; left: 0; right: 0; bottom: 0; height: ${quer ? 46 : 38}%;
              background: linear-gradient(180deg, rgba(17,13,9,0) 0%, rgba(17,13,9,0.92) 55%, #110D09 100%); }
</style></head><body>
  <img class="marke" src="data:image/png;base64,${symbol}" alt="">
  <div class="geraet"><img src="data:image/jpeg;base64,${bild}" alt=""></div>
  <div class="schatten"></div>
</body></html>`;
}

if (!existsSync(QUELLE)) {
  console.error(`Fehlt: ${QUELLE} (aus dem Zweig screenshots, entsteht in run.sh)`);
  process.exit(1);
}
const bild = readFileSync(QUELLE).toString("base64");
const symbol = readFileSync(SYMBOL).toString("base64");
mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.PULSE_CHROMIUM || undefined });
for (const b of BILDER) {
  const page = await browser.newPage({ viewport: { width: b.w, height: b.h }, deviceScaleFactor: 1 });
  await page.setContent(seite(b, bild, symbol), { waitUntil: "load" });
  const ziel = join(OUT, b.datei);
  writeFileSync(ziel, await page.screenshot({ type: "jpeg", quality: 92 }));
  console.log(`  ✓ ${ziel} (${b.w} × ${b.h})`);
  await page.close();
}
await browser.close();
