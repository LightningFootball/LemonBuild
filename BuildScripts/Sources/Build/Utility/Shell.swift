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
        try process.run()
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""
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
