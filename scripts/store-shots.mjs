#!/usr/bin/env node
/* Baut aus den Simulator-Bildern die Bilder für den App Store.
 *
 * **Warum gesetzt und nicht roh eingereicht.** Ein nacktes Bildschirmfoto
 * beantwortet die Frage nicht, die jemand im Store stellt: Was habe ich davon?
 * Die Überschrift beantwortet sie, das Bild belegt sie. Nackt eingereichte
 * Bilder sind das häufigste Kennzeichen einer Ein-Personen-App — und der
 * Grund, warum sie übersehen wird.
 *
 * **Warum ein Skript.** Die Bilder ändern sich bei jeder Oberflächenänderung.
 * Von Hand gesetzte müsste man jedes Mal neu setzen, also setzt man sie
 * irgendwann nicht mehr neu — und im Store steht eine App, die es so nicht
 * mehr gibt.
 *
 * Aufruf (auf einem Mac, nach `scripts/run.sh`):
 *     node scripts/store-shots.mjs
 * Ergebnis: build/appstore/*.png in der von Apple verlangten Größe.
 *
 * Quelle sind die **PNG**-Dateien aus `build/`, nicht die verkleinerten JPEGs
 * aus dem Zweig `screenshots`. Der Store nimmt exakte Pixelmaße; ein
 * hochskaliertes Bild sieht man sofort.
 */
import { chromium } from "playwright";
import { existsSync, mkdirSync, readFileSync } from "node:fs";

const IN = process.argv[2] || "build";
const OUT = "build/appstore";

/* 6,9 Zoll ist seit 2024 das einzige Pflichtmaß fürs iPhone; Apple rechnet
 * die kleineren Geräte selbst herunter. Ein zweites Maß mitzuliefern hieße,
 * jede Änderung doppelt zu pflegen. */
const CANVAS = { width: 1320, height: 2868 };

/* Die Reihenfolge ist die Verkaufsreihenfolge.
 *
 * Die ersten beiden Bilder sind die einzigen, die in der Suchliste erscheinen
 * — sie müssen allein tragen. Deshalb steht vorn nicht der Funktionsumfang,
 * sondern das Versprechen (»sagt dir, ob alles im Rahmen ist«) und der
 * Moment, an dem es sich einlöst (die Erfassung im Keller).
 *
 * Das letzte Bild ist bewusst der Preis: Wer bis dahin gewischt hat, will
 * wissen, was es kostet — und »kein Abo« ist hier das stärkste Argument. */
const SHOTS = [
  {
    file: "screenshot-light.png",
    headline: "Eine Zahl eintragen.\nDen Rest macht die App.",
    sub: "Verbrauch, Kosten und Vergleich zum Vorjahr — auf einen Blick."
  },
  {
    file: "screenshot-capture-light.png",
    headline: "Ablesen dauert\nzehn Sekunden.",
    sub: "Großer Ziffernblock statt Tastatur. Die App merkt, wenn eine Ziffer verrutscht ist."
  },
  {
    file: "screenshot-verlauf-light.png",
    headline: "Sieh, wohin\nes geht.",
    sub: "Monat, Quartal, Jahr — und der Vergleich mit demselben Zeitraum im Vorjahr."
  },
  {
    file: "screenshot-bericht-light.png",
    headline: "Ein Dokument,\ndas jeder versteht.",
    sub: "Für die Jahresabrechnung, den Vermieter oder das Finanzamt."
  },
  {
    file: "screenshot-dark.png",
    headline: "Deine Daten\nbleiben deine.",
    sub: "Kein Konto. Kein Tracking. Export als Tabelle — dauerhaft kostenlos."
  },
  {
    file: "screenshot-pro-light.png",
    headline: "Einmal kaufen.\nKein Abo.",
    sub: "Zwei Zähler sind für immer frei. Pro schaltet den Rest frei — einmalig."
  }
];

/* Das Gerät wird angedeutet, nicht nachgebaut.
 *
 * Apple verbietet keine Rahmen, aber ein falsch gezeichnetes iPhone sieht
 * billiger aus als gar keines — und veraltet mit dem nächsten Modell. Ein
 * abgerundetes Rechteck mit Schatten genügt: Es sagt »Telefon«, ohne eines
 * zu behaupten. */
