// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AITokenMenubar",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "AITokenMenubar",
            path: "Sources/AITokenMenubar"
        )
    ]
)
