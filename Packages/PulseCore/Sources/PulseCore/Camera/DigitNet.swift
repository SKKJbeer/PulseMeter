import Foundation

/// Das Netz, das Siebensegment-Ziffern liest.
///
/// **Warum ein eigenes Netz.** Apples Texterkennung liest Rollenzähler und große
/// Ziffern, aber keine LCD-Anzeigen: Im Versuch vom 21. Oktober traf sie 1 von 9
/// (`docs/kamera/README.md`), und ihre Sicherheit trennte Richtiges nicht von
/// Falschem. Siebensegment-Ziffern sind ein enger, regelmäßiger Fall — sieben
/// Balken, ein paar Schrägen, Geisterbilder abgeschalteter Segmente —, und den
/// kann man vollständig nachbauen. Das Netz ist auf nachgebauten Anzeigen
/// trainiert und an den echten Fotos **nur geprüft**, nie angepasst.
///
/// **Was es kann und was nicht.** Es bekommt einen Ausschnitt, den der Nutzer im
/// Sucher auf die Ziffern gelegt hat (Verhältnis 5 : 1), und liest daraus eine
/// Zeile: Ziffern, Komma, Doppelpunkt. Es sucht kein Display im ganzen Foto.
/// Gedruckte Ziffern (Typenschild, Seriennummer) sind im Training als „nichts"
/// vorgekommen und sollen leer bleiben.
///
/// **Warum in Swift ausgeschrieben statt Core ML.** Die Rechnung steht hier
/// schwarz auf weiß, läuft unter Linux in den Tests und gegen die Referenzwerte
/// aus dem Training — und die JavaScript-Fassung im Klick-Dummy rechnet
/// Schritt für Schritt dasselbe. Ein Modellformat, das nur ein Mac laden kann,
/// hätte nichts davon geprüft. Etwa 70 Millionen Multiplikationen je Bild.
///
/// Aufbau (Gewichte mit eingerechneter Normalisierung, Reihenfolge fest):
/// 4 Faltungsblöcke mit Maxpool, ein Faltungsschritt über die verbleibenden drei
/// Zeilen, vier Blöcke mit Lücken (1, 2, 4, 8) und Restverbindung entlang der
/// Zeichenfolge und eine Ausgabeschicht.
public struct DigitNet: Sendable {

    public static let inputWidth = 240
    public static let inputHeight = 48
    /// Klasse 0 ist „leer", danach die Zeichen in dieser Reihenfolge.
    public static let characters: [Character] = Array("0123456789.:")
    public static let classCount = characters.count + 1
    static let dilations = [1, 2, 4, 8]

    struct Tensor: Sendable {
        let shape: [Int]
        let values: [Float]
    }

    private let tensors: [Tensor]

    public enum LoadError: Error, Equatable {
        case badFormat
        case unexpectedLayout
    }

    /// Liest die Gewichte aus dem flachen Format von `scripts/kamera-training.py`:
    /// `ZNW1`, Anzahl, je Tensor Rang, Maße, Werte als Float32 (little endian).
    public init(weights data: Data) throws {
        let bytes = [UInt8](data)
        var cursor = 0
        func int32() throws -> Int {
            guard cursor + 4 <= bytes.count else { throw LoadError.badFormat }
            let v = Int32(bitPattern: UInt32(bytes[cursor]) | UInt32(bytes[cursor + 1]) << 8
                          | UInt32(bytes[cursor + 2]) << 16 | UInt32(bytes[cursor + 3]) << 24)
            cursor += 4
            return Int(v)
        }
        guard bytes.count > 8, Array(bytes[0..<4]) == Array("ZNW1".utf8) else { throw LoadError.badFormat }
        cursor = 4
        let count = try int32()
        guard count == 20 else { throw LoadError.unexpectedLayout }
        var out: [Tensor] = []
        for _ in 0..<count {
            let rank = try int32()
            guard (1...4).contains(rank) else { throw LoadError.badFormat }
            var shape: [Int] = []
            for _ in 0..<rank { shape.append(try int32()) }
            let n = shape.reduce(1, *)
            guard n > 0, cursor + n * 4 <= bytes.count else { throw LoadError.badFormat }
            var values = [Float](repeating: 0, count: n)
            for i in 0..<n {
                let bits = UInt32(bytes[cursor]) | UInt32(bytes[cursor + 1]) << 8
                    | UInt32(bytes[cursor + 2]) << 16 | UInt32(bytes[cursor + 3]) << 24
                values[i] = Float(bitPattern: bits)
                cursor += 4
            }
            out.append(Tensor(shape: shape, values: values))
        }
        // Die Maße, auf die die Rechnung unten fest gebaut ist.
        let expected: [[Int]] = [[16, 1, 3, 3], [16], [32, 16, 3, 3], [32], [48, 32, 3, 3], [48],
                                 [64, 48, 3, 3], [64], [96, 64, 3, 1], [96],
                                 [96, 96, 5], [96], [96, 96, 5], [96], [96, 96, 5], [96], [96, 96, 5], [96],
                                 [Self.classCount, 96, 1], [Self.classCount]]
        guard out.map(\.shape) == expected else { throw LoadError.unexpectedLayout }
        tensors = out
    }

