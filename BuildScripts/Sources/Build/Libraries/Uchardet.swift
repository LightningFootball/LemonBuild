import Foundation

struct UchardetBuilder: LibraryBuilder {
    let spec = LibrarySpec(
        name: "uchardet",
        version: "v0.0.8",
        source: .git(url: "https://gitlab.freedesktop.org/uchardet/uchardet.git", ref: "v0.0.8"),
        buildSystem: .cmake,
        dependencies: [],
        xcframeworkName: "Uchardet",
        moduleName: "Uchardet"
    )

    func buildSlice(context: BuildContext) throws -> InstallArtifact {
        let cmake = CMakeBuilder(
            toolchain: context.toolchain,
            sourceDir: context.sourceDir,
            buildDir: context.buildDir,
            installDir: context.installDir,
            extraConfigureArgs: [
                // uchardet 0.0.8's CMakeLists requests CMake < 3.5 which
                // modern CMake rejects; pin the policy floor so it still parses.
                "-DCMAKE_POLICY_VERSION_MINIMUM=3.5",
                "-DBUILD_BINARY=OFF",
                "-DBUILD_STATIC=ON"
            ],
            extraEnv: context.pkgConfigEnv
        )
        try cmake.configure()
        try cmake.build()
        try cmake.install()

        let staticLib = context.installDir.appendingPathComponent("lib/libuchardet.a")
        let stage = context.installDir.appendingPathComponent("Headers")
        try HeadersStager.stage(
            source: context.installDir.appendingPathComponent("include"),
            stageRoot: stage,
            moduleName: spec.moduleName,
            umbrellaHeader: "uchardet/uchardet.h"
        )
        return InstallArtifact(staticLibrary: staticLib, headersRoot: stage)
    }
}
