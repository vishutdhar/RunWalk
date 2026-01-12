// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RunWalkFeature",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14) // Required for running tests on macOS
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
    dependencies: [
        .package(url: "https://github.com/vincentneo/CoreGPX.git", from: "0.9.0")
    ],
    targets: [
        // Shared target - platform agnostic types used by both iOS and watchOS
        .target(
            name: "RunWalkShared",
            dependencies: ["CoreGPX"],
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
        // Tests for shared code (runs on macOS with swift test)
        .testTarget(
            name: "RunWalkSharedTests",
            dependencies: [
                "RunWalkShared"
            ],
            path: "Tests/RunWalkSharedTests"
        ),
        // Tests for iOS-specific code (runs in Xcode on iOS Simulator)
        .testTarget(
            name: "RunWalkFeatureTests",
            dependencies: [
                "RunWalkFeature",
                "RunWalkShared"
            ]
        ),
    ]
)
