import Foundation

/// Concrete set of compiler / linker paths and flags for one (platform, arch) slice.
///
/// All tool paths are injected rather than discovered at render time, so the
/// toolchain generators can be unit-tested deterministically. Use
/// `Toolchain.resolve(platform:)` at runtime to populate from the active Xcode.
struct Toolchain {
    let platform: Platform
    let arch: Arch
    let minOSVersion: String
    let sdkPath: String
    let clangPath: String
    let clangxxPath: String
    let arPath: String
    let ranlibPath: String
    let ldPath: String
    let stripPath: String

    /// `arm64-apple-ios16.0` or `arm64-apple-ios16.0-simulator`.
    var targetTriple: String {
        "\(arch.clangArch)-apple-ios\(minOSVersion)\(platform.tripleSuffix)"
    }

    var cFlags: [String] {
        [
            "-arch", arch.clangArch,
            "-isysroot", sdkPath,
            "-target", targetTriple,
            "-fPIC",
            "-O2"
        ]
    }

    var ldFlags: [String] {
        [
            "-arch", arch.clangArch,
            "-isysroot", sdkPath,
            "-target", targetTriple
        ]
    }

    /// `--host=arm64-apple-darwin` — used by autotools configure.
    var configureHost: String {
        "\(arch.clangArch)-apple-darwin"
    }
}

extension Toolchain {
    /// Resolve the active Xcode's clang/ar/… for the given platform.
    static func resolve(
        platform: Platform,
        arch: Arch = .arm64,
        minOSVersion: String = "16.0"
    ) throws -> Toolchain {
        func trim(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
        let sdk = trim(try Shell.run("xcrun", "--sdk", platform.sdkName, "--show-sdk-path"))
        func find(_ tool: String) throws -> String {
            trim(try Shell.run("xcrun", "--sdk", platform.sdkName, "--find", tool))
        }
        return Toolchain(
            platform: platform,
            arch: arch,
            minOSVersion: minOSVersion,
            sdkPath: sdk,
            clangPath: try find("clang"),
            clangxxPath: try find("clang++"),
            arPath: try find("ar"),
            ranlibPath: try find("ranlib"),
            ldPath: try find("ld"),
            stripPath: try find("strip")
        )
    }
}
