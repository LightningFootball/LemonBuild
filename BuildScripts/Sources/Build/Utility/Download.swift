import Foundation

/// Source fetch helpers. Kept intentionally minimal — each stage extends
/// this with whatever it needs (shallow clone, tarball + checksum, submodule sync, …).
enum Download {
    /// Ensure a git repository exists at `destination` and is checked out at `ref`.
    /// Uses a shallow clone; subsequent calls fetch and check out `FETCH_HEAD`.
    static func ensureGit(url: String, ref: String, destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.appendingPathComponent(".git").path) {
            try Shell.run("git", "-C", destination.path, "fetch", "--depth=1", "origin", ref)
            try Shell.run("git", "-C", destination.path, "checkout", "FETCH_HEAD")
            return
        }
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Shell.run("git", "clone", "--depth=1", "--branch", ref, url, destination.path)
    }

    /// Download a file at `url` to `destination` (skip if already present and sha256 matches).
    static func ensureTarball(url: String, sha256: String, destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path), try sha256Digest(of: destination) == sha256 {
            return
        }
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Shell.run("curl", "-fL", "-o", destination.path, url)
        let digest = try sha256Digest(of: destination)
        guard digest == sha256 else {
            throw NSError(
                domain: "LemonBuild.Download",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "sha256 mismatch for \(url): expected \(sha256), got \(digest)"]
            )
        }
    }

    static func sha256Digest(of file: URL) throws -> String {
        let output = try Shell.run("shasum", "-a", "256", file.path)
        return String(output.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first ?? "")
    }
}
