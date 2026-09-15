// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenSide",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // 다른 앱이 의존할 수 있도록 코어를 라이브러리로 노출
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
