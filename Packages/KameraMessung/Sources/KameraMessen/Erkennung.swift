import Foundation
import PulseCore

#if canImport(Vision)
import Vision
import ImageIO

/// Schickt ein Foto durch die Texterkennung des Systems, mit den Einstellungen,
/// die auch die App nähme: genaue Stufe, ohne Sprachkorrektur (eine Korrektur
/// „verbessert" Ziffern zu Wörtern), Deutsch und Englisch.
func erkenne(_ datei: URL) throws -> [RecognizedText] {
    guard let quelle = CGImageSourceCreateWithURL(datei as CFURL, nil),
          let bild = CGImageSourceCreateImageAtIndex(quelle, 0, nil) else {
        throw NSError(domain: "KameraMessen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bild nicht lesbar: \(datei.path)"])
    }
    let anfrage = VNRecognizeTextRequest()
    anfrage.recognitionLevel = .accurate
    anfrage.usesLanguageCorrection = false
    anfrage.recognitionLanguages = ["de-DE", "en-US"]
    try VNImageRequestHandler(cgImage: bild, options: [:]).perform([anfrage])
    return (anfrage.results ?? []).compactMap { $0.topCandidates(1).first }
        .map { RecognizedText($0.string, confidence: Double($0.confidence)) }
}

let visionVerfuegbar = true
#else
func erkenne(_ datei: URL) throws -> [RecognizedText] {
    throw NSError(domain: "KameraMessen", code: 2, userInfo: [NSLocalizedDescriptionKey: "Vision gibt es nur auf einem Apple-Gerät. Mit --texte <datei> lässt sich der Rest prüfen."])
}

let visionVerfuegbar = false
#endif
