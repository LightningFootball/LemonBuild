import Foundation

/// Renders env-var / configure-flag payload for autotools-style builds.
struct AutotoolsEnv {
    let toolchain: Toolchain

    /// Env vars exported before `./configure` and `make` run.
    func render() -> [String: String] {
        let tc = toolchain
        let cflags = tc.cFlags.joined(separator: " ")
        let ldflags = tc.ldFlags.joined(separator: " ")
        return [
            "CC": tc.clangPath,
            "CXX": tc.clangxxPath,
            "AR": tc.arPath,
            "RANLIB": tc.ranlibPath,
            "STRIP": tc.stripPath,
            "CFLAGS": cflags,
            "CXXFLAGS": cflags,
            "OBJCFLAGS": cflags,
            "LDFLAGS": ldflags
        ]
    }

    /// Default `./configure` flags for a static iOS build.
    var defaultConfigureArgs: [String] {
        [
            "--host=\(toolchain.configureHost)",
            "--enable-static",
            "--disable-shared"
        ]
    }
}