    /// Die Ausgabe des Netzes: je Zeitschritt eine Zahl je Klasse (Rohwerte vor
    /// der Normierung), `classCount` Zeilen, `steps` Spalten.
    public struct Output: Sendable {
        public let classCount: Int
        public let steps: Int
        /// Zeilenweise: `values[klasse * steps + schritt]`.
        public let values: [Float]
    }

    /// - Parameter pixels: `inputWidth × inputHeight` Werte von 0 bis 1, zeilenweise.
    public func run(pixels input: [Float]) -> Output {
        precondition(input.count == Self.inputWidth * Self.inputHeight, "Falsche Bildgröße")
        var h = Self.inputHeight
        var w = Self.inputWidth

        // Helligkeit und Kontrast herausrechnen: Ein dunkles Display im Schatten
        // und ein helles in der Sonne sollen dieselben Zahlen liefern.
        let n = Float(input.count)
        let mean = input.reduce(0, +) / n
        var squares: Float = 0
        for v in input { squares += (v - mean) * (v - mean) }
        let std = (squares / (n - 1)).squareRoot() + 0.02
        var x = input.map { ($0 - mean) / std }

        var channels = 1
        for (block, pool) in [(0, (2, 2)), (2, (2, 1)), (4, (2, 1)), (6, (2, 1))] {
            let outChannels = tensors[block].shape[0]
            x = Self.conv3x3ReLU(x, cin: channels, h: h, w: w, weight: tensors[block].values,
                                 bias: tensors[block + 1].values, cout: outChannels)
            channels = outChannels
            (x, h, w) = Self.maxPool(x, channels: channels, h: h, w: w, ph: pool.0, pw: pool.1)
        }
        // Höhe ist jetzt 3: ein Schritt über alle drei Zeilen macht eine Folge daraus.
        x = Self.collapse(x, cin: channels, h: h, w: w, weight: tensors[8].values, bias: tensors[9].values,
                          cout: tensors[8].shape[0])
        channels = tensors[8].shape[0]
        // Vier Blöcke mit wachsenden Lücken (1, 2, 4, 8) und Restverbindung: Jeder Schritt der
        // Folge sieht so die ganze Zeile. Das braucht das Netz, um die kleine „004“ neben der
        // großen Zahl zu überhören und das „k“ der Einheit nicht als Ziffer zu lesen.
        for (k, dilation) in Self.dilations.enumerated() {
            let branch = Self.conv1D(x, cin: channels, steps: w, weight: tensors[10 + 2 * k].values,
                                     bias: tensors[11 + 2 * k].values, cout: channels, kernel: 5,
                                     dilation: dilation, relu: true)
            for i in 0..<x.count { x[i] += branch[i] }
        }
        x = Self.conv1D(x, cin: channels, steps: w, weight: tensors[18].values, bias: tensors[19].values,
                        cout: Self.classCount, kernel: 1, dilation: 1, relu: false)
        return Output(classCount: Self.classCount, steps: w, values: x)
    }

    // MARK: - Schichten
    //
    // **`@_optimize(speed)` auf jeder Schleife, die rechnet.** Im Debug-Bau (Tests, Simulator) läuft Swift ohne
    // Optimierung, und die Rechnung braucht dann auf dem Mac-Läufer Minuten statt Sekunden: Der Lauf zu `41e318a`
    // brauchte für `PulseCore` 38 statt 4 Minuten und riss das Zeitlimit des iPhone-Auftrags. Das Attribut
    // optimiert nur diese Funktionen, auch im Debug-Bau; die Ergebnisse bleiben dieselben.

