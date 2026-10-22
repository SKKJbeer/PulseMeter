# Das Ziffernnetz: Training, Messung, Weitergabe

Liest Siebensegment-Ziffern aus einem Sucherausschnitt (48 × 240 Punkte, Verhältnis 5 : 1).
Warum es das gibt und wie gut es liest: `docs/kamera/README.md`, Abschnitt „Gemessen: das eigene
Ziffernnetz“. Hier steht, wie man es neu baut.

Braucht `numpy`, `opencv-python-headless`, `pillow`, `torch` (CPU genügt). Alle Aufrufe aus
diesem Ordner.

| Schritt | Aufruf | Dauer (4 Kerne) |
|---|---|---|
| Trainingsdaten | `python3 gen.py 120000 train.npz 9000` und `python3 gen.py 3200 val.npz 970000` | 3 Minuten |
| Training | `python3 train.py 6 ziffernnetz.pt train.npz 1.5e-3 neu.pt val.npz` | etwa 9 Minuten je Epoche |
| Messen | `python3 evaluate.py neu.pt 100` | 3 Minuten |
| Gewichte schreiben | `python3 export.py neu.pt ziffernnetz.bin`, dann im Hauptverzeichnis `scripts/kamera-gewichte.py` | Sekunden |
| Referenzwerte | `python3 golden.py neu.pt ../../docs/kamera/lcd-vektoren.json` | Sekunden |
| Alles gegenprüfen | `scripts/pruefen.sh schnell` | 1,5 Minuten |

Dateien: `synth.py` zeichnet die Anzeigen (**hier steckt die Arbeit**), `train.py` das Netz,
`area.py` die flächengemittelte Verkleinerung (dieselbe wie `GrayImage.resampled` in Swift und
`DigitNet.verkleinern` im Klick-Dummy), `realtest.py` schneidet Sucherbilder aus den Fotos in
`docs/kamera/` (Rahmen in `fotos.json`), `evaluate.py` misst wie die App (sechs Bilder, drei gleiche,
Leser), `ziffernnetz.pt` ist der Stand zum Weitertrainieren, `ziffernnetz.bin` das, was in die App geht.

**Die Regeln dabei**

- **Die Fotos werden nie trainiert**, nur gemessen. Wer ein Foto zum Training nimmt, hat keine Zahl mehr.
- **Nach jeder Messung die Fehler ansehen** und den Generator ändern, nicht das Netz anpassen.
- **Ändert sich die Architektur,** ändern sich `DigitNet.swift` (Gewichtsformat, Reihenfolge) und der Block
  `DigitNet` im Klick-Dummy zugleich; `DigitNetTests` und `scripts/check-kamera-js.mjs` melden, wenn
  eine Seite abweicht.
- **Neues Training ab dem alten Stand,** wenn der Generator sich ändert (`train.py` lädt den Stand auch aus
  der Fassung mit zwei einfachen Faltungen), sonst kostet jede Runde eine Stunde mehr.
