// Gemeinsames für die Rechner im Ratgeber.
//
// **An einer Stelle, weil es an drei Stellen gebraucht wird.** Bis 0.117.0
// stand das Einlesen einer Zahl in jeder Seite einzeln. Die Regel für „1.267"
// (ein Punkt vor genau drei Ziffern trennt Tausender) musste deshalb zweimal
// nachgetragen werden, und beim dritten Rechner wäre sie vergessen worden.
//
// Nichts hier sendet oder speichert etwas. Die Rechner rechnen im Browser.
(function () {
  "use strict";

  // Eine Zahl, wie sie jemand in Deutschland eintippt.
  function zahl(text) {
    var t = String(text == null ? "" : text).replace(/\s/g, "");
    if (t.indexOf(",") >= 0) t = t.replace(/\./g, "").replace(",", ".");
    // „1.267" ist eintausendzweihundertsiebenundsechzig, nicht eins Komma
    // zwei. „0.9523" oder „11.4" bleiben Kommazahlen.
    else if (/^\d{1,3}(\.\d{3})+$/.test(t)) t = t.replace(/\./g, "");
    var n = parseFloat(t);
    return isFinite(n) ? n : NaN;
  }

  function format(n, stellen) {
    return new Intl.NumberFormat("de-DE", {
      minimumFractionDigits: stellen, maximumFractionDigits: stellen
    }).format(n);
  }

  var euro = new Intl.NumberFormat("de-DE", { style: "currency", currency: "EUR" });

  function schutz(s) {
    return String(s).replace(/[&<>"]/g, function (z) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[z];
    });
  }

  // Eine Kachel: oben der Name, groß die Zahl, klein worauf sie sich bezieht.
  // `art` ist "haupt", "gut", "achtung" oder leer. `kennung` macht die Kachel
  // für die Prüfung auffindbar, ohne am Wortlaut zu hängen.
  function kachel(kennung, name, wert, zusatz, art) {
    return '<div class="kachel' + (art ? " kachel-" + art : "") + '" data-kachel="' + kennung + '">' +
      '<span class="kachel-name">' + schutz(name) + "</span>" +
      '<span class="kachel-wert">' + schutz(wert) + "</span>" +
      (zusatz ? '<span class="kachel-zusatz">' + schutz(zusatz) + "</span>" : "") +
      "</div>";
  }

  function kacheln(liste) {
    return '<div class="kacheln">' + liste.join("") + "</div>";
  }

  function hinweis(text) {
    return '<p class="rechner-hinweis" data-hinweis>' + schutz(text) + "</p>";
  }

  window.Rechner = { zahl: zahl, format: format, euro: euro, kachel: kachel,
                     kacheln: kacheln, hinweis: hinweis };
})();
