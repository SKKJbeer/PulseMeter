/* Prüft das gebündelte Abbild der Website, bevor es veröffentlicht wird.
 *
 * **Warum getrennt von `check-website.mjs`.** Das Bündel ist eine andere Datei
 * als die Website: Der Stil steckt in einem `<style>`, die Bilder stecken als
 * Datenadressen darin, und aus sechs Seiten ist eine geworden. Genau bei
 * diesem Umbau geht etwas kaputt, das die Website selbst nicht hat — ein
 * `srcset`, das nicht mit ersetzt wurde, zeigt sich erst im dunklen
 * Erscheinungsbild, und ein Verweis auf `hilfe.html` läuft ins Leere, wenn die
 * Umschreibung auf `#v-hilfe` ihn verfehlt hat. Beides wäre in der
 * Veröffentlichung sichtbar und hier nicht mehr zu ändern.
 *
 * Aufruf:  node scripts/check-buendel.mjs <datei>
 */
import { chromium } from "playwright";
const datei = process.argv[2];
const b = await chromium.launch({ executablePath: process.env.PULSE_CHROMIUM });
let schlecht = 0;
for (const scheme of ["light", "dark"]) {
  for (const breite of [320, 768, 1280]) {
    const p = await b.newPage({ viewport: { width: breite, height: 900 }, colorScheme: scheme });
    const fremd = [], fehler = [];
    p.on("request", r => { if (!r.url().startsWith("file:") && !r.url().startsWith("data:")) fremd.push(r.url()); });
    p.on("pageerror", e => fehler.push(e.message));
    await p.goto("file://" + datei);
    await p.waitForTimeout(300);
    const ueber = await p.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    const ids = await p.evaluate(() => [...document.querySelectorAll("section.v-seite")].map(s => s.id));
    const leer = await p.evaluate(() => [...document.images].filter(i => !i.naturalWidth).length);
    const tote = await p.evaluate(() => [...document.querySelectorAll('a[href^="#"]')]
      .map(a => a.getAttribute("href")).filter(h => h.length > 1 && !document.querySelector(h)));
    const ok = ueber <= 1 && fremd.length === 0 && fehler.length === 0 && ids.length === 6 && leer === 0 && tote.length === 0;
    if (!ok) schlecht++;
    console.log(`${ok ? "ok  " : "FEHL"} ${scheme} ${breite}: Überlauf ${ueber}px, ${ids.length} Abschnitte, ${leer} leere Bilder, tote Marken ${tote.join(",") || "keine"}, fremd ${fremd[0] || "keine"}, JS ${fehler[0] || "keine"}`);
    await p.close();
  }
}
await b.close();
process.exit(schlecht ? 1 : 0);
