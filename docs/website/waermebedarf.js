// Wärmebedarf-Rechner, eine Fassung für zwei Seiten: waermebedarf-berechnen.html
// und die Fassung zum Einbinden, rechner-waermebedarf.html. Beide tragen
// dieselben Felder mit denselben Kennungen. Zwei Kopien der Rechnung würden
// auseinanderlaufen, und ein Energieberater zeigte dann andere Zahlen als wir.
// Die Werte stammen aus dem Praxisleitfaden „Die Wärmepumpe im
// Einfamilienhaus“ des BürgerNetzwerkSolar Worms (März 2026, in Anlehnung
// an VDI 4645 und VDI 4650), Abschnitt 4. Genommen ist jeweils die Mitte
// der Spanne; die Spanne selbst steht in der Kachel, weil eine einzelne
// Zahl genauer aussähe, als die Methode ist.
window.HAUS = {
  unsaniert:   { name: "Unsanierter Altbau", von: 1800, bis: 2200, mitte: 2000 },
  teilsaniert: { name: "Teilsaniert",        von: 1500, bis: 1800, mitte: 1650 },
  saniert:     { name: "Sanierter Altbau",   von: 1300, bis: 1600, mitte: 1450 },
  neubau:      { name: "Neubau, KfW 40",     von: 900,  bis: 1200, mitte: 1050 }
};
// Nutzungsgrad: Wie viel von der Energie im Brennstoff als Wärme im Haus
// ankommt. Leitfaden: alter Standard- oder Niedertemperaturkessel 0,70 bis
// 0,80, Brennwertkessel 0,90 bis 0,95.
window.KESSEL = { alt: 0.75, brennwert: 0.92 };
// Die Jahresarbeitszahl ist der Schnitt der 61 Luft-Wärmepumpen im
// Feldtest „WP-QS im Bestand“ von Fraunhofer ISE, derselbe Wert wie auf
// jahresarbeitszahl-berechnen.html.
window.JAZ_LUFT = 3.4;
(function () {
  var R = window.Rechner;
  var ARTEN = {
    gas:    { einheit: "m³", faktor: "10,5", faktorEinheit: "kWh/m³", hinweis: "Zustandszahl × Brennwert", stoff: "Gas" },
    gaskwh: { einheit: "kWh", faktor: null, stoff: "Gas" },
    oel:    { einheit: "Liter", faktor: "10", faktorEinheit: "kWh/Liter", hinweis: "Heizwert, meist 10", stoff: "Heizöl" }
  };
  var form = document.getElementById("wb-rechner");
  function art() { return form.querySelector('input[name="wb-art"]:checked').value; }
  function wert(id) { return R.zahl(document.getElementById(id).value); }
  // Auf hundert gerundet: Die Rechnung ist eine Schätzung, und „17.388 kWh“
  // täte so, als wüsste sie es auf die Kilowattstunde.
  function hundert(n) { return Math.round(n / 100) * 100; }

  function umstellen() {
    var a = ARTEN[art()];
    document.getElementById("wb-einheit").textContent = a.einheit;
    document.getElementById("wb-faktor-feld").hidden = a.faktor === null;
    if (a.faktor !== null) {
      document.getElementById("wb-faktor").value = a.faktor;
      document.getElementById("wb-faktor-einheit").textContent = a.faktorEinheit;
      document.getElementById("wb-faktor-hinweis").textContent = a.hinweis;
    }
    rechne();
  }

  function rechne() {
    var a = ARTEN[art()], aus = document.getElementById("wb-ergebnis");
    var menge = wert("wb-menge"), faktor = a.faktor === null ? 1 : wert("wb-faktor");
    if (!(menge > 0) || !(faktor > 0)) {
      aus.innerHTML = R.hinweis("Trag deinen Verbrauch im Jahr ein.");
      return;
    }
    var haus = window.HAUS[document.getElementById("wb-haus").value];
    var brennstoff = menge * faktor;
    var waerme = brennstoff * window.KESSEL[document.getElementById("wb-kessel").value];
    aus.innerHTML = R.kacheln([
      R.kachel("waerme", "Wärme im Jahr", "≈ " + R.format(hundert(waerme), 0) + " kWh",
               "aus " + R.format(hundert(brennstoff), 0) + " kWh " + a.stoff, "haupt"),
      R.kachel("heizlast", "Heizlast grob", "≈ " + R.format(waerme / haus.mitte, 1) + " kW",
               "Spanne " + R.format(waerme / haus.bis, 1) + " bis " + R.format(waerme / haus.von, 1)),
      R.kachel("strom", "Strom mit Wärmepumpe", "≈ " + R.format(hundert(waerme / window.JAZ_LUFT), 0) + " kWh",
               "bei Jahresarbeitszahl " + R.format(window.JAZ_LUFT, 1))
    ]);
  }

  form.querySelectorAll('input[name="wb-art"]').forEach(function (r) { r.addEventListener("change", umstellen); });
  form.addEventListener("input", function (e) { if (e.target.name !== "wb-art") rechne(); });
  form.addEventListener("change", function (e) { if (e.target.tagName === "SELECT") rechne(); });
  umstellen();
})();
