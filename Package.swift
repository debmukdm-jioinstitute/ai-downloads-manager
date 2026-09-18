// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Nest",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Nest",
            path: "Sources/Nest"
        ),
        .testTarget(
            name: "NestTests",
            dependencies: ["Nest"],
            path: "Tests/NestTests"
        )
    ]
)
