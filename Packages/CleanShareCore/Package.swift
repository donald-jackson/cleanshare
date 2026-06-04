// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CleanShareCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "CleanShareCore",
            targets: ["CleanShareCore"]
        ),
        .executable(
            name: "cleanshare-cli",
            targets: ["cleanshare-cli"]
        )
    ],
    targets: [
        .target(
            name: "CleanShareCore",
            path: "Sources/CleanShareCore"
        ),
        .executableTarget(
            name: "cleanshare-cli",
            dependencies: ["CleanShareCore"],
            path: "Sources/CleanShareCoreCLI"
        ),
        .testTarget(
            name: "CleanShareCoreTests",
            dependencies: ["CleanShareCore"],
            path: "Tests/CleanShareCoreTests",
            resources: [.copy("Fixtures")]
        )
    ]
)
