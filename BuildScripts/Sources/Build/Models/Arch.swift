import Foundation

/// CPU architecture targeted by a build. v0.1.0 roadmap is arm64 only.
enum Arch: String {
    case arm64

    var clangArch: String { "arm64" }
    var cmakeProcessor: String { "arm64" }
    var mesonCPUFamily: String { "aarch64" }
    var mesonCPU: String { "arm64" }
}
