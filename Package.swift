// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AssetManager",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AssetManager",
            path: "Sources"
        )
    ]
)
