// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Arca",
    // The interface is written in Brazilian Portuguese and translated in Sources/Arca/Resources.
    defaultLocalization: "pt-BR",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Arca",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ArcaTests",
            dependencies: ["Arca"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
