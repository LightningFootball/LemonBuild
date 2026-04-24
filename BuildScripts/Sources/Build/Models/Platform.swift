import Foundation

/// iOS platform slice targeted by a build.
/// v0.1.0 roadmap covers only arm64 device and arm64 simulator.
enum Platform: String, CaseIterable {
    case iOSDevice
    case iOSSimulator

    /// Folder name inside `*.xcframework` (`ios-arm64`, `ios-arm64-simulator`).
    var sliceName: String {
        switch self {
        case .iOSDevice: return "ios-arm64"
        case .iOSSimulator: return "ios-arm64-simulator"
        }
    }

    /// `xcrun --sdk <name>` identifier.
    var sdkName: String {
        switch self {
        case .iOSDevice: return "iphoneos"
        case .iOSSimulator: return "iphonesimulator"
        }
    }

    /// Suffix appended to the Apple clang target triple (`-simulator` for sim slices).
    var tripleSuffix: String {
        switch self {
        case .iOSDevice: return ""
        case .iOSSimulator: return "-simulator"
        }
    }

    /// Value written to `[host_machine] subsystem` in a meson cross-file.
    var mesonSubsystem: String {
        switch self {
        case .iOSDevice: return "ios"
        case .iOSSimulator: return "ios-simulator"
        }
    }
}
