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
  const r = Reader.propose(texte, { int: f.format[0], frac: f.format[1] }, f.bereich ? f.bereich.map(Number) : null, !!f.eingerahmt);
  const ok = f.erwartet.wert !== undefined
    ? r.proposal && r.proposal.value === Number(f.erwartet.wert)
    : r.none === f.erwartet.keine;
  if (!ok) { falsch++; console.error(`✗ ${f.name}: erwartet ${JSON.stringify(f.erwartet)}, bekommen ${JSON.stringify(r)}`); }
}
if (falsch) { console.error(`Kamera-Leser im Klick-Dummy: ${falsch} von ${faelle.length} Fällen weichen von Swift ab.`); process.exit(1); }
console.log(`Kamera-Leser im Klick-Dummy: ${faelle.length} Fälle, identisch zu Swift.`);

// Einigung über mehrere Bilder: dieselben Folgen wie in Swift (ReadingConsensus).
{
  const a = html.indexOf("/* ReadingConsensus:start"), b = html.indexOf("/* ReadingConsensus:end */");
  if (a < 0 || b < 0) { console.error("✗ Marken für ReadingConsensus fehlen im Klick-Dummy"); process.exit(1); }
  const Konsens = new Function(html.slice(a, b) + "\nreturn ReadingConsensus;")();
  const folgen = JSON.parse(readFileSync(join(wurzel, "docs/kamera/vektoren.json"), "utf8")).einigung;
  let schlecht = 0;
  for (const f of folgen) {
    const k = Konsens.neu(f.required, f.window); let einig = null;
    for (const w of f.folge) einig = k.add(w === null ? { none: "noCandidate" } : { proposal: { value: Number(w) } });
    const ist = einig ? String(einig.proposal.value) : null;
    if (ist !== f.erwartet) { schlecht++; console.error(`✗ Einigung ${f.name}: erwartet ${f.erwartet}, bekommen ${ist}`); }
  }
  if (schlecht) process.exit(1);
  console.log(`Einigung im Klick-Dummy: ${folgen.length} Folgen, identisch zu Swift.`);
}

// Zuordnung zum Zählwerk: dieselben Fälle wie in Swift (RegisterChoice).
{
  const a = html.indexOf("/* RegisterChoice:start"), b = html.indexOf("/* RegisterChoice:end */");
  if (a < 0 || b < 0) { console.error("✗ Marken für RegisterChoice fehlen im Klick-Dummy"); process.exit(1); }
  const Wahl = new Function(html.slice(a, b) + "\nreturn RegisterChoice;")();
  const faelle = JSON.parse(readFileSync(join(wurzel, "docs/kamera/vektoren.json"), "utf8")).zuordnung;
  let schlecht = 0;
  for (const f of faelle) {
    const ist = Wahl.check(Number(f.wert), f.andere.map(r => r && r.map(Number)));
    if (ist !== f.erwartet) { schlecht++; console.error(`✗ Zuordnung ${f.name}: erwartet ${f.erwartet}, bekommen ${ist}`); }
  }
  if (schlecht) process.exit(1);
  console.log(`Zuordnung im Klick-Dummy: ${faelle.length} Fälle, identisch zu Swift.`);
}

// Kamera Stufe 2: Kennzahl, Zuordnung und Einigung mit Kennzahl, dieselben Fälle wie in Swift.
{
  const a = html.indexOf("/* RegisterChoice:start"), b = html.indexOf("/* RegisterChoice:end */");
  const c = html.indexOf("/* ReadingConsensus:start"), d = html.indexOf("/* ReadingConsensus:end */");
  const e = html.indexOf("/* RegisterAssignment:start"), f = html.indexOf("/* RegisterAssignment:end */");
  if (e < 0 || f < 0) { console.error("✗ Marken für RegisterAssignment fehlen im Klick-Dummy"); process.exit(1); }
  const M = new Function(html.slice(a, b) + "\n" + html.slice(c, d) + "\n" + html.slice(e, f)
    + "\nreturn { ObisCode, RegisterAssignment, LabeledConsensus };")();
  const vek = JSON.parse(readFileSync(join(wurzel, "docs/kamera/vektoren.json"), "utf8"));
  let schlecht = 0;
  for (const k of vek.kennzahl) {
    const ist = M.ObisCode.read(k.text);
    if (ist !== k.erwartet) { schlecht++; console.error(`✗ Kennzahl „${k.text}“: erwartet ${k.erwartet}, bekommen ${ist}`); }
  }
  for (const z of vek.zuweisung) {
    const ist = M.RegisterAssignment.decide(Number(z.wert), z.kennzahl, z.gefragt, z.kennzahlen, z.bereiche.map(r => r && r.map(Number)));
    if (ist !== z.erwartet) { schlecht++; console.error(`✗ Zuweisung ${z.name}: erwartet ${z.erwartet}, bekommen ${ist}`); }
  }
  for (const g of vek.kennzahl_einigung) {
    const k = M.LabeledConsensus.neu(); let last = null;
    for (const [w, code] of g.folge) last = k.add(w === null ? { none: "noCandidate" } : { proposal: { value: Number(w) } }, code);
    const ist = last ? `${last.reading.proposal.value}|${last.code || ""}` : null;
    if (ist !== g.erwartet) { schlecht++; console.error(`✗ Einigung mit Kennzahl ${g.name}: erwartet ${g.erwartet}, bekommen ${ist}`); }
  }
  if (schlecht) process.exit(1);
  console.log(`Kennzahl im Klick-Dummy: ${vek.kennzahl.length + vek.zuweisung.length + vek.kennzahl_einigung.length} Fälle, identisch zu Swift.`);
}

