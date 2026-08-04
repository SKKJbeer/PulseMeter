// swift-tools-version: 6.0
import PackageDescription

// PulseData ist die Persistenzschicht: SwiftData-Modelle als Spiegel der
// Domänentypen aus PulseCore, dahinter CloudKit.
//
// Die Abhängigkeit zeigt nur in eine Richtung — PulseCore kennt dieses Paket
// nicht. Dadurch bleibt der Rechenkern ohne Apple-Frameworks und damit auch
// ohne Xcode prüfbar. Siehe docs/01-architektur.md, ADR-002 und ADR-003.
let package = Package(
    name: "PulseData",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "PulseData", targets: ["PulseData"])
    ],
    dependencies: [
        .package(path: "../PulseCore")
    ],
    targets: [
        .target(
            name: "PulseData",
            dependencies: ["PulseCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PulseDataTests",
            dependencies: ["PulseData", "PulseCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
