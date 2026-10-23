# Das Ziffernnetz: Training, Messung, Weitergabe

Liest Siebensegment-Ziffern aus einem Sucherausschnitt (48 × 240 Punkte, Verhältnis 5 : 1).
Warum es das gibt und wie gut es liest: `docs/kamera/README.md`, Abschnitt „Gemessen: das eigene
Ziffernnetz“. Hier steht, wie man es neu baut.

Braucht `numpy`, `opencv-python-headless`, `pillow`, `torch` (CPU genügt). Alle Aufrufe aus
diesem Ordner. Einmalig: `python3 schriften-holen.py` (Siebensegment-Schriften DSEG, SIL OFL, nur für das Training).

| Schritt | Aufruf | Dauer (4 Kerne) |
|---|---|---|
| Trainingsdaten | `python3 gen.py 120000 train.npz 9000` und `python3 gen.py 3200 val.npz 970000` | 3 Minuten |
| Training | `python3 train.py 8 ziffernnetz-1.pt train.npz 1.2e-3 neu.pt val.npz` | etwa 10 Minuten je Epoche |
| Messen | `python3 evaluate.py ziffernnetz-1.pt,neu.pt 100` (Netze mit Komma: ein Bild gilt nur bei gleichem Text) | 10 Minuten |
| Gewichte schreiben | `python3 export.py neu.pt ziffernnetz-2.bin`, dann im Hauptverzeichnis `scripts/kamera-gewichte.py` | Sekunden |
| Referenzwerte | `python3 golden.py ../../docs/kamera/lcd-vektoren.json ziffernnetz-1.pt neu.pt` | Sekunden |
| Alles gegenprüfen | `scripts/pruefen.sh schnell` | 1,5 Minuten |

Dateien: `synth.py` zeichnet die Anzeigen (**hier steckt die Arbeit**), `train.py` das Netz,
`area.py` die flächengemittelte Verkleinerung (dieselbe wie `GrayImage.resampled` in Swift und
`DigitNet.verkleinern` im Klick-Dummy), `realtest.py` schneidet Sucherbilder aus den Fotos in
`docs/kamera/` (Rahmen in `fotos.json`), `evaluate.py` misst wie die App (sechs Bilder, drei gleiche,
Leser), `ziffernnetz-N.pt` sind die Stände zum Weitertrainieren, `ziffernnetz-N.bin` das, was in die App geht (zwei Netze, die sich einig sein müssen).

**Die Regeln dabei**

- **Die Fotos werden nie trainiert**, nur gemessen. Wer ein Foto zum Training nimmt, hat keine Zahl mehr.
- **Wer Fehlerbilder ansieht, verbraucht den Test.** Die erste Sammlung (`fotos.json`) ist so verbraucht. Neue Fotos
  für eine neue Sammlung holen (Wikimedia Commons, frei lizenziert, `scripts/check-kamerafotos.py`), bevor man
  eine Verbesserung behauptet; und Änderungen am Generator allgemein halten, nicht auf ein Foto zuschneiden.
- **Ein Netz mehr ist keine Verbesserung, bis es gemessen ist.** Runde 4 und 5 machten es einzeln schlechter; nur die
  Einigung zweier Netze hielt die Fehler niedrig.
- **Nach jeder Messung die Fehler ansehen** und den Generator ändern, nicht das Netz anpassen.
- **Ändert sich die Architektur,** ändern sich `DigitNet.swift` (Gewichtsformat, Reihenfolge) und der Block
  `DigitNet` im Klick-Dummy zugleich; `DigitNetTests` und `scripts/check-kamera-js.mjs` melden, wenn
  eine Seite abweicht.
- **Neues Training ab dem alten Stand,** wenn der Generator sich ändert (`train.py` lädt den Stand auch aus
  der Fassung mit zwei einfachen Faltungen), sonst kostet jede Runde eine Stunde mehr.
