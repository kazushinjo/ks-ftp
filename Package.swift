// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FTPClient",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "FTPClient",
            path: "Sources/FTPClient",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
