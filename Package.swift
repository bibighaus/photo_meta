// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PhotoMeta",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PhotoMeta",
            path: "Sources/PhotoMeta"
        )
    ]
)
