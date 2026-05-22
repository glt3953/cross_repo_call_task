// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CrossRepoCall",
    platforms: [
        .macOS(.v12),
    ],
    targets: [
        .executableTarget(
            name: "CrossRepoCall",
            dependencies: [],
            path: "Sources"),
    ]
)
