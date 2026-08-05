// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OmniaDomain",
    products: [
        .library(name: "OmniaDomain", targets: ["OmniaDomain"]),
    ],
    dependencies: [
        .package(path: "../OmniaFoundation"),
    ],
    targets: [
        .target(
            name: "OmniaDomain",
            dependencies: ["OmniaFoundation"]
        ),
        .testTarget(
            name: "OmniaDomainTests",
            dependencies: ["OmniaDomain"]
        ),
    ]
)
