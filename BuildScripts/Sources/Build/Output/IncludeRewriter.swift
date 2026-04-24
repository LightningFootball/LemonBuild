import Foundation

/// Rewrites `#include <prefix/name.h>` and `#include "prefix/name.h"` inside
/// every `.h` file under `dir` to a quoted path computed from the caller's
/// `replacement` closure.
///
/// Why this exists: our `HeadersStager` wraps each library's headers under an
/// extra `Headers/<Module>/` directory so modulemaps don't collide in SPM's
/// `include/` flattening. That wrap buries any upstream self-referential
/// `#include <libname/...>` one level deeper than the library itself
/// assumes — the angle-bracket form can't resolve via the consumer's `-I`
/// search path anymore. Rewriting those includes into relative quoted paths
/// bypasses the `-I` search entirely.
enum IncludeRewriter {
    /// Walk `.h` files under `dir`. For each matched self-reference, call
    /// `replacement(prefix, name, upDepth)` where `upDepth` is the number of
    /// `..` steps needed to reach `dir` from the including file's directory
    /// (0 when at the walk root, 1 for a first-level subdir, etc.).
    static func rewriteSelfIncludes(
        in dir: URL,
        prefixes: [String],
        replacement: (_ prefix: String, _ name: String, _ upDepth: Int) -> String,
        recursive: Bool = false
    ) throws {
        try walk(dir, depth: 0, recursive: recursive, prefixes: prefixes, replacement: replacement)
    }

    private static func walk(
        _ dir: URL,
        depth: Int,
        recursive: Bool,
        prefixes: [String],
        replacement: (String, String, Int) -> String
    ) throws {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: dir.path) else { return }
        for entry in entries {
            let url = dir.appendingPathComponent(entry)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: url.path, isDirectory: &isDir)
            if isDir.boolValue {
                if recursive {
                    try walk(url, depth: depth + 1, recursive: true, prefixes: prefixes, replacement: replacement)
                }
                continue
            }
            guard entry.hasSuffix(".h") else { continue }
            try rewriteFile(at: url, depth: depth, prefixes: prefixes, replacement: replacement)
        }
    }

    private static func rewriteFile(
        at url: URL,
        depth: Int,
        prefixes: [String],
        replacement: (String, String, Int) -> String
    ) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        let patched = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in rewriteLine(String(line), depth: depth, prefixes: prefixes, replacement: replacement) }
            .joined(separator: "\n")
        if patched != text {
            try patched.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private static func rewriteLine(
        _ line: String,
        depth: Int,
        prefixes: [String],
        replacement: (String, String, Int) -> String
    ) -> String {
        guard line.hasPrefix("#include ") else { return line }
        for prefix in prefixes {
            if let name = extractDelimited(line, openPrefix: "<\(prefix)/", closeDelim: ">") {
                return "#include \"\(replacement(prefix, name, depth))\""
            }
            if let name = extractDelimited(line, openPrefix: "\"\(prefix)/", closeDelim: "\"") {
                return "#include \"\(replacement(prefix, name, depth))\""
            }
        }
        return line
    }

    private static func extractDelimited(_ line: String, openPrefix: String, closeDelim: String) -> String? {
        guard let start = line.range(of: openPrefix) else { return nil }
        let after = start.upperBound
        guard let end = line.range(of: closeDelim, range: after..<line.endIndex) else { return nil }
        return String(line[after..<end.lowerBound])
    }
}
