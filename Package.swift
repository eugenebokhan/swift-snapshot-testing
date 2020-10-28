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
                 .upToNextMinor(from: "0.16.3")),
        .package(url: "https://github.com/devicekit/DeviceKit.git",
                 .upToNextMinor(from: "4.2.1")),
        .package(url: "https://github.com/eugenebokhan/ResourcesBridge.git",
                 .upToNextMinor(from: "0.0.3"))
    ],
    targets: [
        .target(name: "SwiftSnapshotTesting",
                dependencies: [
                    "Alloy",
                    "DeviceKit",
                    "ResourcesBridge"
                ],
                resources: [.process("Shaders/Shaders.metal")])
    ]
)
