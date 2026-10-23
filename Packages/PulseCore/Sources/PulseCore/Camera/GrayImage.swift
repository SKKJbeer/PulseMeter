import Foundation

/// Ein Rechteck in Bildpunkten. Es darf über den Rand des Bildes hinausragen;
/// dort wird der Rand fortgesetzt.
///
/// **Ein eigener Typ statt `CGRect`:** PulseCore bleibt bei Foundation, und
/// die Auswertung soll unter Linux dieselben Zahlen liefern wie auf dem Telefon.
public struct PixelRect: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Ein Graustufenbild, zeilenweise, 0 (schwarz) bis 255 (weiß).
///
/// Die Kamera liefert die Helligkeit als eigene Ebene; mehr braucht die
/// Ziffernerkennung nicht. Farbe hilft ihr nicht, und sie zu rechnen kostet
/// bei jedem Bild Zeit, die am Zähler fehlt.
public struct GrayImage: Sendable {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(width > 0 && height > 0 && pixels.count == width * height,
                     "Die Bildpunkte passen nicht zu Breite und Höhe")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// Mit Zeilenabstand: So steht die Helligkeitsebene eines Kamerabilds im
    /// Speicher, wenn eine Zeile länger ist als das Bild breit.
    public init(width: Int, height: Int, bytesPerRow: Int, base: UnsafePointer<UInt8>) {
        var out = [UInt8](repeating: 0, count: width * height)
        out.withUnsafeMutableBufferPointer { dst in
            for y in 0..<height {
                let row = base + y * bytesPerRow
                for x in 0..<width { dst[y * width + x] = row[x] }
            }
        }
        self.init(width: width, height: height, pixels: out)
    }

    /// Kopiert nur das Fenster um `rect` aus einer Helligkeitsebene und gibt das
    /// Rechteck in Koordinaten des Fensters zurück.
    ///
    /// **Warum nicht das ganze Bild.** Ein Kamerabild hat zwei Millionen Punkte, der
    /// Rahmen im Sucher ein paar Zehntausend. Jedes Bild ganz zu kopieren hieße
    /// in der Sekunde zehnmal zwei Megabyte umzuschichten, um sie gleich
    /// wegzuwerfen. `nil`, wenn der Rahmen ganz außerhalb liegt.
    public static func window(around rect: PixelRect, width: Int, height: Int, bytesPerRow: Int,
                              base: UnsafePointer<UInt8>) -> (image: GrayImage, rect: PixelRect)? {
        let x0 = max(0, Int(floor(rect.x)) - 2)
        let y0 = max(0, Int(floor(rect.y)) - 2)
        let x1 = min(width, Int(ceil(rect.x + rect.width)) + 2)
        let y1 = min(height, Int(ceil(rect.y + rect.height)) + 2)
        guard x1 > x0, y1 > y0 else { return nil }
        let image = GrayImage(width: x1 - x0, height: y1 - y0, bytesPerRow: bytesPerRow, base: base + y0 * bytesPerRow + x0)
        return (image, PixelRect(x: rect.x - Double(x0), y: rect.y - Double(y0), width: rect.width, height: rect.height))
    }

    /// Verkleinert (oder vergrößert) ein Rechteck auf `outWidth × outHeight`,
    /// **flächengemittelt**: Jeder Zielpunkt ist der Mittelwert der Quellfläche, die er
    /// überdeckt, mit anteiligen Gewichten am Rand.
    ///
    /// **Warum nicht einfach „bilinear".** Eine Zielfläche, die vier Bildpunkte
    /// breit ist, würde bilinear nur zwei davon ansehen und die dünnen Segmente
    /// einer Siebensegment-Ziffer mal treffen, mal verfehlen. Das Netz ist auf
    /// flächengemittelte Bilder trainiert (`scripts/kamera-training.py`), und
    /// die Python-, Swift- und JavaScript-Fassung rechnen dasselbe.
    ///
    /// Werte 0 bis 1.
    @_optimize(speed)
    public func resampled(rect: PixelRect, outWidth: Int, outHeight: Int) -> [Float] {
        let rows = Self.weights(start: rect.y, length: rect.height, count: outHeight, limit: height)
        let cols = Self.weights(start: rect.x, length: rect.width, count: outWidth, limit: width)
        var out = [Float](repeating: 0, count: outWidth * outHeight)
        // Erst waagerecht über die nötigen Quellzeilen, dann senkrecht: getrennt
        // gerechnet, weil die Gewichte getrennt sind.
        var rowBuffer = [Float](repeating: 0, count: width)
        pixels.withUnsafeBufferPointer { src in
            for (oy, row) in rows.enumerated() {
                // Zeile der Zielhöhe: gewichtete Summe der Quellzeilen, danach Spalten.
                for i in 0..<width { rowBuffer[i] = 0 }
                for (sy, wy) in row {
                    let base = sy * width
                    for x in 0..<width { rowBuffer[x] += Float(src[base + x]) * wy }
                }
                for (ox, col) in cols.enumerated() {
                    var sum: Float = 0
                    for (sx, wx) in col { sum += rowBuffer[sx] * wx }
                    out[oy * outWidth + ox] = sum / 255
                }
            }
        }
        return out
    }

    /// Je Zielindex die Quellindizes mit Gewicht (Summe 1). Ragt die Fläche über
    /// den Rand, zählt der Randpunkt weiter.
    static func weights(start: Double, length: Double, count: Int, limit: Int) -> [[(Int, Float)]] {
        let step = length / Double(count)
        return (0..<count).map { o in
            let a = start + Double(o) * step
            let b = a + step
            var entries: [Int: Double] = [:]
            var index = Int(floor(a))
            while Double(index) < b {
                let overlap = min(b, Double(index + 1)) - max(a, Double(index))
                if overlap > 0 {
                    let clamped = min(max(index, 0), limit - 1)
                    entries[clamped, default: 0] += overlap
                }
                index += 1
            }
            if entries.isEmpty {
                let clamped = min(max(Int(floor(a)), 0), limit - 1)
                entries[clamped] = step
            }
            let total = entries.values.reduce(0, +)
            return entries.sorted { $0.key < $1.key }.map { ($0.key, Float($0.value / total)) }
        }
    }
}
