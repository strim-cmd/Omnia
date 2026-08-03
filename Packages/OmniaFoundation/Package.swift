// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OmniaFoundation",
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
