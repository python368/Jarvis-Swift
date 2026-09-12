// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JarvisSwift",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "JarvisSwift",
            targets: ["JarvisSwift"])
    ],
    targets: [
        .target(
            name: "JarvisSwift",
            dependencies: []),
        .testTarget(
            name: "JarvisSwiftTests",
            dependencies: ["JarvisSwift"])
    ]
)