#!/usr/bin/env node
/* Setzt die Bilder für den App Store: Überschrift oben, das echte
 * Bildschirmfoto darunter.
 *
 * **Warum gesetzt und nicht roh.** Bis 1.5 gingen die Simulator-Bilder roh in
 * den Store, und das erste war ein leerer Ziffernblock: „00.000,000", ein
 * grauer Knopf, kein Wort dazu. Das zweite zeigte „Gas ist seit 105 Tagen
 * nicht abgelesen". Vom Gründer am 19. Oktober: Das erste Bild muss Interesse
 * wecken und einen vollen Haushalt zeigen. In der Suchliste sieht man die
 * ersten drei Bilder, ohne Text daneben; ein nacktes Bildschirmfoto beantwortet
 * dort nicht, was man davon hat.
 *
 * **Die Texte stehen nicht hier**, sondern in `docs/09-appstore.md` unter
 * „Überschriften der Bildschirmfotos". Dort prüft `check-store-texte.py` sie
 * wie jeden anderen Store-Text, und wer den Laden ändern will, findet sie
 * neben Beschreibung und Versionshinweisen.
 *
 * **Die Bilder sind echt.** Gesetzt wird nur, was die App zeigt; Zahlen,
 * Karten und Knöpfe kommen aus dem Simulator (`run.sh`, `-pulse-schaufenster`).
 * Dazugesetzt werden nur Überschrift, Unterzeile und auf dem ersten Bild die
 * Namen der Zähler, die auf dem kleinen Schirm nicht alle Platz haben.
 *
 * Aufruf:
 *     node scripts/store-shots.mjs [eingang] [ausgang]
 * Vorgabe: build/store → build/store-gesetzt. Eingang sind die Bilder in
 * voller Größe aus dem Zweig `screenshots` (`git archive origin/screenshots
 * store`). Jedes Bild behält genau sein Maß, sonst nimmt Apple es nicht.
 */
import { chromium } from "playwright";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const IN = process.argv[2] || "build/store";
const OUT = process.argv[3] || "build/store-gesetzt";

/* Die Überschriften aus dem Store-Dokument.
 *
 * Eine Zeile je Bild: `quelle | Überschrift | Unterzeile | Leiste`. Ein Wort
 * zwischen Sternchen steht in Bernstein, die Leiste ist optional und durch
 * „·" getrennt. Die Reihenfolge der Zeilen ist die Reihenfolge im Laden. */
function ueberschriften() {
  const doc = readFileSync("docs/09-appstore.md", "utf8");
  const abschnitt = doc.split("### Überschriften der Bildschirmfotos")[1];
  if (!abschnitt) throw new Error("09-appstore.md: Abschnitt „Überschriften der Bildschirmfotos“ fehlt");
  const block = abschnitt.match(/```\n([\s\S]*?)```/);
  if (!block) throw new Error("09-appstore.md: kein Textblock unter „Überschriften der Bildschirmfotos“");
  return block[1].trim().split("\n").map((zeile, i) => {
    const [quelle, kopf, unter, leiste] = zeile.split("|").map(t => (t || "").trim());
    if (!quelle || !kopf || !unter) throw new Error(`09-appstore.md: Zeile ${i + 1} unvollständig: ${zeile}`);
    return { nummer: i + 1, quelle, kopf, unter, leiste: leiste ? leiste.split("·").map(t => t.trim()) : [] };
  });
}

/* Zwei Geräte, zwei Maße. Die Schriftgrößen gehen mit der Breite, das
 * Verhältnis bleibt: Auf dem iPad soll die Überschrift nicht wie ein Zettel
 * an einer Wand aussehen. */
const GERAETE = [
  { praefix: "", w: 1320, h: 2868, rand: 90, oben: 150, kopf: 108, unter: 50, leiste: 34, breite: 1040, radius: 96, rahmen: 18 },
  { praefix: "ipad-", w: 2064, h: 2752, rand: 150, oben: 150, kopf: 128, unter: 58, leiste: 44, breite: 1540, radius: 56, rahmen: 22 }
];

const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const betont = s => esc(s).replace(/\*([^*]+)\*/g, "<em>$1</em>");

