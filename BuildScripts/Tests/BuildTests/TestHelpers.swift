import Foundation
@testable import Build

extension Toolchain {
    /// Deterministic toolchain for unit tests — no xcrun lookups.
    static func mock(
        platform: Platform,
        arch: Arch = .arm64,
        minOSVersion: String = "16.0"
    ) -> Toolchain {
        Toolchain(
            platform: platform,
            arch: arch,
            minOSVersion: minOSVersion,
            sdkPath: "/fake/sdk/\(platform.sdkName)",
            clangPath: "/fake/bin/clang",
            clangxxPath: "/fake/bin/clang++",
            arPath: "/fake/bin/ar",
            ranlibPath: "/fake/bin/ranlib",
            ldPath: "/fake/bin/ld",
            stripPath: "/fake/bin/strip"
        )
    }
}
