// swift-tools-version: 5.9
import PackageDescription

// Regelmotorn för Skoväder. Ren Swift (bara Foundation) så att den kan
// testas med `swift test` på både macOS och Linux, utan simulator.
let package = Package(
    name: "SkovaderEngine",
    defaultLocalization: "sv",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SkovaderEngine", targets: ["SkovaderEngine"]),
    ],
    targets: [
        .target(
            name: "SkovaderEngine",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "SkovaderEngineTests",
            dependencies: ["SkovaderEngine"]
        ),
    ]
)
