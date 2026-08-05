// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OmniaApp",
    products: [
        .library(name: "OmniaApp", targets: ["OmniaApp"]),
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
        .testTarget(
            name: "OmniaAppTests",
            dependencies: ["OmniaApp"]
        ),
    ]
)
