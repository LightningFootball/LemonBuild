import XCTest
@testable import Build

final class ToolchainTests: XCTestCase {
    func testDeviceTargetTriple() {
        let tc = Toolchain.mock(platform: .iOSDevice)
        XCTAssertEqual(tc.targetTriple, "arm64-apple-ios16.0")
    }

    func testSimulatorTargetTriple() {
        let tc = Toolchain.mock(platform: .iOSSimulator)
        XCTAssertEqual(tc.targetTriple, "arm64-apple-ios16.0-simulator")
    }

    func testCustomMinVersion() {
        let tc = Toolchain.mock(platform: .iOSDevice, minOSVersion: "17.2")
        XCTAssertEqual(tc.targetTriple, "arm64-apple-ios17.2")
    }

    func testCFlagsContainArchSysrootTarget() {
        let tc = Toolchain.mock(platform: .iOSSimulator)
        let flags = tc.cFlags
        XCTAssertTrue(flags.contains("-arch"))
        XCTAssertTrue(flags.contains("arm64"))
        XCTAssertTrue(flags.contains("-isysroot"))
        XCTAssertTrue(flags.contains("/fake/sdk/iphonesimulator"))
        XCTAssertTrue(flags.contains("-target"))
        XCTAssertTrue(flags.contains("arm64-apple-ios16.0-simulator"))
    }

    func testConfigureHost() {
        let tc = Toolchain.mock(platform: .iOSDevice)
        XCTAssertEqual(tc.configureHost, "arm64-apple-darwin")
    }
}
