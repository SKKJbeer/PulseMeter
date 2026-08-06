// swift-tools-version: 6.0
import PackageDescription

// PulseUI ist das Design-System: Farben, Typografie und die Komponenten aus
// docs/03-ux-konzept.md. Es kennt keine Fachbegriffe — eine Komponente heißt
// `ValueCard`, nicht `MeterCard`, damit sie nicht an einen Anwendungsfall
// gebunden ist (ADR-003).
//
// Bewusst nur iOS: Das System lebt von UIKit-Merkmalen wie dynamischen Farben
// und Dynamic Type. Eine macOS-Fassung wäre Aufwand ohne Nutzen, solange es
// keine Mac-App gibt.
let package = Package(
    name: "PulseUI",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PulseUI", targets: ["PulseUI"])
    ],
    targets: [
        .target(name: "PulseUI", swiftSettings: [.swiftLanguageMode(.v6)])
    ]
)
