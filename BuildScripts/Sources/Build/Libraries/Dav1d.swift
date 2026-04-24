import Foundation

struct Dav1dBuilder: LibraryBuilder {
    let spec = LibrarySpec(
        name: "dav1d",
        version: "1.5.1",
        source: .git(url: "https://code.videolan.org/videolan/dav1d.git", ref: "1.5.1"),
        buildSystem: .meson,
        dependencies: [],
        xcframeworkName: "Dav1d",
        moduleName: "Dav1d"
    )

    func buildSlice(toolchain: Toolchain, sourceDir: URL, workspace: URL) throws -> InstallArtifact {
        let slice = toolchain.platform.sliceName
        let buildDir = workspace.appendingPathComponent("build/\(slice)")
        let installDir = workspace.appendingPathComponent("install/\(slice)")

        let meson = MesonBuilder(
            toolchain: toolchain,
            sourceDir: sourceDir,
            buildDir: buildDir,
            installDir: installDir,
            extraSetupArgs: [
                "-Denable_tools=false",
                "-Denable_tests=false",
                "-Denable_examples=false"
            ]
        )
        try meson.configure()
        try meson.build()
        try meson.install()

        let staticLib = installDir.appendingPathComponent("lib/libdav1d.a")
        let headersDir = installDir.appendingPathComponent("include")
        try ModuleMapWriter.write(
            to: headersDir,
            module: spec.moduleName,
            umbrellaHeader: "dav1d/dav1d.h"
        )
        return InstallArtifact(staticLibrary: staticLib, headersRoot: headersDir)
    }
}
