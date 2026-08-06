// swift-tools-version: 6.0
import PackageDescription

// PulseCore ist die Domänenschicht von PulseMeter.
//
// Bewusste Einschränkung: Dieses Paket importiert ausschließlich Foundation.
// Kein SwiftUI, kein SwiftData, kein CloudKit. Dadurch ist der Rechenkern
// plattformunabhängig testbar — auch ohne Xcode und ohne Simulator.
// Siehe docs/01-architektur.md, ADR-003.
let package = Package(
    name: "PulseCore",
    // Ohne diese Angabe nimmt SwiftPM auf Apple-Plattformen eine sehr alte
    // Mindestversion an, und Sprachmittel wie `Identifiable` gelten dort als
    // nicht verfügbar. Unter Linux gibt es keine Verfügbarkeitsprüfung — der
    // Fehler zeigt sich also erst beim Bauen auf einem Mac.
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "PulseCore", targets: ["PulseCore"])
    ],
    targets: [
        .target(
            name: "PulseCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PulseCoreTests",
            dependencies: ["PulseCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
