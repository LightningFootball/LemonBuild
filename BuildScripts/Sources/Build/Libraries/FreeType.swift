import Foundation

struct FreeTypeBuilder: LibraryBuilder {
    let spec = LibrarySpec(
        name: "freetype",
        version: "VER-2-13-3",
        source: .git(url: "https://github.com/freetype/freetype.git", ref: "VER-2-13-3"),
        buildSystem: .meson,
        dependencies: [],
        xcframeworkName: "FreeType",
        moduleName: "FreeType"
    )

    func buildSlice(context: BuildContext) throws -> InstallArtifact {
        // Drop every optional dep. harfbuzz=disabled breaks the FreeType↔HarfBuzz
        // circular dep; HarfBuzz links against *this* lean FreeType.
        let meson = MesonBuilder(
            toolchain: context.toolchain,
            sourceDir: context.sourceDir,
            buildDir: context.buildDir,
            installDir: context.installDir,
            extraSetupArgs: [
                "-Dzlib=disabled",
                "-Dbzip2=disabled",
                "-Dpng=disabled",
                "-Dharfbuzz=disabled",
                "-Dbrotli=disabled",
                "-Dtests=disabled"
            ],
            extraEnv: context.pkgConfigEnv
        )
        try meson.configure()
        try meson.build()
        try meson.install()
        try scrubFalseRequires(installDir: context.installDir)

        let staticLib = context.installDir.appendingPathComponent("lib/libfreetype.a")
        // Leave `include/freetype2/{ft2build.h,freetype/*}` as-is so the
        // generated `freetype2.pc` Cflags stays valid for downstream pkg-config.
        // Mirror those headers into the per-module staging tree for xcframework use.
        let stage = context.installDir.appendingPathComponent("Headers")
        try HeadersStager.stage(
            source: context.installDir.appendingPathComponent("include"),
            stageRoot: stage,
            moduleName: spec.moduleName,
            umbrellaHeader: "freetype2/ft2build.h"
        )
        return InstallArtifact(staticLibrary: staticLib, headersRoot: stage)
    }

    /// FreeType's meson generates `freetype2.pc` with `Requires: bzip2` even
    /// when bzip2 is disabled, which poisons every downstream pkg-config lookup.
    /// Strip it so HarfBuzz / libass can resolve `freetype2` cleanly.
    private func scrubFalseRequires(installDir: URL) throws {
        let pc = installDir.appendingPathComponent("lib/pkgconfig/freetype2.pc")
        guard FileManager.default.fileExists(atPath: pc.path) else { return }
        let content = try String(contentsOf: pc, encoding: .utf8)
        let scrubbed = content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.hasPrefix("Requires") }
            .joined(separator: "\n")
        try scrubbed.write(to: pc, atomically: true, encoding: .utf8)
    }
}
