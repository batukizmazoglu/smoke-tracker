// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SmokeTrackerCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SmokeTrackerCore", targets: ["SmokeTrackerCore"]),
    ],
    targets: [
        .target(name: "SmokeTrackerCore"),
        .testTarget(
            name: "SmokeTrackerCoreTests",
            dependencies: ["SmokeTrackerCore"]
        ),
    ]
)
