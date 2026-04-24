import Foundation

struct HarfbuzzBuilder: LibraryBuilder {
    let spec = LibrarySpec(
        name: "harfbuzz",
        version: "8.5.0",
        source: .git(url: "https://github.com/harfbuzz/harfbuzz.git", ref: "8.5.0"),
        buildSystem: .meson,
        dependencies: ["freetype"],
        xcframeworkName: "Harfbuzz",
        moduleName: "Harfbuzz"
    )

    func buildSlice(context: BuildContext) throws -> InstallArtifact {
        let meson = MesonBuilder(
            toolchain: context.toolchain,
            sourceDir: context.sourceDir,
            buildDir: context.buildDir,
            installDir: context.installDir,
            extraSetupArgs: [
                "-Dfreetype=enabled",
                "-Dglib=disabled",
                "-Dgobject=disabled",
                "-Dcairo=disabled",
                "-Dicu=disabled",
                "-Dgraphite=disabled",
                "-Dchafa=disabled",
                "-Dcoretext=disabled",
                "-Dtests=disabled",
                "-Dbenchmark=disabled",
                "-Ddocs=disabled",
                "-Dutilities=disabled"
            ],
            extraEnv: context.pkgConfigEnv
        )
        try meson.configure()
        try meson.build()
        try meson.install()

        let staticLib = context.installDir.appendingPathComponent("lib/libharfbuzz.a")
        let stage = context.installDir.appendingPathComponent("Headers")
        try HeadersStager.stage(
            source: context.installDir.appendingPathComponent("include"),
            stageRoot: stage,
            moduleName: spec.moduleName,
            umbrellaHeader: "harfbuzz/hb.h"
        )
        return InstallArtifact(staticLibrary: staticLib, headersRoot: stage)
    }
}
