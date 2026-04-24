import Foundation

/// Combines multiple same-platform slices into one fat binary.
///
/// v0.1.0 ships only arm64 per platform, so this usually degenerates into a
/// plain copy. The type is preserved so that adding an extra arch later is a
/// single-site change.
enum Lipo {
    static func combine(inputs: [URL], output: URL) throws {
        let fm = FileManager.default
        try? fm.removeItem(at: output)
        try fm.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        if inputs.count == 1, let only = inputs.first {
            try fm.copyItem(at: only, to: output)
            return
        }
        var args: [String] = ["-create"]
        args.append(contentsOf: inputs.map(\.path))
        args.append(contentsOf: ["-output", output.path])
        try Shell.run("lipo", args: args)
    }
}