    @_optimize(speed)
    static func conv3x3ReLU(_ x: [Float], cin: Int, h: Int, w: Int, weight: [Float], bias: [Float], cout: Int) -> [Float] {
        var out = [Float](repeating: 0, count: cout * h * w)
        x.withUnsafeBufferPointer { src in
            weight.withUnsafeBufferPointer { wt in
                out.withUnsafeMutableBufferPointer { dst in
                    for oc in 0..<cout {
                        let plane = oc * h * w
                        for i in 0..<(h * w) { dst[plane + i] = bias[oc] }
                        for ic in 0..<cin {
                            let inPlane = ic * h * w
                            for ky in 0..<3 {
                                let dy = ky - 1
                                for kx in 0..<3 {
                                    let dx = kx - 1
                                    let wv = wt[((oc * cin + ic) * 3 + ky) * 3 + kx]
                                    let x0 = max(0, -dx)
                                    let x1 = min(w, w - dx)
                                    for y in max(0, -dy)..<min(h, h - dy) {
                                        let srcRow = inPlane + (y + dy) * w + dx
                                        let dstRow = plane + y * w
                                        for xx in x0..<x1 { dst[dstRow + xx] += wv * src[srcRow + xx] }
                                    }
                                }
                            }
                        }
                        for i in 0..<(h * w) where dst[plane + i] < 0 { dst[plane + i] = 0 }
                    }
                }
            }
        }
        return out
    }

    @_optimize(speed)
    static func maxPool(_ x: [Float], channels: Int, h: Int, w: Int, ph: Int, pw: Int) -> ([Float], Int, Int) {
        let oh = h / ph, ow = w / pw
        var out = [Float](repeating: -Float.infinity, count: channels * oh * ow)
        for c in 0..<channels {
            for y in 0..<oh {
                for xx in 0..<ow {
                    var best = -Float.infinity
                    for dy in 0..<ph {
                        for dx in 0..<pw {
                            best = max(best, x[(c * h + y * ph + dy) * w + xx * pw + dx])
                        }
                    }
                    out[(c * oh + y) * ow + xx] = best
                }
            }
        }
        return (out, oh, ow)
    }

    /// Faltung mit Kern (h × 1) ohne Auffüllen: aus `h` Zeilen wird eine.
    @_optimize(speed)
    static func collapse(_ x: [Float], cin: Int, h: Int, w: Int, weight: [Float], bias: [Float], cout: Int) -> [Float] {
        var out = [Float](repeating: 0, count: cout * w)
        for oc in 0..<cout {
            for xx in 0..<w {
                var sum = bias[oc]
                for ic in 0..<cin {
                    for ky in 0..<h {
                        sum += weight[(oc * cin + ic) * h + ky] * x[(ic * h + ky) * w + xx]
                    }
                }
                out[oc * w + xx] = max(0, sum)
            }
        }
        return out
    }

    @_optimize(speed)
    static func conv1D(_ x: [Float], cin: Int, steps: Int, weight: [Float], bias: [Float], cout: Int, kernel: Int, dilation: Int, relu: Bool) -> [Float] {
        var out = [Float](repeating: 0, count: cout * steps)
        let pad = kernel / 2
        x.withUnsafeBufferPointer { src in
            weight.withUnsafeBufferPointer { wt in
                out.withUnsafeMutableBufferPointer { dst in
                    for oc in 0..<cout {
                        for t in 0..<steps { dst[oc * steps + t] = bias[oc] }
                        for ic in 0..<cin {
                            for k in 0..<kernel {
                                let wv = wt[(oc * cin + ic) * kernel + k]
                                let shift = (k - pad) * dilation
                                for t in max(0, -shift)..<min(steps, steps - shift) {
                                    dst[oc * steps + t] += wv * src[ic * steps + t + shift]
                                }
                            }
                        }
                        if relu { for t in 0..<steps where dst[oc * steps + t] < 0 { dst[oc * steps + t] = 0 } }
                    }
                }
            }
        }
        return out
    }
}
