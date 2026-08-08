// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OmniaPresentation",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
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
