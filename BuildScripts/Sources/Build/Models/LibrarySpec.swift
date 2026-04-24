import Foundation

/// Static description of a library we cross-compile into an xcframework.
struct LibrarySpec {
    let name: String
    let version: String
    let source: Source
    let buildSystem: BuildSystemKind
    let dependencies: [String]
    /// Filename of the produced xcframework (without extension). Usually PascalCase.
    let xcframeworkName: String
    /// Clang module name written into the xcframework's `module.modulemap`.
    let moduleName: String

    enum Source {
        case git(url: String, ref: String)
        case tarball(url: String, sha256: String)
    }

    enum BuildSystemKind: String, CaseIterable {
        case meson
        case cmake
        case autotools
        case xcodebuild
    }
}

/// Everything a library's `buildSlice` needs to produce one slice.
struct BuildContext {
    let toolchain: Toolchain
    let sourceDir: URL
    let buildDir: URL
    let installDir: URL
    /// Install-prefix directories of already-built dependencies for this slice,
    /// keyed by lowercased dependency name.
    let dependencyInstallDirs: [String: URL]

    /// `PKG_CONFIG_PATH` pointing to all dep pkg-config dirs, colon-joined.
    var pkgConfigPath: String {
        dependencyInstallDirs.values
            .map { $0.appendingPathComponent("lib/pkgconfig").path }
            .joined(separator: ":")
    }

    /// `PKG_CONFIG_LIBDIR` is like `PKG_CONFIG_PATH` but *replaces* the default
    /// system paths — crucial for cross-compilation so native deps never leak in.
    var pkgConfigLibdir: String { pkgConfigPath }

    /// Env vars every builder should export before invoking meson/cmake/configure
    /// so cross builds never resolve host-provided libraries (brew's `bzip2`,
    /// system `iconv`, …). For libs with no declared deps, this clears
    /// PKG_CONFIG_LIBDIR to the empty string.
    var pkgConfigEnv: [String: String] {
        [
            "PKG_CONFIG_PATH": pkgConfigPath,
            "PKG_CONFIG_LIBDIR": pkgConfigLibdir
        ]
    }
}

/// Result of installing a single slice. The build driver picks these up and
/// feeds them to the xcframework assembler.
struct InstallArtifact {
    /// Absolute path to the produced static library (e.g. `.../lib/libdav1d.a`).
    let staticLibrary: URL
    /// Directory that becomes the slice's `Headers/` (must contain a `module.modulemap`).
    let headersRoot: URL
}

/// Each library supplies one of these to drive its own per-slice install.
protocol LibraryBuilder {
    var spec: LibrarySpec { get }
    func buildSlice(context: BuildContext) throws -> InstallArtifact
}

/// Central registry of everything the CLI knows how to build.
enum LibraryRegistry {
    static let builders: [any LibraryBuilder] = [
        Dav1dBuilder(),
        FreeTypeBuilder(),
        FribidiBuilder(),
        HarfbuzzBuilder(),
        UchardetBuilder(),
        LibassBuilder()
    ]

    static var libraries: [LibrarySpec] { builders.map(\.spec) }

    static func find(_ name: String) -> (any LibraryBuilder)? {
        builders.first { $0.spec.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}
