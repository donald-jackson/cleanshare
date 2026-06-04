// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CleanShareCore",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "CleanShareCore",
            targets: ["CleanShareCore"]
        )
    ],
    targets: [
        .target(
            name: "CleanShareCore",
            path: "Sources/CleanShareCore"
        ),
        .testTarget(
            name: "CleanShareCoreTests",
            dependencies: ["CleanShareCore"],
            path: "Tests/CleanShareCoreTests"
        )
    ]
)
