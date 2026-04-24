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
        .library(name: "FreeType", targets: ["FreeType"]),
        .library(name: "Fribidi", targets: ["Fribidi"]),
        .library(name: "Harfbuzz", targets: ["Harfbuzz"]),
        .library(name: "Uchardet", targets: ["Uchardet"]),
        .library(name: "Libass", targets: ["Libass"]),
        .library(name: "MoltenVK", targets: ["MoltenVK"]),
        .library(name: "Shaderc", targets: ["Shaderc"]),
        .library(name: "Libplacebo", targets: ["Libplacebo"]),
    ],
    targets: [
        .target(name: "LemonBuild", path: "Sources/LemonBuild"),
        .binaryTarget(name: "Dav1d", path: "Frameworks/Dav1d.xcframework"),
        .binaryTarget(name: "FreeType", path: "Frameworks/FreeType.xcframework"),
        .binaryTarget(name: "Fribidi", path: "Frameworks/Fribidi.xcframework"),
        .binaryTarget(name: "Harfbuzz", path: "Frameworks/Harfbuzz.xcframework"),
        .binaryTarget(name: "Uchardet", path: "Frameworks/Uchardet.xcframework"),
        .binaryTarget(name: "Libass", path: "Frameworks/Libass.xcframework"),
        .binaryTarget(name: "MoltenVK", path: "Frameworks/MoltenVK.xcframework"),
        .binaryTarget(name: "Shaderc", path: "Frameworks/Shaderc.xcframework"),
        .binaryTarget(name: "Libplacebo", path: "Frameworks/Libplacebo.xcframework"),
        .testTarget(
            name: "LemonBuildTests",
            dependencies: [
                "LemonBuild",
                "Dav1d",
                "FreeType",
                "Fribidi",
                "Harfbuzz",
                "Uchardet",
                "Libass",
                "MoltenVK",
                "Shaderc",
                "Libplacebo",
            ],
            path: "Tests/LemonBuildTests",
            linkerSettings: [
                // libass uses iconv for subtitle charset conversion; iOS ships
                // libiconv in the sysroot, so expose it to the link.
                .linkedLibrary("iconv"),
                // libc++ for shaderc (C++ runtime) and for libplacebo's C++ bits.
                .linkedLibrary("c++"),
                // MoltenVK's Metal/QuartzCore/IOSurface/Foundation dependencies.
                .linkedFramework("Metal"),
                .linkedFramework("Foundation"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("IOSurface"),
            ]
        ),
    ]
)
