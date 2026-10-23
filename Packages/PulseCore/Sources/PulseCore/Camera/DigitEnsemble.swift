import Foundation

/// Mehrere Ziffernnetze, die sich **einig** sein müssen.
///
/// **Warum.** Ein Netz irrt sich anders als das andere: Auf Fotos, die nie zum Training
/// gehörten (`docs/kamera/fotos-lcd.json`), las ein einzelnes Netz in einzelnen Versuchen eine
/// Zahl falsch, das andere an anderer Stelle. Dieselbe Zeile von beiden gelesen ist ein viel
/// stärkeres Zeichen als von einem. Lesen sie Verschiedenes, gilt das Bild als nicht gelesen;
/// die Einigung über mehrere Bilder (``ReadingConsensus``) und die Prüfung des Nutzers kommen danach.
/// Der Preis: Es kommt öfter nichts heraus. Eine falsche Zahl ist schlimmer (Produktprinzip 7).
public struct DigitEnsemble: Sendable {

    public let nets: [DigitNet]

    public init(nets: [DigitNet]) {
        precondition(!nets.isEmpty, "Ein Ensemble braucht mindestens ein Netz")
        self.nets = nets
    }

    /// Die Netze, die in der App laufen.
    public static let bundled = DigitEnsemble(nets: DigitNet.bundledNets)

    /// Liest eine Zeile. Alle Netze müssen **genau denselben Text** gelesen haben, die Sicherheit ist die
    /// kleinste unter ihnen. Sonst ist das Ergebnis leer.
    public func read(pixels: [Float]) -> DigitLine {
        var agreed: DigitLine?
        for net in nets {
            let line = DigitDecoder.decode(net.run(pixels: pixels))
            guard let first = agreed else { agreed = line; continue }
            guard first.text == line.text else { return DigitLine(glyphs: []) }
            // Gleicher Text: je Zeichen die kleinere Wahrscheinlichkeit behalten.
            agreed = DigitLine(glyphs: zip(first.glyphs, line.glyphs).map {
                DigitLine.Glyph(character: $0.character, probability: min($0.probability, $1.probability))
            })
        }
        return agreed ?? DigitLine(glyphs: [])
    }
}
