import Foundation

/// Orchestrates a `./configure && make && make install` build.
struct AutotoolsBuilder {
    let toolchain: Toolchain
    let sourceDir: URL
    let buildDir: URL
    let installDir: URL
    let extraConfigureArgs: [String]
    let jobs: Int

    init(
        toolchain: Toolchain,
        sourceDir: URL,
        buildDir: URL,
        installDir: URL,
        extraConfigureArgs: [String] = [],
        jobs: Int = ProcessInfo.processInfo.activeProcessorCount
    ) {
        self.toolchain = toolchain
        self.sourceDir = sourceDir
        self.buildDir = buildDir
        self.installDir = installDir
        self.extraConfigureArgs = extraConfigureArgs
        self.jobs = jobs
    }

    func configure() throws {
        try? FileManager.default.removeItem(at: buildDir)
        try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
        let env = AutotoolsEnv(toolchain: toolchain)
        var args = env.defaultConfigureArgs
        args.append("--prefix=\(installDir.path)")
        args.append(contentsOf: extraConfigureArgs)
        let configure = sourceDir.appendingPathComponent("configure")
        try Shell.run(configure.path, args: args, env: env.render(), currentDirectory: buildDir)
    }

    func build() throws {
        try Shell.run("make", args: ["-j\(jobs)"], currentDirectory: buildDir)
    }

    func install() throws {
        try Shell.run("make", args: ["install"], currentDirectory: buildDir)
    }
}
