// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OmniaFoundation",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "OmniaFoundation", targets: ["OmniaFoundation"]),
    ],
    targets: [
        .target(name: "OmniaFoundation"),
        .testTarget(
            name: "OmniaFoundationTests",
            dependencies: ["OmniaFoundation"]
        ),
    ]
)
