// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BuildScripts",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "build", targets: ["Build"])
    ],
    targets: [
        .executableTarget(
            name: "Build",
            path: "Sources/Build"
        ),
        .testTarget(
            name: "BuildTests",
            dependencies: ["Build"],
            path: "Tests/BuildTests"
        )
    ]
)
