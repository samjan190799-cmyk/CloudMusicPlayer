// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CloudMusicPlayer",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "CloudMusicPlayer",
            targets: ["CloudMusicPlayer"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CloudMusicPlayer",
            dependencies: [],
            path: "Sources")
    ]
)
