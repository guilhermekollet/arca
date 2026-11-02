// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Keys",
    // The interface is written in Brazilian Portuguese and translated in Sources/Keys/Resources.
    defaultLocalization: "pt-BR",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Keys",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "KeysTests",
            dependencies: ["Keys"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
