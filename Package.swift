// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Chaves",
    // The interface is written in Brazilian Portuguese and translated in Sources/Chaves/Resources.
    defaultLocalization: "pt-BR",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Chaves",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ChavesTests",
            dependencies: ["Chaves"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
