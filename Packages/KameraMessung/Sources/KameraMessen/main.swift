import Foundation
import PulseCore

// Aufruf (aus dem Hauptverzeichnis):
//   swift run --package-path Packages/KameraMessung kamera-messen            # Vision, nur auf einem Mac
//   ... kamera-messen --texte gelesen.json                                     # gelesene Texte aus einer Datei
//   ... kamera-messen --zeige                                                  # dazu die gelesenen Texte je Foto
//   ... kamera-messen --streng                                                 # Ausstieg 1, wenn irgendwo ein falscher Vorschlag steht
//
// `gelesen.json`: {"<Fotoname ohne .jpg>": [["Text", Sicherheit 0…1], …], …}

let argumente = Array(CommandLine.arguments.dropFirst())
let streng = argumente.contains("--streng")
let zeige = argumente.contains("--zeige")

func wert(nach schalter: String) -> String? {
    guard let i = argumente.firstIndex(of: schalter), i + 1 < argumente.count else { return nil }
    return argumente[i + 1]
}

let wurzel = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/kamera")
guard let daten = try? Data(contentsOf: wurzel.appendingPathComponent("fotos.json")),
      let sammlung = try? JSONDecoder().decode(Sammlung.self, from: daten) else {
    FileHandle.standardError.write(Data("docs/kamera/fotos.json nicht gefunden. Aus dem Hauptverzeichnis des Projekts aufrufen.\n".utf8))
    exit(2)
}

var vorgegeben: [String: [RecognizedLine]]?
if let pfad = wert(nach: "--texte") {
    guard let d = try? Data(contentsOf: URL(fileURLWithPath: pfad)),
          let roh = try? JSONSerialization.jsonObject(with: d) as? [String: [[Any]]] else {
        FileHandle.standardError.write(Data("\(pfad) nicht lesbar.\n".utf8)); exit(2)
    }
    vorgegeben = roh.mapValues { $0.compactMap { p in
        guard p.count == 2, let t = p[0] as? String, let c = (p[1] as? NSNumber)?.doubleValue else { return nil }
        return RecognizedLine(t, confidence: c)
    } }
} else if !visionVerfuegbar {
    FileHandle.standardError.write(Data("Vision gibt es nur auf einem Apple-Gerät. Mit --texte <datei> lässt sich der Rest prüfen.\n".utf8))
    exit(2)
}

var zeilen: [Zeile] = []
for foto in sammlung.fotos {
    do {
        let texte = try vorgegeben?[foto.name] ?? erkenne(wurzel.appendingPathComponent(foto.datei))
        zeilen.append(auswerten(foto, texte: texte))
    } catch {
        FileHandle.standardError.write(Data("\(foto.name): \(error.localizedDescription)\n".utf8))
        exit(2)
    }
}

let text = bericht(zeilen, mitTexten: zeige)
print(text)
// Im Ablauf auch in die Zusammenfassung, wie die übrigen Berichte.
if let ziel = ProcessInfo.processInfo.environment["GITHUB_STEP_SUMMARY"],
   let handle = FileHandle(forWritingAtPath: ziel) {
    handle.seekToEndOfFile()
    handle.write(Data(("### Kamera: Texterkennung an den Zählerfotos\n\n```\n" + text + "\n```\n").utf8))
    try? handle.close()
}
exit(streng && hatFalsche(zeilen) ? 1 : 0)
