import Foundation

/// Source fetch helpers. Stays intentionally small — each stage extends this
/// with whatever it needs (shallow clone, submodule init, tarball + checksum …).
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

    /// Download `url` (cached by sha256), then extract into `destination`.
    /// Supports `.tar`, `.tar.gz`/`.tgz`, `.tar.xz`, `.zip`. If `destination`
    /// already exists, assumes a prior extract and no-ops; wipe it manually to
    /// force a refresh (e.g. bumping `spec.version`).
    static func ensureTarball(url: String, sha256: String, destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) { return }

        let archivesDir = destination.deletingLastPathComponent().appendingPathComponent(".archives")
        try fm.createDirectory(at: archivesDir, withIntermediateDirectories: true)
        let archivePath = archivesDir.appendingPathComponent(archiveFilename(for: url))

        let needsDownload: Bool
        if fm.fileExists(atPath: archivePath.path) {
            needsDownload = try sha256Digest(of: archivePath) != sha256
        } else {
            needsDownload = true
        }
        if needsDownload {
            try? fm.removeItem(at: archivePath)
            try Shell.run("curl", "-fL", "-o", archivePath.path, url)
        }
        let digest = try sha256Digest(of: archivePath)
        guard digest == sha256 else {
            throw NSError(
                domain: "LemonBuild.Download",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "sha256 mismatch for \(url)\n  expected: \(sha256)\n  got:      \(digest)"
                ]
            )
        }

        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        try extractArchive(at: archivePath, into: destination)
    }

    static func sha256Digest(of file: URL) throws -> String {
        let output = try Shell.run("shasum", "-a", "256", file.path)
        return String(output.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first ?? "")
    }

    private static func extractArchive(at archive: URL, into destination: URL) throws {
        let name = archive.lastPathComponent.lowercased()
        if name.hasSuffix(".zip") {
            try Shell.run("unzip", "-q", "-o", archive.path, "-d", destination.path)
        } else if name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz") {
            try Shell.run("tar", "-xzf", archive.path, "-C", destination.path)
        } else if name.hasSuffix(".tar.xz") {
            try Shell.run("tar", "-xJf", archive.path, "-C", destination.path)
        } else if name.hasSuffix(".tar") {
            try Shell.run("tar", "-xf", archive.path, "-C", destination.path)
        } else {
            throw NSError(
                domain: "LemonBuild.Download",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "unrecognized archive format: \(archive.lastPathComponent)"]
            )
        }
    }

    private static func archiveFilename(for url: String) -> String {
        (URL(string: url)?.lastPathComponent).flatMap { $0.isEmpty ? nil : $0 } ?? "archive.bin"
    }
}
