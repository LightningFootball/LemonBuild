import Foundation

/// Turns per-slice static libraries + header directories into a single
/// `.xcframework` via `xcodebuild -create-xcframework`.
struct XCFrameworkAssembler {
    struct Slice {
        let platform: Platform
        let libraryPath: URL
        let headersDir: URL?
    }

    let name: String
    let slices: [Slice]
    let outputDir: URL

    /// Writes `<outputDir>/<name>.xcframework` and returns its URL.
    @discardableResult
    func assemble() throws -> URL {
        precondition(!slices.isEmpty, "XCFramework needs at least one slice")
        let fm = FileManager.default
        try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let output = outputDir.appendingPathComponent("\(name).xcframework")
        try? fm.removeItem(at: output)

        var args: [String] = ["-create-xcframework"]
        for slice in slices {
            args.append("-library")
            args.append(slice.libraryPath.path)
            if let headers = slice.headersDir {
                args.append("-headers")
                args.append(headers.path)
            }
        }
        args.append("-output")
        args.append(output.path)
        try Shell.run("xcodebuild", args: args)
        return output
    }
}