// Ziffernnetz: dieselbe Rechnung wie in Swift und Python, an denselben Referenzwerten.
const blockVon = (marke) => {
  const a = html.indexOf(`/* ${marke}:start`), b = html.indexOf(`/* ${marke}:end */`);
  if (a < 0 || b < 0) { console.error(`✗ Marken für ${marke} fehlen im Klick-Dummy`); process.exit(1); }
  return html.slice(a, b);
};
const Netz = new Function(blockVon("ZIFFERNNETZ") + "\n" + blockVon("DigitNet") + "\nreturn { DigitNet, ZIFFERNNETZ_B64 };")();
const { DigitNet, ZIFFERNNETZ_B64 } = Netz;
const lcd = JSON.parse(readFileSync(join(wurzel, "docs/kamera/lcd-vektoren.json"), "utf8"));
const bytesVon = (b64) => Uint8Array.from(Buffer.from(b64, "base64"));
let netzFalsch = 0;

const v = lcd.verkleinern;
const klein = DigitNet.verkleinern(bytesVon(v.pixel), v.breite, v.hoehe, v.rechteck, v.ziel[0], v.ziel[1]);
const abw = Math.max(...klein.map((x, i) => Math.abs(x - v.erwartet[i])));
if (!(abw < 1e-4)) { netzFalsch++; console.error(`✗ Verkleinern weicht um ${abw} von Python ab`); }

const Ts = ZIFFERNNETZ_B64.map((b) => DigitNet.ladeGewichte(b));
for (const f of lcd.faelle) {
  const px = Float32Array.from(bytesVon(f.pixel), (b) => b / 255);
  if (f.texte.length !== Ts.length) { netzFalsch++; console.error(`✗ ${f.name}: ${f.texte.length} Netze in den Referenzwerten, ${Ts.length} im Klick-Dummy`); continue; }
  Ts.forEach((T, i) => {
    const out = DigitNet.laufen(T, px), zeile = DigitNet.lesen(out);
    const ref = f.ausgaben && f.ausgaben[i];
    if (ref) {
      const w = Math.max(...ref.map((x, k) => Math.abs(x - out.werte[k])));
      if (!(w < 0.01)) { netzFalsch++; console.error(`✗ ${f.name}, Netz ${i}: Ausgabe weicht um ${w} von Python ab`); }
    }
    if (zeile.text !== f.texte[i] || Math.abs(zeile.sicherheit - f.sicherheiten[i]) > 0.01) {
      netzFalsch++; console.error(`✗ ${f.name}, Netz ${i}: gelesen „${zeile.text}“ (${zeile.sicherheit.toFixed(3)}), Python „${f.texte[i]}“ (${f.sicherheiten[i]})`);
    }
  });
  const ens = DigitNet.lesenEnsemble(Ts, px);
  if (ens.text !== f.text || Math.abs(ens.sicherheit - f.sicherheit) > 0.01) {
    netzFalsch++; console.error(`✗ ${f.name}: Ensemble „${ens.text}“ (${ens.sicherheit.toFixed(3)}), Python „${f.text}“ (${f.sicherheit})`);
  }
}
if (netzFalsch) { console.error(`Ziffernnetz im Klick-Dummy: ${netzFalsch} Abweichungen von Python.`); process.exit(1); }
console.log(`Ziffernnetz im Klick-Dummy: ${lcd.faelle.length} Fälle, identisch zu Python und Swift.`);
