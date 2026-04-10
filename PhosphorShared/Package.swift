// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PhosphorShared",
    // NOTE: Requires Xcode 26+ for full iOS 26 API support.
    // Using .v18 as minimum so the package resolves on current toolchains.
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "PhosphorShared",
            targets: ["PhosphorShared"]
        ),
    ],
    targets: [
        .target(name: "PhosphorShared"),
        .testTarget(
            name: "PhosphorSharedTests",
            dependencies: ["PhosphorShared"]
        ),
    ]
)
