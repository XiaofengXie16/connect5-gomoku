// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Connect5",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Connect5",
            path: "Sources/Connect5"
        )
    ]
)
