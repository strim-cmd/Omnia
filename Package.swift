// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Omnia",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    dependencies: [
        .package(path: "Packages/OmniaFoundation"),
        .package(path: "Packages/OmniaDomain"),
        .package(path: "Packages/OmniaApplication"),
        .package(path: "Packages/OmniaInfrastructure"),
        .package(path: "Packages/OmniaPresentation"),
        .package(path: "Packages/OmniaApp"),
    ],
    targets: [
        .target(
            name: "Omnia",
            dependencies: [
                "OmniaFoundation",
                "OmniaDomain",
                "OmniaApplication",
                "OmniaInfrastructure",
                "OmniaPresentation",
                "OmniaApp",
            ]
        ),
        .testTarget(
            name: "OmniaTests",
            dependencies: ["Omnia"]
        ),
    ]
)
