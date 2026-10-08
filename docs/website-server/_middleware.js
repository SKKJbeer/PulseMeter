// Zählt Seitenaufrufe auf dem Server — ohne Cookie, ohne Skript im Browser,
// ohne IP-Adresse.
//
// **Warum auf dem Server und nicht im Browser.** Die Website verspricht keine
// Cookies, keine Zählpixel und kein Zustimmungsfenster, und `check-website.mjs`
// prüft, dass keine einzige Anfrage an einen fremden Server geht. Ein
// Analysewerkzeug im Browser bräche beides. Hier läuft nichts beim Besucher:
// Cloudflare liefert die Seite ohnehin aus, und diese Funktion schreibt dabei
// eine Zeile mit fünf groben Angaben mit.
//
// **Was gespeichert wird, und was nicht.** Die Seite, der Name der Website,
// von der jemand kam (nur der Name, nicht die Adresse), das Land, die Art des
// Geräts und eine selbst gesetzte Quelle aus `?von=`. Nicht gespeichert werden
// IP-Adresse, Browserkennung, genaue Herkunftsadresse und alles, was einen
// Besuch einem Menschen zuordnen könnte. Die Datenschutzerklärung sagt genau
// das; wer hier eine Angabe ergänzt, ändert sie im selben Zug.
//
// **Die Seite geht vor.** Scheitert die Zählung, wird trotzdem ausgeliefert.
// Eine Website, die wegen einer Statistik nicht lädt, wäre ein schlechter
// Tausch.

const SEITEN = new Set([
  "/", "/ratgeber", "/verbrauch-berechnen", "/stromkosten-berechnen", "/stromverbrauch-vergleichen", "/jahresarbeitszahl-berechnen", "/zaehlerstand-ablesen", "/gas-in-kwh",
  "/zaehlerstand-umzug", "/entwicklung", "/hilfe", "/datenschutz", "/impressum",
]);

// Wer uns besucht, ohne Mensch zu sein. Getrennt gezählt, weil gerade das eine
// Antwort ist: ob Google die Seite überhaupt holt.
const BOTS = [
  [/Googlebot|Google-InspectionTool|GoogleOther/i, "Bot: Google"],
  [/bingbot|BingPreview/i, "Bot: Bing"],
  [/Applebot/i, "Bot: Apple"],
  [/DuckDuckBot/i, "Bot: DuckDuckGo"],
  [/YandexBot/i, "Bot: Yandex"],
  [/bot|crawl|spider|slurp|preview|facebookexternalhit|curl|wget|python|headless/i, "Bot: andere"],
];

export function seite(pfad, status) {
  if (status === 404) return "404";
  const p = pfad.replace(/\.html$/, "").replace(/\/index$/, "/").replace(/(.)\/$/, "$1");
  return SEITEN.has(p) ? p : "andere";
}

export function geraet(kennung) {
  const k = kennung || "";
  for (const [muster, name] of BOTS) if (muster.test(k)) return name;
  if (/iPad|Tablet|Android(?!.*Mobile)/i.test(k)) return "Tablet";
  if (/Mobi|iPhone|Android/i.test(k)) return "Telefon";
  return "Rechner";
}

export function herkunft(verweis, eigenerName) {
  if (!verweis) return "direkt";
  try {
    const name = new URL(verweis).hostname.replace(/^www\./, "");
    if (name === eigenerName) return "intern";
    // Google hat je Land einen Namen; für die Frage „kommt es über Google"
    // ist google.de dasselbe wie google.com.
    return name.replace(/^(google)\.[a-z.]+$/, "$1");
  } catch {
    return "unlesbar";
  }
}

// `?von=reddit` in einem selbst geteilten Verweis. Nur Kleinbuchstaben,
// Ziffern und Bindestrich, höchstens 30 Zeichen: Das Feld ist für ein
// Kennwort gedacht, nicht für Freitext.
export function quelle(url) {
  const roh = url.searchParams.get("von") || url.searchParams.get("utm_source") || "";
  return roh.toLowerCase().replace(/[^a-z0-9-]/g, "").slice(0, 30);
}

// **Eine Adresse, nicht drei.** Seit dem 3. Oktober steht die Website unter
// `zaehlora.de`. `zaehlora.pages.dev` und `www.zaehlora.de` liefern sonst
// dieselben Seiten noch einmal aus, und eine Suchmaschine sähe drei Kopien.
// `canonical` sagt schon, welche gilt; die 301 sagt es auch Menschen und alten
// Verweisen, mit dem ganzen Pfad. Vorschauadressen wie
// `abc123.zaehlora.pages.dev` bleiben, wie sie sind: Mit ihnen prüft man einen
// Stand, bevor er gilt.
export const ADRESSE = "zaehlora.de";
const UMLEITEN = new Set(["zaehlora.pages.dev", "www.zaehlora.de"]);

// **Seiten, die es nicht mehr gibt, zeigen auf ihren Nachfolger.** Der
// Abschlagsrechner ist am 4. Oktober im Stromkostenrechner aufgegangen; zwei
// fast gleiche Rechner nebeneinander hat der Gründer zu Recht „doppelt"
// genannt. Wer einem alten Verweis folgt, landet beim Abschnitt zum Abschlag.
const UMGEZOGEN = {
  "/abschlag-zu-hoch": "/stromkosten-berechnen#abschlag",
  "/abschlag-zu-hoch.html": "/stromkosten-berechnen#abschlag",
};

export function umleitung(url) {
  if (UMLEITEN.has(url.hostname)) {
    const pfad = UMGEZOGEN[url.pathname] || url.pathname;
    return `https://${ADRESSE}${pfad}${pfad.includes("#") ? "" : url.search}`;
  }
  const neu = UMGEZOGEN[url.pathname];
  return neu ? `${url.origin}${neu}` : null;
}

export async function onRequest(context) {
  const ziel = umleitung(new URL(context.request.url));
  if (ziel) return Response.redirect(ziel, 301);
  const roh = await context.next();
  // Eine eigene Antwort, weil die von `next()` unveränderlich sein kann. Die
  // drei Sicherheitsangaben aus `_headers` stehen hier noch einmal: Ob
  // Cloudflare `_headers` auch auf Antworten anwendet, die durch eine Funktion
  // laufen, ist nicht belegt, und die Zählung soll die Seiten nichts kosten.
  const antwort = new Response(roh.body, roh);
  if ((antwort.headers.get("content-type") || "").startsWith("text/html")) {
    antwort.headers.set("X-Content-Type-Options", "nosniff");
    antwort.headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
    antwort.headers.set("X-Frame-Options", "SAMEORIGIN");
    // Woran die Prüfung nach dem Hochladen sieht, dass die Funktion läuft.
    antwort.headers.set("X-Zaehlung", "ohne-personenbezug");
  }
  try {
    const art = antwort.headers.get("content-type") || "";
    const zaehlung = context.env && context.env.ZAEHLUNG;
    if (zaehlung && context.request.method === "GET" && art.startsWith("text/html")) {
      const url = new URL(context.request.url);
      zaehlung.writeDataPoint({
        blobs: [
          seite(url.pathname, antwort.status),
          herkunft(context.request.headers.get("referer"), url.hostname),
          (context.request.cf && context.request.cf.country) || "",
          geraet(context.request.headers.get("user-agent")),
          quelle(url),
        ],
        doubles: [1],
      });
    }
  } catch {
    // Siehe oben: Die Seite geht vor.
  }
  return antwort;
}