function page(shot, dataURI) {
  return `<!doctype html><html><head><meta charset="utf-8"><style>
  *{margin:0;padding:0;box-sizing:border-box}
  html,body{width:${CANVAS.width}px;height:${CANVAS.height}px;overflow:hidden}
  body{
    background:linear-gradient(168deg,#241F16 0%,#17150F 46%,#12100C 100%);
    font-family:-apple-system,"SF Pro Display","Helvetica Neue",Helvetica,Arial,sans-serif;
    display:flex;flex-direction:column;align-items:center;
    padding:150px 96px 0;
  }
  /* Ein Hauch Bernstein hinter dem Gerät. Ohne ihn steht das Bild auf
     einer grauen Fläche und wirkt wie ein Beleg statt wie ein Angebot. */
  .glow{
    position:absolute;left:50%;top:940px;transform:translateX(-50%);
    width:1500px;height:1500px;border-radius:50%;
    background:radial-gradient(circle,rgba(224,160,64,.20) 0%,rgba(224,160,64,0) 62%);
  }
  h1{
    position:relative;
    /* 92 statt 104: Bei 104 lief die zweite Zeile trotz gesetztem Umbruch
       ein drittes Mal um, und eine dreizeilige Überschrift liest im Store
       niemand mehr. Die Breite ist zusätzlich begrenzt, damit der Umbruch
       dort sitzt, wo er gesetzt ist, und nicht dort, wo er gerade passt. */
    font-size:92px;line-height:1.12;font-weight:700;letter-spacing:-1.5px;
    color:#F7F3EA;text-align:center;white-space:pre-line;max-width:1080px;
  }
  p{
    position:relative;
    margin-top:34px;font-size:44px;line-height:1.34;font-weight:400;
    color:#B9AF9C;text-align:center;max-width:1000px;
  }
  .device{
    position:relative;margin-top:96px;
    border-radius:64px;overflow:hidden;
    box-shadow:0 60px 120px rgba(0,0,0,.55), 0 0 0 14px #2A251C, 0 0 0 16px #4A4132;
  }
  .device img{display:block;width:1000px}
  </style></head><body>
  <div class="glow"></div>
  <h1>${shot.headline}</h1>
  <p>${shot.sub}</p>
  <div class="device"><img src="${dataURI}"></div>
  </body></html>`;
}

/* PNG bevorzugt, JPEG als Rückfall.
 *
 * Der Store bekommt die PNGs aus `build/`. Der Rückfall existiert, damit sich
 * das Skript auch gegen die verkleinerten Bilder aus dem Zweig `screenshots`
 * ausprobieren lässt — dort liegen sie als JPEG, und ohne diesen Weg ließe
 * sich der Aufbau ohne Mac gar nicht ansehen. Für die Einreichung taugen sie
 * nicht: Der Store nimmt exakte Pixelmaße, und Hochskaliertes sieht man. */
function source(file) {
  for (const candidate of [`${IN}/${file}`, `${IN}/${file.replace(/\.png$/, ".jpg")}`]) {
    if (existsSync(candidate)) {
      return { path: candidate, mime: candidate.endsWith(".png") ? "image/png" : "image/jpeg" };
    }
  }
  return null;
}

const missing = SHOTS.filter(s => !source(s.file)).map(s => s.file);
if (missing.length === SHOTS.length) {
  console.error(`Keine Bilder in ${IN}/ gefunden. Erst \`scripts/run.sh\` laufen lassen —`);
  console.error("und zwar auf einem Mac, denn die Bilder entstehen im Simulator.");
  process.exit(1);
}
if (missing.length) console.warn(`Übersprungen, weil nicht vorhanden: ${missing.join(", ")}`);

mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.PULSE_CHROMIUM || undefined });
const view = await browser.newPage({ viewport: CANVAS, deviceScaleFactor: 1 });

let n = 0;
for (const shot of SHOTS) {
  const found = source(shot.file);
  if (!found) continue;
  const dataURI = `data:${found.mime};base64,` + readFileSync(found.path).toString("base64");
  await view.setContent(page(shot, dataURI));
  await view.waitForTimeout(120);
  n += 1;
  const name = `${OUT}/${String(n).padStart(2, "0")}-${shot.file.replace(/^screenshot-|\.png$/g, "")}.png`;
  await view.screenshot({ path: name });
  console.log(`  ${name}`);
}
await browser.close();
console.log(`\n${n} Bilder in ${CANVAS.width}×${CANVAS.height} — das Maß für 6,9 Zoll.`);
console.log("Apple rechnet die kleineren Geräte selbst herunter.");
