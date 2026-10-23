import Foundation

/// Der Rahmen im Sucher und was daraus für das Netz wird.
public enum Viewfinder {

    /// Breite : Höhe des Rahmens — dasselbe Verhältnis wie der Eingang des Netzes.
    /// Ein anderes würde die Ziffern beim Verkleinern strecken, und das Netz hat
    /// nie gestreckte Ziffern gesehen.
    public static let aspect = Double(DigitNet.inputWidth) / Double(DigitNet.inputHeight)

    /// Wo der Rahmen in der Ansicht liegt: mittig, fast so breit wie die Ansicht,
    /// ein Stück über der Mitte, damit der Daumen ihn nicht verdeckt.
    ///
    /// - Parameter heightShare: Anteil der Ansichtshöhe, auf dem der Mittelpunkt
    ///   liegt (0,42 = knapp über der Mitte).
    public static func guide(inViewWidth width: Double, height: Double, centerY heightShare: Double = 0.42,
                             margin: Double = 20) -> PixelRect {
        let w = max(1, width - 2 * margin)
        let h = w / aspect
        return PixelRect(x: margin, y: height * heightShare - h / 2, width: w, height: h)
    }

    /// Rechnet den Rahmen aus Koordinaten der Ansicht in Bildpunkte des
    /// Kamerabilds um.
    ///
    /// Die Vorschau füllt die Ansicht (`resizeAspectFill`): Das Bild ist
    /// gleichmäßig so weit vergrößert, dass es die Ansicht überall deckt, und
    /// ragt an den Seiten über. Genau diese Verschiebung wird hier zurückgenommen.
    /// Selbst gerechnet statt über `metadataOutputRectConverted`, weil das Bild
    /// vor der Auswertung gedreht wird und die Umrechnung der Kamera dann etwas
    /// anderes meint als das, was auf dem Schirm steht.
    public static func bufferRect(guide: PixelRect, viewWidth: Double, viewHeight: Double,
                                  bufferWidth: Double, bufferHeight: Double) -> PixelRect {
        let scale = max(viewWidth / bufferWidth, viewHeight / bufferHeight)
        let offsetX = (viewWidth - bufferWidth * scale) / 2
        let offsetY = (viewHeight - bufferHeight * scale) / 2
        return PixelRect(x: (guide.x - offsetX) / scale, y: (guide.y - offsetY) / scale,
                         width: guide.width / scale, height: guide.height / scale)
    }

    /// Liest eine Zeile aus dem Rahmen eines Kamerabilds.
    public static func read(_ frame: GrayImage, rect: PixelRect, ensemble: DigitEnsemble = .bundled) -> DigitLine {
        let pixels = frame.resampled(rect: rect, outWidth: DigitNet.inputWidth, outHeight: DigitNet.inputHeight)
        return ensemble.read(pixels: pixels)
    }
}

/// Wie brauchbar das Bild im Rahmen ist, bevor das Netz es sieht.
///
/// **Warum vorher.** Ein dunkles oder verwackeltes Bild liefert keine Ziffern,
/// und „nichts gefunden" sagt dem Nutzer nicht, was er ändern soll. Die Hinweise
/// sagen es: Licht an, ruhiger halten.
public struct FrameQuality: Hashable, Sendable {
    public enum Hint: Hashable, Sendable {
        case ok
        /// Zu dunkel: Die Taschenlampe hilft.
        case tooDark
        /// Zu wenig Kontrast zwischen Ziffern und Grund (Spiegelung, Gegenlicht).
        case flat
        /// Unscharf oder verwackelt.
        case blurry
    }

    /// Mittlere Helligkeit, 0 bis 1.
    public let brightness: Double
    /// Streuung der Helligkeit im Rahmen, 0 bis etwa 0,5.
    public let contrast: Double
    /// Mittlere Kantenstärke bezogen auf den Kontrast: Scharfe Ziffern haben viele steile Kanten.
    public let sharpness: Double

    public init(pixels: [Float], width: Int, height: Int) {
        let n = Double(pixels.count)
        let mean = pixels.reduce(0) { $0 + Double($1) } / n
        let variance = pixels.reduce(0) { $0 + (Double($1) - mean) * (Double($1) - mean) } / n
        let std = variance.squareRoot()
        var edges = 0.0
        var count = 0.0
        for y in 0..<height {
            for x in 1..<width {
                edges += abs(Double(pixels[y * width + x]) - Double(pixels[y * width + x - 1]))
                count += 1
            }
        }
        brightness = mean
        contrast = std
        sharpness = std > 0.0001 ? (edges / count) / std : 0
    }

    public var hint: Hint {
        if brightness < 0.16 { return .tooDark }
        if contrast < 0.035 { return .flat }
        if sharpness < 0.10 { return .blurry }
        return .ok
    }
}
