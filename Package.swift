// swift-tools-version:5.9
// For editing in Xcode (`open Package.swift`). The app bundle itself is built by scripts/build.sh.
import PackageDescription

let package = Package(
    name: "Spaceport",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "Spaceport",
            path: "Sources/Spaceport",
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
