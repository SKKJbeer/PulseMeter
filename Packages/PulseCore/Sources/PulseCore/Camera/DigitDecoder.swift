import Foundation

/// Was das Netz in einem Bild gelesen hat.
public struct DigitLine: Hashable, Sendable {
    public struct Glyph: Hashable, Sendable {
        public var character: Character
        /// Wahrscheinlichkeit, die das Netz diesem Zeichen gab (0 bis 1).
        public var probability: Float
    }

    public var glyphs: [Glyph]

    public init(glyphs: [Glyph]) { self.glyphs = glyphs }

    public var text: String { String(glyphs.map(\.character)) }

    /// Das unsicherste Zeichen bestimmt die Zeile. Eine Zahl ist so gut wie ihre
    /// schwächste Ziffer: Eine falsche Stelle macht aus 14.426 eben 19.426.
    public var confidence: Double {
        glyphs.map { Double($0.probability) }.min() ?? 0
    }

    public var isEmpty: Bool { glyphs.isEmpty }

    /// Für den Leser: der Text und wie sicher er ist.
    public var recognized: RecognizedLine { RecognizedLine(text, confidence: confidence) }
}

public enum DigitDecoder {

    /// Gierige CTC-Auswertung: je Zeitschritt die wahrscheinlichste Klasse, Wiederholungen
    /// zusammengefasst, „leer" gestrichen. Die Sicherheit eines Zeichens ist der höchste Wert,
    /// den es auf seinem Stück der Folge erreicht hat.
    public static func decode(_ output: DigitNet.Output) -> DigitLine {
        var glyphs: [DigitLine.Glyph] = []
        var previous = 0
        for t in 0..<output.steps {
            // Softmax über die Klassen dieses Schritts.
            var peak = -Float.infinity
            var best = 0
            for c in 0..<output.classCount {
                let v = output.values[c * output.steps + t]
                if v > peak { peak = v; best = c }
            }
            var sum: Float = 0
            for c in 0..<output.classCount { sum += exp(output.values[c * output.steps + t] - peak) }
            let p = 1 / sum    // exp(peak - peak) = 1
            if best != 0 {
                if best != previous {
                    glyphs.append(.init(character: DigitNet.characters[best - 1], probability: p))
                } else if p > glyphs[glyphs.count - 1].probability {
                    glyphs[glyphs.count - 1].probability = p
                }
            }
            previous = best
        }
        return DigitLine(glyphs: glyphs)
    }
}
