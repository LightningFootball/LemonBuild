import Foundation

/// Renders a CMake toolchain file targeting one iOS slice.
struct CMakeToolchain {
    let toolchain: Toolchain

    func render() -> String {
        let tc = toolchain
        var lines: [String] = []

        lines.append("# LemonBuild CMake toolchain file for \(tc.platform.sliceName)")
        lines.append("set(CMAKE_SYSTEM_NAME iOS)")
        lines.append("set(CMAKE_SYSTEM_PROCESSOR \(tc.arch.cmakeProcessor))")
        lines.append("set(CMAKE_OSX_SYSROOT \(tc.sdkPath))")
        lines.append("set(CMAKE_OSX_ARCHITECTURES \(tc.arch.clangArch))")
        lines.append("set(CMAKE_OSX_DEPLOYMENT_TARGET \(tc.minOSVersion))")
        lines.append("set(CMAKE_C_COMPILER \(tc.clangPath))")
        lines.append("set(CMAKE_CXX_COMPILER \(tc.clangxxPath))")
        lines.append("set(CMAKE_AR \(tc.arPath) CACHE FILEPATH \"\" FORCE)")
        lines.append("set(CMAKE_RANLIB \(tc.ranlibPath) CACHE FILEPATH \"\" FORCE)")
        lines.append("set(CMAKE_C_COMPILER_TARGET \(tc.targetTriple))")
        lines.append("set(CMAKE_CXX_COMPILER_TARGET \(tc.targetTriple))")
        lines.append("set(CMAKE_FIND_ROOT_PATH \(tc.sdkPath))")
        lines.append("set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)")
        lines.append("set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)")
        lines.append("set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)")
        lines.append("set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)")
        if tc.platform == .iOSSimulator {
            lines.append("set(CMAKE_XCODE_EFFECTIVE_PLATFORMS -iphonesimulator)")
        }
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
