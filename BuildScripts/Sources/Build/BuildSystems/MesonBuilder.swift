import Foundation

/// Orchestrates a meson + ninja build for a single slice.
struct MesonBuilder {
    let toolchain: Toolchain
    let sourceDir: URL
    let buildDir: URL
    let installDir: URL
    let extraSetupArgs: [String]
    let extraEnv: [String: String]

    init(
        toolchain: Toolchain,
        sourceDir: URL,
        buildDir: URL,
        installDir: URL,
        extraSetupArgs: [String] = [],
        extraEnv: [String: String] = [:]
    ) {
        self.toolchain = toolchain
        self.sourceDir = sourceDir
        self.buildDir = buildDir
        self.installDir = installDir
        self.extraSetupArgs = extraSetupArgs
        self.extraEnv = extraEnv
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
        try Shell.run("meson", args: args, env: extraEnv, currentDirectory: sourceDir)
    }

    func build() throws {
        try Shell.run("meson", args: ["compile", "-C", buildDir.path], env: extraEnv)
    }

    func install() throws {
        try Shell.run("meson", args: ["install", "-C", buildDir.path], env: extraEnv)
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
