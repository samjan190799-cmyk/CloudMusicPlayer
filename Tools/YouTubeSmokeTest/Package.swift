// swift-tools-version:5.9
import PackageDescription

// Консольный смоук-тест YouTube для macOS-раннера.
// Компилирует НАСТОЯЩИЕ файлы приложения (YouTubeService, AudioFileSniffer) — их копирует run.sh.
let package = Package(
    name: "YouTubeSmokeTest",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/alexeichhorn/YouTubeKit", from: "0.4.9")
    ],
    targets: [
        .executableTarget(
            name: "YouTubeSmokeTest",
            dependencies: [.product(name: "YouTubeKit", package: "YouTubeKit")]
        )
    ]
)
