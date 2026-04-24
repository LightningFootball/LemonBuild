import Foundation

/// Orchestrates a CMake + ninja (or make) build for a single slice.
struct CMakeBuilder {
    let toolchain: Toolchain
    let sourceDir: URL
    let buildDir: URL
    let installDir: URL
    let extraConfigureArgs: [String]
    let extraEnv: [String: String]
    let generator: String

    init(
        toolchain: Toolchain,
        sourceDir: URL,
        buildDir: URL,
        installDir: URL,
        extraConfigureArgs: [String] = [],
        extraEnv: [String: String] = [:],
        generator: String = "Ninja"
    ) {
        self.toolchain = toolchain
        self.sourceDir = sourceDir
        self.buildDir = buildDir
        self.installDir = installDir
        self.extraConfigureArgs = extraConfigureArgs
        self.extraEnv = extraEnv
        self.generator = generator
    }

    func configure() throws {
        try? FileManager.default.removeItem(at: buildDir)
        try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
        let toolchainFile = try writeToolchainFile()
        var args: [String] = [
            "-S", sourceDir.path,
            "-B", buildDir.path,
            "-G", generator,
            "-DCMAKE_BUILD_TYPE=Release",
            "-DCMAKE_INSTALL_PREFIX=\(installDir.path)",
            "-DCMAKE_TOOLCHAIN_FILE=\(toolchainFile.path)",
            "-DBUILD_SHARED_LIBS=OFF"
        ]
        args.append(contentsOf: extraConfigureArgs)
        try Shell.run("cmake", args: args, env: extraEnv)
    }

    func build() throws {
        try Shell.run("cmake", args: ["--build", buildDir.path], env: extraEnv)
    }

    func install() throws {
        try Shell.run("cmake", args: ["--install", buildDir.path], env: extraEnv)
    }

    private func writeToolchainFile() throws -> URL {
        let dir = buildDir.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("cmake-toolchain-\(toolchain.platform.sliceName).cmake")
        let contents = CMakeToolchain(toolchain: toolchain).render()
        try contents.write(to: file, atomically: true, encoding: .utf8)
        return file
    }
}
