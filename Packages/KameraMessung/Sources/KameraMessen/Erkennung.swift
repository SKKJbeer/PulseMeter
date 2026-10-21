import Foundation
import PulseCore

#if canImport(Vision)
import Vision
import ImageIO

/// Schickt ein Foto durch die Texterkennung des Systems, mit den Einstellungen,
/// die auch die App nähme: genaue Stufe, ohne Sprachkorrektur (eine Korrektur
/// „verbessert" Ziffern zu Wörtern), Deutsch und Englisch.
func erkenne(_ datei: URL, ausschnitt: [Double]? = nil) throws -> [RecognizedLine] {
    guard let quelle = CGImageSourceCreateWithURL(datei as CFURL, nil),
          let bild = CGImageSourceCreateImageAtIndex(quelle, 0, nil) else {
        throw NSError(domain: "KameraMessen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bild nicht lesbar: \(datei.path)"])
    }
    var bild = bild
    // Der Rahmen aus dem Sucher: Vision liest dann nur das Display, nicht das Typenschild.
    if let a = ausschnitt, a.count == 4 {
        let b = Double(bild.width), h = Double(bild.height)
        let rahmen = CGRect(x: a[0] * b, y: a[1] * h, width: (a[2] - a[0]) * b, height: (a[3] - a[1]) * h).integral
        if let beschnitten = bild.cropping(to: rahmen) { bild = beschnitten }
    }
    let anfrage = VNRecognizeTextRequest()
    anfrage.recognitionLevel = .accurate
    anfrage.usesLanguageCorrection = false
    anfrage.recognitionLanguages = ["de-DE", "en-US"]
    try VNImageRequestHandler(cgImage: bild, options: [:]).perform([anfrage])
    return (anfrage.results ?? []).compactMap { $0.topCandidates(1).first }
        .map { RecognizedLine($0.string, confidence: Double($0.confidence)) }
}

let visionVerfuegbar = true
#else
func erkenne(_ datei: URL, ausschnitt: [Double]? = nil) throws -> [RecognizedLine] {
    throw NSError(domain: "KameraMessen", code: 2, userInfo: [NSLocalizedDescriptionKey: "Vision gibt es nur auf einem Apple-Gerät. Mit --texte <datei> lässt sich der Rest prüfen."])
}

let visionVerfuegbar = false
#endif
