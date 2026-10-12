// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProgressTracker",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ProgressTracker", targets: ["ProgressTracker"])
    ],
    targets: [
        .executableTarget(
            name: "ProgressTracker",
            path: "Sources/ProgressTracker"
        )
    ]
)
