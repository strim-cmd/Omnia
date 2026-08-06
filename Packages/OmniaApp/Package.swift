// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OmniaApp",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "OmniaApp", targets: ["OmniaApp"]),
        .executable(name: "Omnia", targets: ["OmniaAppExecutable"]),
    ],
    dependencies: [
        .package(path: "../OmniaPresentation"),
        .package(path: "../OmniaApplication"),
        .package(path: "../OmniaInfrastructure"),
        .package(path: "../OmniaDomain"),
        .package(path: "../OmniaFoundation"),
    ],
    targets: [
        .target(
            name: "OmniaApp",
            dependencies: [
                "OmniaPresentation",
                "OmniaApplication",
                "OmniaInfrastructure",
                "OmniaDomain",
                "OmniaFoundation",
            ]
        ),
        .executableTarget(
            name: "OmniaAppExecutable",
            dependencies: [
                "OmniaApp",
                "OmniaPresentation",
            ]
        ),
        .testTarget(
            name: "OmniaAppTests",
            dependencies: ["OmniaApp"]
        ),
    ]
)
