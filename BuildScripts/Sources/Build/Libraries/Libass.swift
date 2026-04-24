import Foundation

struct LibassBuilder: LibraryBuilder {
    let spec = LibrarySpec(
        name: "libass",
        version: "0.17.3",
        source: .git(url: "https://github.com/libass/libass.git", ref: "0.17.3"),
        buildSystem: .autotools,
        dependencies: ["freetype", "fribidi", "harfbuzz"],
        xcframeworkName: "Libass",
        moduleName: "Libass"
    )

    func buildSlice(context: BuildContext) throws -> InstallArtifact {
        let autotools = AutotoolsBuilder(
            toolchain: context.toolchain,
            sourceDir: context.sourceDir,
            buildDir: context.buildDir,
            installDir: context.installDir,
            extraConfigureArgs: [
                // Don't pull in any system font provider; Lemon registers fonts
                // directly via ass_add_font().
                "--disable-fontconfig",
                "--disable-coretext",
                "--disable-require-system-font-provider"
            ],
            extraEnv: context.pkgConfigEnv,
            runAutogen: true
        )
        try autotools.configure()
        try autotools.build()
        try autotools.install()

        let staticLib = context.installDir.appendingPathComponent("lib/libass.a")
        let stage = context.installDir.appendingPathComponent("Headers")
        try HeadersStager.stage(
            source: context.installDir.appendingPathComponent("include"),
            stageRoot: stage,
            moduleName: spec.moduleName,
            umbrellaHeader: "ass/ass.h"
        )
        return InstallArtifact(staticLibrary: staticLib, headersRoot: stage)
    }
}