function seite(g, bild, text) {
  const daten = readFileSync(bild).toString("base64");
  const leiste = text.leiste.length
    ? `<div class="leiste">${text.leiste.map(n => `<span>${esc(n)}</span>`).join("")}</div>` : "";
  return `<!doctype html><html lang="de"><head><meta charset="utf-8">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Figtree:wght@500;600;800&display=block">
<style>
  /* Warmes Dunkel wie das App-Symbol: Bernstein darauf fällt in einer
     Ergebnisliste auf, in der fast alles weiß, blau oder grün ist. */
  html, body { margin: 0; }
  body {
    width: ${g.w}px; height: ${g.h}px; overflow: hidden;
    background:
      radial-gradient(90% 55% at 50% 0%, #4A3520 0%, rgba(74,53,32,0) 70%),
      linear-gradient(180deg, #221A12 0%, #17120D 100%);
    color: #F7F0E5; font-family: Figtree, sans-serif;
    display: flex; flex-direction: column; align-items: center;
  }
  .kopf { box-sizing: border-box; width: 100%; padding: ${g.oben}px ${g.rand}px 0; text-align: center; }
  h1 { margin: 0; font-weight: 800; font-size: ${g.kopf}px; line-height: 1.04;
       letter-spacing: -0.022em; text-wrap: balance; }
  h1 em { font-style: normal; color: #F4AE45; }
  p { margin: 0.55em auto 0; max-width: 92%; font-weight: 500; font-size: ${g.unter}px;
      line-height: 1.28; color: #DCCFBD; text-wrap: balance; }
  .leiste { display: flex; flex-wrap: wrap; justify-content: center; gap: ${Math.round(g.leiste * 0.45)}px;
            margin-top: ${Math.round(g.leiste * 1.1)}px; }
  .leiste span { font-weight: 600; font-size: ${g.leiste}px; padding: 0.32em 0.85em; border-radius: 999px;
                 color: #FBE6C4; background: rgba(244,174,69,0.13); box-shadow: inset 0 0 0 2px rgba(244,174,69,0.42); }
  .geraet { margin-top: ${Math.round(g.kopf * 0.62)}px; width: ${g.breite}px; flex: none;
            padding: ${g.rahmen}px; border-radius: ${g.radius}px; background: #0A0806;
            box-shadow: 0 50px 140px rgba(0,0,0,0.6), inset 0 0 0 3px #3B3127; }
  .geraet img { display: block; width: 100%; border-radius: ${g.radius - g.rahmen}px; }
</style></head><body>
  <div class="kopf"><h1>${betont(text.kopf)}</h1><p>${betont(text.unter)}</p>${leiste}</div>
  <div class="geraet"><img src="data:image/jpeg;base64,${daten}" alt=""></div>
</body></html>`;
}

const texte = ueberschriften();
mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.PULSE_CHROMIUM || undefined });
let fehlt = 0, gesetzt = 0;
for (const g of GERAETE) {
  const page = await browser.newPage({ viewport: { width: g.w, height: g.h }, deviceScaleFactor: 1 });
  for (const text of texte) {
    const bild = join(IN, `${g.praefix}${text.quelle}.jpg`);
    if (!existsSync(bild)) {
      console.log(`  · fehlt: ${bild}`);
      fehlt++;
      continue;
    }
    await page.setContent(seite(g, bild, text), { waitUntil: "networkidle" });
    await page.evaluate(() => document.fonts.ready);
    // **Eine Ersatzschrift wäre ein stiller Fehler.** Lädt die Schrift nicht,
    // setzt Chromium eine andere, und das Bild sieht aus wie gewollt, nur
    // schlechter. Dann lieber kein Bild.
    const geladen = await page.evaluate(() => document.fonts.check('800 100px "Figtree"'));
    if (!geladen) throw new Error("Die Schrift Figtree ist nicht geladen (fonts.googleapis.com erreichbar?)");
    const ziel = join(OUT, `${g.praefix}${String(text.nummer).padStart(2, "0")}-${text.quelle}.jpg`);
    writeFileSync(ziel, await page.screenshot({ type: "jpeg", quality: 92 }));
    console.log(`  ✓ ${ziel}`);
    gesetzt++;
  }
  await page.close();
}
await browser.close();
console.log(`${gesetzt} Bilder gesetzt${fehlt ? `, ${fehlt} Quellen fehlen` : ""}.`);
process.exit(fehlt ? 1 : 0);
