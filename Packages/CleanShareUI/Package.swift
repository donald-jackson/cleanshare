// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CleanShareUI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CleanShareUI",
            targets: ["CleanShareUI"]
        )
    ],
    dependencies: [
        .package(path: "../CleanShareCore")
    ],
    targets: [
        .target(
            name: "CleanShareUI",
            dependencies: [
                .product(name: "CleanShareCore", package: "CleanShareCore")
            ],
            path: "Sources/CleanShareUI"
        ),
        .testTarget(
            name: "CleanShareUITests",
            dependencies: ["CleanShareUI"],
            path: "Tests/CleanShareUITests"
        )
    ]
)
