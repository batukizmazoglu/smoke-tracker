// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SmokeTrackerData",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SmokeTrackerData", targets: ["SmokeTrackerData"]),
    ],
    dependencies: [
        .package(path: "../SmokeTrackerCore"),
    ],
    targets: [
        .target(
            name: "SmokeTrackerData",
            dependencies: [
                .product(name: "SmokeTrackerCore", package: "SmokeTrackerCore")
            ]
        ),
        .testTarget(
            name: "SmokeTrackerDataTests",
            dependencies: ["SmokeTrackerData"]
        ),
    ]
)
