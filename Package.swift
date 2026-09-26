// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenSide",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // Expose core as a library so other apps can depend on it
        .library(
            name: "OpenSideCore",
            targets: ["OpenSideCore"]
        ),
        .executable(
            name: "OpenSide",
            targets: ["OpenSide"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "OpenSideCore",
            dependencies: [],
            path: "Sources/OpenSideCore"
        ),
        .executableTarget(
            name: "OpenSide",
            dependencies: ["OpenSideCore"],
            path: "Sources/OpenSide"
        ),
        .testTarget(
            name: "OpenSideTests",
            dependencies: ["OpenSideCore"],
            path: "Tests/OpenSideTests"
        )
    ]
)
