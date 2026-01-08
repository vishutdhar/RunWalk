// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RunWalkFeature",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        // Shared code - platform agnostic models and types
        .library(
            name: "RunWalkShared",
            targets: ["RunWalkShared"]
        ),
        // iOS-specific features
        .library(
            name: "RunWalkFeature",
            targets: ["RunWalkFeature"]
        ),
        // watchOS-specific features
        .library(
            name: "RunWalkWatchFeature",
            targets: ["RunWalkWatchFeature"]
        ),
    ],
    targets: [
        // Shared target - platform agnostic types used by both iOS and watchOS
        .target(
            name: "RunWalkShared",
            path: "Sources/RunWalkShared"
        ),
        // iOS target - depends on shared code
        .target(
            name: "RunWalkFeature",
            dependencies: ["RunWalkShared"],
            path: "Sources/RunWalkFeature"
        ),
        // watchOS target - depends on shared code
        .target(
            name: "RunWalkWatchFeature",
            dependencies: ["RunWalkShared"],
            path: "Sources/RunWalkWatchFeature"
        ),
        // Tests for iOS features
        .testTarget(
            name: "RunWalkFeatureTests",
            dependencies: [
                "RunWalkFeature",
                "RunWalkShared"
            ]
        ),
    ]
)
