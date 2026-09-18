// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "AIDownloadsManager",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AIDownloadsManager",
            path: "Sources/AIDownloadsManager"
        ),
        .testTarget(
            name: "AIDownloadsManagerTests",
            dependencies: ["AIDownloadsManager"],
            path: "Tests/AIDownloadsManagerTests"
        )
    ]
)
