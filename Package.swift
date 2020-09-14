// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SwiftSnapshotTesting",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_14)
    ],
    products: [
        .library(name: "SwiftSnapshotTesting",
                 targets: ["SwiftSnapshotTesting"]),
    ],
    dependencies: [
        .package(url: "https://github.com/s1ddok/Alloy.git",
                 .branch("swiftpm2")),
        .package(url: "https://github.com/devicekit/DeviceKit.git",
                 from: "4.0.0"),
        .package(url: "https://github.com/eugenebokhan/ResourcesBridge.git",
                 from: "0.0.2")
    ],
    targets: [
        .target(name: "SwiftSnapshotTesting",
                dependencies: [
                    "Alloy",
                    "DeviceKit",
                    "ResourcesBridge"
                ],
                resources: [
                    .process("Shaders/Shaders.metal"),
                ],
                swiftSettings: [
                    .define("SwiftPM")
                ],
                linkerSettings: [
                    .linkedFramework("Metal"),
                    .linkedFramework("MetalPerformanceShaders")
                ])
    ]
)
