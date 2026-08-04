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
