import Foundation

/// Writes a `module.modulemap` file into a headers directory so that the
/// resulting `.xcframework` is importable as a Swift/Clang module.
enum ModuleMapWriter {
    static func write(to headersDir: URL, module: String, umbrellaHeader: String) throws {
        let content = """
        module \(module) {
            header "\(umbrellaHeader)"
            export *
        }

        """
        let dest = headersDir.appendingPathComponent("module.modulemap")
        try FileManager.default.createDirectory(
            at: headersDir,
            withIntermediateDirectories: true
        )
        try content.write(to: dest, atomically: true, encoding: .utf8)
    }
}
