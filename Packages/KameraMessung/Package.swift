// swift-tools-version: 6.0
import PackageDescription

// Misst, was die Texterkennung des Telefons auf den Zählerfotos in
// `docs/kamera/` liest und was `MeterTextReader` daraus macht.
//
// **Eigenes Paket und nicht Teil von PulseCore**, weil Vision ein Apple-Rahmen
// ist und PulseCore ausschließlich Foundation importiert (ADR-003). Unter Linux
// baut das Paket trotzdem: Der Vision-Teil fällt dort weg, und das Werkzeug
// liest die gelesenen Texte aus einer Datei (`--texte`). So lässt sich alles
// außer dem Aufruf von Vision ohne Mac prüfen.
let package = Package(
    name: "KameraMessung",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "kamera-messen", targets: ["KameraMessen"])
    ],
    dependencies: [
        .package(path: "../PulseCore")
    ],
    targets: [
        .executableTarget(
            name: "KameraMessen",
            dependencies: [.product(name: "PulseCore", package: "PulseCore")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
