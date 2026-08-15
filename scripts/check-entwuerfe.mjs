/* Prüft die Entwürfe unter `docs/entwuerfe/` headless.
 *
 * **Warum ein Entwurf geprüft wird.** Ein Vorschlag, der beim Antippen nichts
 * tut, ist kein Vorschlag — und ob er etwas tut, sieht man einem Bild nicht an.
 * Beim ersten Lauf hat diese Prüfung genau das gefunden: Variante A reagierte
 * bei 360 Pixeln nicht. Es lag an der Prüfung selbst (die Seite war gescrollt,
 * die Maus zielte ins Leere) — aber gesucht hätte man sonst am Entwurf.
 *
 * Aufruf:  node scripts/check-entwuerfe.mjs
 */
import { chromium } from "playwright";
const b = await chromium.launch({ executablePath: process.env.PULSE_CHROMIUM });
let fehler = 0;
const ok = (gut, text) => { console.log((gut ? "  ok   " : "  FEHL ") + text); if (!gut) fehler++; };

for (const scheme of ["light", "dark"]) {
  for (const breite of [360, 1280]) {
    const p = await b.newPage({ viewport: { width: breite, height: 1000 }, colorScheme: scheme });
    const js = [];
    p.on("pageerror", e => js.push(e.message));
    p.on("console", m => { if (m.type() === "error") js.push(m.text()); });
    await p.goto("file://" + process.cwd() + "/docs/entwuerfe/zaehlereingabe.html");
    await p.waitForTimeout(200);
    console.log(`\n== ${scheme} @ ${breite}`);

    // B: 185395 eintippen -> 18.539,5
    for (const z of "185395") await p.click(`#b-block [data-t="${z}"]`);
    await p.waitForTimeout(120);
    const bText = (await p.locator("#b-zahl").innerText()).replace(/\s/g, "");
    ok(bText.startsWith("18.539,5"), `B zeigt ${bText}`);
    ok(/kWh in 34 Tagen/.test(await p.locator("#b-urteil").innerText()), "B urteilt über den Verbrauch");
    ok(!(await p.locator("#b-sichern").isDisabled()), "B lässt sichern");

    // C: nur den Rest, 5395 -> 18539,5
    for (const z of "5395") await p.click(`#c-block [data-t="${z}"]`);
    await p.waitForTimeout(120);
    const cGanz = (await p.locator("#c-fest").innerText()) + (await p.locator("#c-neu").innerText()) + (await p.locator("#c-frac").innerText());
    ok(cGanz.replace(/\s/g, "") === "18539,5", `C zeigt ${cGanz}`);
    ok(/67,2 kWh/.test(await p.locator("#c-verbrauch").innerText()), "C nennt den Verbrauch: " + await p.locator("#c-verbrauch").innerText());

    // C: Notausgang
    await p.click("#c-mehr");
    await p.waitForTimeout(80);
    ok((await p.locator("#c-fest").innerText()).trim() === "", "C blendet die festen Stellen aus");
    await p.click("#c-mehr");

    // A: eine Walze antippen (obere Hälfte = hoch)
    const vorher = await p.locator("#a-urteil").innerText();
    const w = p.locator("#a-walzen .walze").nth(4);
    await w.scrollIntoViewIfNeeded();
    await p.waitForTimeout(80);
    const box = await w.boundingBox();
    await p.mouse.move(box.x + box.width / 2, box.y + 8);
    await p.mouse.down(); await p.mouse.up();
    await p.waitForTimeout(250);
    ok((await p.locator("#a-urteil").innerText()) !== vorher, "A reagiert auf einen Tipp");

    // Rückwärts: kleiner als der letzte Stand
    await p.click('#b-block [data-t="c"]');
    for (const z of "100000") await p.click(`#b-block [data-t="${z}"]`);
    await p.waitForTimeout(120);
    ok(/Kleiner als der letzte Stand/.test(await p.locator("#b-urteil").innerText()), "B erkennt einen Rückwärtsstand");
    ok(await p.locator("#b-sichern").isDisabled(), "B sperrt das Sichern dann");

    const ueber = await p.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    ok(ueber <= 1, `kein horizontaler Überlauf (${ueber} px)`);
    ok(js.length === 0, js.length ? "JS-Fehler: " + js[0] : "keine JavaScript-Fehler");
    await p.close();
  }
}
await b.close();
console.log(fehler ? `\n${fehler} gefallen` : "\nAlles grün");
process.exit(fehler ? 1 : 0);
