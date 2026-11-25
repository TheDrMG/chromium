// swift-tools-version: 6.0
import PackageDescription

// Swift package for building with xtool on Linux (`xtool dev`).
// Shares its sources with UnitConverter.xcodeproj, so either can be used.
let package = Package(
    name: "UnitConverter",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "UnitConverter", targets: ["UnitConverter"]),
    ],
    targets: [
        .target(
            name: "UnitConverter",
            path: "UnitConverter",
            exclude: ["Assets.xcassets"]
        ),
        .testTarget(
            name: "UnitConverterTests",
            dependencies: ["UnitConverter"],
            path: "UnitConverterTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
