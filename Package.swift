// swift-tools-version:5.9
import PackageDescription

// v0.1.0: 骨架 + 已构建产物。
// 各 xcframework 构建就绪后在此暴露为 .binaryTarget。
// 计划模块：Libmpv / FFmpeg / Libass / FreeType / HarfBuzz / Fribidi /
//         Libplacebo / Shaderc / MoltenVK / Dav1d / Uchardet
let package = Package(
    name: "LemonBuild",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(name: "LemonBuild", targets: ["LemonBuild"]),
        .library(name: "Dav1d", targets: ["Dav1d"]),
    ],
    targets: [
        .target(name: "LemonBuild", path: "Sources/LemonBuild"),
        .binaryTarget(name: "Dav1d", path: "Frameworks/Dav1d.xcframework"),
        .testTarget(
            name: "LemonBuildTests",
            dependencies: ["LemonBuild", "Dav1d"],
            path: "Tests/LemonBuildTests"
        ),
    ]
)
