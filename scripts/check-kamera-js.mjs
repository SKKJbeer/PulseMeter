#!/usr/bin/env node
// Lässt die JavaScript-Fassung des Kamera-Lesers im Klick-Dummy gegen dieselben
// Fälle laufen wie die Swift-Fassung (docs/kamera/vektoren.json). Zwei Fassungen
// derselben Regeln laufen sonst auseinander, ohne dass es jemand merkt — in
// diesem Projekt hat jede Runde am Prototyp einen echten Fehler im Rechenkern
// gefunden (CLAUDE.md, Regel 2).
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const wurzel = join(dirname(fileURLToPath(import.meta.url)), "..");
const html = readFileSync(join(wurzel, "docs/prototype/index.html"), "utf8");
const von = html.indexOf("/* MeterTextReader:start");
const bis = html.indexOf("/* MeterTextReader:end */");
if (von < 0 || bis < 0) { console.error("✗ Marken für MeterTextReader fehlen im Klick-Dummy"); process.exit(1); }
const Reader = new Function(html.slice(von, bis) + "\nreturn MeterTextReader;")();

const { faelle } = JSON.parse(readFileSync(join(wurzel, "docs/kamera/vektoren.json"), "utf8"));
let falsch = 0;
for (const f of faelle) {
  const texte = f.texte.map(([text, confidence]) => ({ text, confidence }));
  const r = Reader.propose(texte, { int: f.format[0], frac: f.format[1] }, f.bereich ? f.bereich.map(Number) : null);
  const ok = f.erwartet.wert !== undefined
    ? r.proposal && r.proposal.value === Number(f.erwartet.wert)
    : r.none === f.erwartet.keine;
  if (!ok) { falsch++; console.error(`✗ ${f.name}: erwartet ${JSON.stringify(f.erwartet)}, bekommen ${JSON.stringify(r)}`); }
}
if (falsch) { console.error(`Kamera-Leser im Klick-Dummy: ${falsch} von ${faelle.length} Fällen weichen von Swift ab.`); process.exit(1); }
console.log(`Kamera-Leser im Klick-Dummy: ${faelle.length} Fälle, identisch zu Swift.`);
