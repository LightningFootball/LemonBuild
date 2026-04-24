import Foundation

/// Orchestrates "fetch source → per-slice install → xcframework" for one library
/// and all of its transitive dependencies (depth-first, stable order).
struct BuildDriver {
    let repoRoot: URL

    var workspaceRoot: URL { repoRoot.appendingPathComponent("work") }
    var frameworksRoot: URL { repoRoot.appendingPathComponent("Frameworks") }

    /// Walks the dep graph starting from `library`, builds each lib (deps first),
    /// and returns the xcframework path of the requested lib.
    @discardableResult
    func build(library: any LibraryBuilder, platforms: [Platform]) throws -> URL {
        let order = try buildOrder(for: library)
        var last: URL = frameworksRoot
        for lib in order {
            last = try buildOneLibrary(lib, platforms: platforms)
        }
        return last
    }

    /// Depth-first topological sort of the library + its transitive deps.
    func buildOrder(for library: any LibraryBuilder) throws -> [any LibraryBuilder] {
        var result: [any LibraryBuilder] = []
        var visited = Set<String>()
        var stack = Set<String>()

        func visit(_ lib: any LibraryBuilder) throws {
            let name = lib.spec.name
            if visited.contains(name) { return }
            if stack.contains(name) {
                throw NSError(
                    domain: "LemonBuild.BuildDriver",
                    code: 10,
                    userInfo: [NSLocalizedDescriptionKey: "dependency cycle involving \(name)"]
                )
            }
            stack.insert(name)
            for dep in lib.spec.dependencies {
                guard let depLib = LibraryRegistry.find(dep) else {
                    throw NSError(
                        domain: "LemonBuild.BuildDriver",
                        code: 11,
                        userInfo: [NSLocalizedDescriptionKey: "\(name) depends on unregistered library \(dep)"]
                    )
                }
                try visit(depLib)
            }
            stack.remove(name)
            visited.insert(name)
            result.append(lib)
        }
        try visit(library)
        return result
    }

    private func buildOneLibrary(_ library: any LibraryBuilder, platforms: [Platform]) throws -> URL {
        let spec = library.spec
        let libWorkspace = workspaceRoot.appendingPathComponent(spec.name)
        let sourceDir = libWorkspace.appendingPathComponent("src")

        print(">> \(spec.name) \(spec.version) (\(spec.buildSystem.rawValue))")
        try fetchSource(spec: spec, into: sourceDir)

        var slices: [XCFrameworkAssembler.Slice] = []
        for platform in platforms {
            let toolchain = try Toolchain.resolve(platform: platform)
            let buildDir = libWorkspace.appendingPathComponent("build/\(platform.sliceName)")
            let installDir = libWorkspace.appendingPathComponent("install/\(platform.sliceName)")

            var depInstallDirs: [String: URL] = [:]
            for depName in spec.dependencies {
                let depInstall = workspaceRoot
                    .appendingPathComponent(depName)
                    .appendingPathComponent("install/\(platform.sliceName)")
                depInstallDirs[depName.lowercased()] = depInstall
            }
            let context = BuildContext(
                toolchain: toolchain,
                sourceDir: sourceDir,
                buildDir: buildDir,
                installDir: installDir,
                dependencyInstallDirs: depInstallDirs
            )
            print("   [\(platform.sliceName)] configuring + building")
            let artifact = try library.buildSlice(context: context)
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
        let out = try assembler.assemble()
        print("<< \(spec.name) → \(out.path)")
        return out
    }

    private func fetchSource(spec: LibrarySpec, into dest: URL) throws {
        switch spec.source {
        case .git(let url, let ref):
            try Download.ensureGit(url: url, ref: ref, destination: dest)
        case .tarball(let url, let sha256):
            try Download.ensureTarball(url: url, sha256: sha256, destination: dest)
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
        return cwd.deletingLastPathComponent()
    }
}
