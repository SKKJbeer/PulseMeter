/* Bedienung bei Fehlern, im Klick-Dummy: Was sagt der Ziffernblock, wenn
 * jemand nichts, zu wenig, zu viel oder dasselbe eintippt — und was bleibt
 * gesichert, wenn er abbricht?
 *
 * **Warum es das gibt.** Die Rückfragen im Ziffernblock sind der wichtigste
 * Schutz vor dem häufigsten Datenfehler, dem Tippfehler. PulseCore rechnet sie
 * geprüft aus, aber bis 0.149.0 hat keine Prüfung je den Satz gelesen, der am
 * Ende auf dem Schirm steht. So stand monatelang „rund 0× dein üblicher
 * Verbrauch“ da, wenn jemand den letzten Stand übernahm — richtig gerechnet,
 * unverständlich gesagt. Dieselben Fälle prüft `AppUITests/BedienungTests.swift`
 * in der App; hier laufen sie in Sekunden und ohne Mac.
 *
 * Geprüft wird jeder Zweig von `judge()` einmal, dazu:
 *   - kein Satz mit einem Faktor („×“): zwei Mengen statt einer Rechnung
 *   - jede Rückfrage lässt sichern (nachfragen, nicht verbieten)
 *   - die Rückfrage „unter dem letzten Wert“ hat eine Antwort (Prinzip 4)
 *   - „Abbrechen“ sichert nichts
 *
 * Aufruf: node scripts/check-bedienung.mjs [pfad-oder-url]
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
const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
const jsErrors = [];
page.on("pageerror", e => jsErrors.push(e.message));
await page.goto(url);
await page.waitForTimeout(400);
await page.evaluate(() => { bewertungGefragt = true; });

const vorher = await page.evaluate(() =>
  METERS.find(m => m.id === "strom").registers[0].readings.length);

await page.locator('[data-capture="strom"]').first().click();
await page.waitForTimeout(250);

const lage = () => page.evaluate(() => ({
  text: document.getElementById("verdict").innerText.replace(/\s+/g, " ").trim(),
  gesperrt: document.getElementById("save").disabled,
  wechsel: document.querySelectorAll("#verdict [data-meterchange]").length
}));
/** Setzt einen Stand so, wie ihn der Ziffernblock setzen würde. */
const tippe = wert => page.evaluate(w => {
  digits = String(Math.round(w * 10 ** capRegister().frac));
  drawCounter(); judge();
}, wert);
const letzter = await page.evaluate(() => capRegister().readings.slice(-1)[0].value);
const saetze = [];

// 1. Nichts eingetippt.
let l = await lage();
note(l.gesperrt && /Zählerstand eintippen/.test(l.text),
     `Ohne Zahl ist „Sichern“ gesperrt und der Hinweis sagt, was fehlt („${l.text}“)`);

// 2. Den letzten Stand unverändert übernehmen — der Fall, der „rund 0×“ ergab.
await page.locator("#prefill").click();
await page.waitForTimeout(100);
l = await lage();
saetze.push(l.text);
note(/^Derselbe Stand wie vor (einem Tag|\d+ Tagen)\. Stimmt die Zahl\?$/.test(l.text),
     `Unveränderter Stand: Rückfrage in Tagen („${l.text}“)`);
note(!l.gesperrt, "… und lässt sich trotzdem sichern");

// 3. Eine Stelle zu wenig: unter dem letzten Wert.
await tippe(Math.floor(letzter / 10));
l = await lage();
saetze.push(l.text);
note(/unter dem letzten Wert/.test(l.text) && /Ziffer verirrt/.test(l.text),
     `Zu klein: Rückfrage nennt den letzten Wert und den Tippfehler („${l.text.slice(0, 70)}…“)`);
note(l.wechsel === 1, "… mit der Antwort „Der Zähler wurde gewechselt“");
note(!l.gesperrt, "… und lässt sich trotzdem sichern");

// 4. Eine Stelle zu viel: zwei Mengen, kein Faktor.
const kapazitaet = await page.evaluate(() => 10 ** capRegister().int);
await tippe(Math.min(letzter + 20000, kapazitaet - 1));
l = await lage();
saetze.push(l.text);
note(/^Das wären [\d.]+ \S+ in (einem Tag|\d+ Tagen), sonst sind es rund [\d.]+ \S+\. Stimmt die Zahl\?$/.test(l.text),
     `Zu groß: eingetippte und übliche Menge nebeneinander („${l.text}“)`);
note(!l.gesperrt, "… und lässt sich trotzdem sichern");

// 5. Ein gewöhnlicher Stand: Gesucht wird ein Zuwachs, den die Prüfung als
//    normal bestätigt — es muss ihn geben, sonst beanstandet sie alles.
let normal = null;
for (const zuwachs of [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000]) {
  await tippe(letzter + zuwachs);
  l = await lage();
  if (/normal für dich/.test(l.text)) { normal = l; break; }
}
note(normal !== null, `Ein gewöhnlicher Zuwachs wird bestätigt („${normal ? normal.text : "keiner gefunden"}“)`);

note(saetze.every(s => !s.includes("×")),
     "Keine Rückfrage rechnet in Vielfachen („×“)");

// 6. Abbrechen sichert nichts — auch nicht mit einer Zahl im Ziffernblock.
await page.locator("#cap-back").click();
await page.waitForTimeout(250);
const nachher = await page.evaluate(() =>
  METERS.find(m => m.id === "strom").registers[0].readings.length);
note(nachher === vorher, `„Abbrechen“ sichert nichts (${vorher} Ablesungen vorher, ${nachher} nachher)`);

note(jsErrors.length === 0, "Keine Skriptfehler" + (jsErrors.length ? ": " + jsErrors.join("; ") : ""));

await browser.close();
if (failures.length) {
  console.log(`\n${failures.length} Prüfung(en) fehlgeschlagen.`);
  process.exit(1);
}
console.log("\nBedienung bei Fehlern: alles in Ordnung.");
