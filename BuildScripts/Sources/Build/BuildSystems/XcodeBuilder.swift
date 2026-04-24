import Foundation

/// Thin wrapper around `xcodebuild` for libraries whose upstream already ships
/// an Xcode project (e.g. MoltenVK). Stage 1: structure only.
struct XcodeBuilder {
    let projectPath: URL
    let scheme: String
    let platform: Platform
    let derivedDataPath: URL

    func buildArchive(configuration: String = "Release") throws {
        let destination: String
        switch platform {
        case .iOSDevice: destination = "generic/platform=iOS"
        case .iOSSimulator: destination = "generic/platform=iOS Simulator"
        }
        try Shell.run("xcodebuild", args: [
            "-project", projectPath.path,
            "-scheme", scheme,
            "-configuration", configuration,
            "-destination", destination,
            "-derivedDataPath", derivedDataPath.path,
            "BUILD_LIBRARY_FOR_DISTRIBUTION=YES",
            "SKIP_INSTALL=NO",
            "archive"
        ])
    }
}
