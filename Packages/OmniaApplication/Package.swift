// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OmniaApplication",
    products: [
        .library(name: "OmniaApplication", targets: ["OmniaApplication"]),
    ],
    dependencies: [
        .package(path: "../OmniaDomain"),
        .package(path: "../OmniaFoundation"),
    ],
    targets: [
        .target(
            name: "OmniaApplication",
            dependencies: ["OmniaDomain", "OmniaFoundation"]
        ),
        .testTarget(
            name: "OmniaApplicationTests",
            dependencies: ["OmniaApplication"]
        ),
    ]
)
