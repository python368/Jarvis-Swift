// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Relay",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Relay",
            targets: ["Relay"])
    ],
    targets: [
        .target(
            name: "Relay",
            dependencies: []),
        .testTarget(
            name: "RelayTests",
            dependencies: ["Relay"])
    ]
)