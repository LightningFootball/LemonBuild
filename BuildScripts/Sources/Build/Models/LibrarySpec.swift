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
    /// Install the library for one slice and return the artifact paths.
    func buildSlice(toolchain: Toolchain, sourceDir: URL, workspace: URL) throws -> InstallArtifact
}

/// Central registry of everything the CLI knows how to build.
enum LibraryRegistry {
    static let builders: [any LibraryBuilder] = [
        Dav1dBuilder()
    ]

    static var libraries: [LibrarySpec] { builders.map(\.spec) }

    static func find(_ name: String) -> (any LibraryBuilder)? {
        builders.first { $0.spec.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}
