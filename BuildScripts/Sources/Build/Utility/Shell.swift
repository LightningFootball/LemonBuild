import Foundation

/// Thin wrapper around `Process` that captures output and throws on non-zero exit.
enum Shell {
    struct Error: Swift.Error, CustomStringConvertible {
        let command: String
        let args: [String]
        let exitCode: Int32
        let stdout: String
        let stderr: String
        var description: String {
            """
            [\(command)] exited \(exitCode)
            cmd: \(command) \(args.joined(separator: " "))
            stdout: \(stdout)
            stderr: \(stderr)
            """
        }
    }

    @discardableResult
    static func run(
        _ command: String,
        _ args: String...,
        env: [String: String]? = nil,
        currentDirectory: URL? = nil
    ) throws -> String {
        try run(command, args: args, env: env, currentDirectory: currentDirectory)
    }

    @discardableResult
    static func run(
        _ command: String,
        args: [String],
        env: [String: String]? = nil,
        currentDirectory: URL? = nil
    ) throws -> String {
        let process = Process()
        if command.hasPrefix("/") {
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = args
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [command] + args
        }
        if let env {
            process.environment = ProcessInfo.processInfo.environment.merging(env) { _, new in new }
        }
        if let currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        // Drain both pipes concurrently. If we don't, a child that writes more
        // than ~16KB to stderr while we're synchronously draining stdout will
        // block on its stderr write — stdout EOF never comes — and the whole
        // pipeline deadlocks. FFmpeg's `make -j10` with 10 clang children each
        // emitting `-MMD` dependency notes hits that limit within seconds.
        let outQueue = DispatchQueue(label: "lemonbuild.shell.out")
        let errQueue = DispatchQueue(label: "lemonbuild.shell.err")
        var outChunks = Data()
        var errChunks = Data()
        let outGroup = DispatchGroup()
        let errGroup = DispatchGroup()

        outGroup.enter()
        outQueue.async {
            outChunks = outPipe.fileHandleForReading.readDataToEndOfFile()
            outGroup.leave()
        }
        errGroup.enter()
        errQueue.async {
            errChunks = errPipe.fileHandleForReading.readDataToEndOfFile()
            errGroup.leave()
        }

        try process.run()
        process.waitUntilExit()
        outGroup.wait()
        errGroup.wait()

        let stdout = String(data: outChunks, encoding: .utf8) ?? ""
        let stderr = String(data: errChunks, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw Error(
                command: command,
                args: args,
                exitCode: process.terminationStatus,
                stdout: stdout,
                stderr: stderr
            )
        }
        return stdout
    }

    /// Convenience for single-shot captures that callers will trim themselves.
    static func capture(_ command: String, _ args: String...) throws -> String {
        try run(command, args: args)
    }
}
