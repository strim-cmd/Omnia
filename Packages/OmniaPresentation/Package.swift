// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OmniaPresentation",
    products: [
        .library(name: "OmniaPresentation", targets: ["OmniaPresentation"]),
    ],
    dependencies: [
        .package(path: "../OmniaApplication"),
        .package(path: "../OmniaFoundation"),
    ],
    targets: [
        .target(
            name: "OmniaPresentation",
            dependencies: ["OmniaApplication", "OmniaFoundation"]
        ),
        .testTarget(
            name: "OmniaPresentationTests",
            dependencies: ["OmniaPresentation"]
        ),
    ]
)
