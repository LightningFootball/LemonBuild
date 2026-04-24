import Foundation

/// Static description of a library we cross-compile into an xcframework.
struct LibrarySpec {
    let name: String
    let version: String
    let source: Source
    let buildSystem: BuildSystemKind
    let dependencies: [String]
    /// Path of the produced static library relative to the install prefix, e.g. `lib/libdav1d.a`.
    let productLibraryRelativePath: String
    /// Path of the headers dir relative to the install prefix, e.g. `include/dav1d`.
    let headersRelativePath: String

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

/// All libraries the CLI knows about. v0.1.0 stage 1 starts empty;
/// each later stage appends its library specs.
enum LibraryRegistry {
    static let libraries: [LibrarySpec] = []

    static func find(_ name: String) -> LibrarySpec? {
        libraries.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}
