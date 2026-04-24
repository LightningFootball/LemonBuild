// swift-tools-version:5.9
import PackageDescription

// v0.1.0: 骨架占位。
// 各个 xcframework 构建就绪后，会在此文件中通过 .binaryTarget 暴露。
// 计划模块：Libmpv / FFmpeg / Libass / FreeType / HarfBuzz / Fribidi /
//         Libplacebo / Shaderc / MoltenVK / Dav1d / Uchardet
let package = Package(
    name: "LemonBuild",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(name: "LemonBuild", targets: ["LemonBuild"]),
    ],
    targets: [
        .target(name: "LemonBuild", path: "Sources/LemonBuild"),
    ]
)
