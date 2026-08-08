// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OmniaInfrastructure",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "OmniaInfrastructure", targets: ["OmniaInfrastructure"]),
    ],
    dependencies: [
        .package(path: "../OmniaDomain"),
        .package(path: "../OmniaFoundation"),
    ],
    targets: [
        .target(
            name: "OmniaInfrastructure",
            dependencies: ["OmniaDomain", "OmniaFoundation"]
        ),
        .testTarget(
            name: "OmniaInfrastructureTests",
            dependencies: ["OmniaInfrastructure"]
        ),
    ]
)
