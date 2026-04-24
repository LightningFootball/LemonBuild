import Foundation

struct FribidiBuilder: LibraryBuilder {
    let spec = LibrarySpec(
        name: "fribidi",
        version: "v1.0.15",
        source: .git(url: "https://github.com/fribidi/fribidi.git", ref: "v1.0.15"),
        buildSystem: .meson,
        dependencies: [],
        xcframeworkName: "Fribidi",
        moduleName: "Fribidi"
    )

    func buildSlice(context: BuildContext) throws -> InstallArtifact {
        let meson = MesonBuilder(
            toolchain: context.toolchain,
            sourceDir: context.sourceDir,
            buildDir: context.buildDir,
            installDir: context.installDir,
            extraSetupArgs: [
                "-Dtests=false",
                "-Ddocs=false",
                "-Dbin=false"
            ],
            extraEnv: context.pkgConfigEnv
        )
        try meson.configure()
        try meson.build()
        try meson.install()

        let staticLib = context.installDir.appendingPathComponent("lib/libfribidi.a")
        let stage = context.installDir.appendingPathComponent("Headers")
        try HeadersStager.stage(
            source: context.installDir.appendingPathComponent("include"),
            stageRoot: stage,
            moduleName: spec.moduleName,
            umbrellaHeader: "fribidi/fribidi.h"
        )
        return InstallArtifact(staticLibrary: staticLib, headersRoot: stage)
    }
}
