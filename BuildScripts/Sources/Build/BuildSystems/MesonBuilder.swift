import Foundation

/// Orchestrates a meson + ninja build for a single slice.
///
/// Stage 1: structure only. Stage 2+ fills in concrete `setup` flags per library.
struct MesonBuilder {
    let toolchain: Toolchain
    let sourceDir: URL
    let buildDir: URL
    let installDir: URL
    let extraSetupArgs: [String]

    init(
        toolchain: Toolchain,
        sourceDir: URL,
        buildDir: URL,
        installDir: URL,
        extraSetupArgs: [String] = []
    ) {
        self.toolchain = toolchain
        self.sourceDir = sourceDir
        self.buildDir = buildDir
        self.installDir = installDir
        self.extraSetupArgs = extraSetupArgs
    }

    func configure() throws {
        try? FileManager.default.removeItem(at: buildDir)
        let crossFile = try writeCrossFile()
        var args: [String] = [
            "setup",
            buildDir.path,
            "--cross-file", crossFile.path,
            "--prefix", installDir.path,
            "--buildtype", "release",
            "--default-library", "static",
            "--libdir", "lib"
        ]
        args.append(contentsOf: extraSetupArgs)
        try Shell.run("meson", args: args, currentDirectory: sourceDir)
    }

    func build() throws {
        try Shell.run("meson", "compile", "-C", buildDir.path)
    }

    func install() throws {
        try Shell.run("meson", "install", "-C", buildDir.path)
    }

    private func writeCrossFile() throws -> URL {
        let fm = FileManager.default
        let dir = buildDir.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("meson-cross-\(toolchain.platform.sliceName).ini")
        let contents = MesonCrossFile(toolchain: toolchain).render()
        try contents.write(to: file, atomically: true, encoding: .utf8)
        return file
    }
}
