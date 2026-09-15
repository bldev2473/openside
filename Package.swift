// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenSide",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "OpenSide",
            targets: ["OpenSide"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "OpenSide",
            dependencies: [],
            path: "Sources/OpenSide"
        ),
        .testTarget(
            name: "OpenSideTests",
            dependencies: ["OpenSide"],
            path: "Tests/OpenSideTests"
        )
    ]
)
