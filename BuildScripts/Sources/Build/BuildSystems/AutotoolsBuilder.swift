import Foundation

/// Orchestrates a `./configure && make && make install` build.
struct AutotoolsBuilder {
    let toolchain: Toolchain
    let sourceDir: URL
    let buildDir: URL
    let installDir: URL
    let extraConfigureArgs: [String]
    let extraEnv: [String: String]
    let runAutogen: Bool
    let jobs: Int

    init(
        toolchain: Toolchain,
        sourceDir: URL,
        buildDir: URL,
        installDir: URL,
        extraConfigureArgs: [String] = [],
        extraEnv: [String: String] = [:],
        runAutogen: Bool = false,
        jobs: Int = ProcessInfo.processInfo.activeProcessorCount
    ) {
        self.toolchain = toolchain
        self.sourceDir = sourceDir
        self.buildDir = buildDir
        self.installDir = installDir
        self.extraConfigureArgs = extraConfigureArgs
        self.extraEnv = extraEnv
        self.runAutogen = runAutogen
        self.jobs = jobs
    }

    func configure() throws {
        try? FileManager.default.removeItem(at: buildDir)
        try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)

        if runAutogen {
            let configureURL = sourceDir.appendingPathComponent("configure")
            if !FileManager.default.fileExists(atPath: configureURL.path) {
                try Shell.run("autoreconf", args: ["-fi"], currentDirectory: sourceDir)
            }
        }

        var env = AutotoolsEnv(toolchain: toolchain).render()
        env.merge(extraEnv) { _, new in new }
        var args = AutotoolsEnv(toolchain: toolchain).defaultConfigureArgs
        args.append("--prefix=\(installDir.path)")
        args.append(contentsOf: extraConfigureArgs)
        let configure = sourceDir.appendingPathComponent("configure")
        try Shell.run(configure.path, args: args, env: env, currentDirectory: buildDir)
    }

    func build() throws {
        try Shell.run("make", args: ["-j\(jobs)"], env: extraEnv, currentDirectory: buildDir)
    }

    func install() throws {
        try Shell.run("make", args: ["install"], env: extraEnv, currentDirectory: buildDir)
    }
}
