import Foundation

/// Orchestrates "fetch source → per-slice install → xcframework" for one library.
struct BuildDriver {
    let repoRoot: URL

    var workspaceRoot: URL { repoRoot.appendingPathComponent("work") }
    var frameworksRoot: URL { repoRoot.appendingPathComponent("Frameworks") }

    @discardableResult
    func build(library: any LibraryBuilder, platforms: [Platform]) throws -> URL {
        let spec = library.spec
        let libWorkspace = workspaceRoot.appendingPathComponent(spec.name)
        let sourceDir = libWorkspace.appendingPathComponent("src")

        try fetchSource(spec: spec, into: sourceDir)

        var slices: [XCFrameworkAssembler.Slice] = []
        for platform in platforms {
            let toolchain = try Toolchain.resolve(platform: platform)
            let artifact = try library.buildSlice(
                toolchain: toolchain,
                sourceDir: sourceDir,
                workspace: libWorkspace
            )
            slices.append(.init(
                platform: platform,
                libraryPath: artifact.staticLibrary,
                headersDir: artifact.headersRoot
            ))
        }

        let assembler = XCFrameworkAssembler(
            name: spec.xcframeworkName,
            slices: slices,
            outputDir: frameworksRoot
        )
        return try assembler.assemble()
    }

    private func fetchSource(spec: LibrarySpec, into dest: URL) throws {
        switch spec.source {
        case .git(let url, let ref):
            try Download.ensureGit(url: url, ref: ref, destination: dest)
        case .tarball(let url, let sha256):
            // Not used in stage 2; will wire up when the first tarball-based lib lands.
            _ = (url, sha256)
            throw NSError(
                domain: "LemonBuild.BuildDriver",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "tarball source not yet implemented"]
            )
        }
    }
}

extension BuildDriver {
    /// Locate the repo root by walking up from `cwd` looking for the `BuildScripts` sibling.
    static func locateRepoRoot(from cwd: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) -> URL {
        var current = cwd
        let fm = FileManager.default
        for _ in 0..<6 {
            let marker = current.appendingPathComponent("BuildScripts/Package.swift")
            if fm.fileExists(atPath: marker.path) { return current }
            if current.path == "/" { break }
            current = current.deletingLastPathComponent()
        }
        // Fall back: assume cwd *is* BuildScripts and parent is repo root.
        return cwd.deletingLastPathComponent()
    }
}
