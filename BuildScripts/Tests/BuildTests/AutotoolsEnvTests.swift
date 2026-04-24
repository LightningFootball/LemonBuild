import XCTest
@testable import Build

final class AutotoolsEnvTests: XCTestCase {
    func testDeviceEnvVars() throws {
        let env = AutotoolsEnv(toolchain: .mock(platform: .iOSDevice)).render()
        XCTAssertEqual(env["CC"], "/fake/bin/clang")
        XCTAssertEqual(env["CXX"], "/fake/bin/clang++")
        XCTAssertEqual(env["AR"], "/fake/bin/ar")
        XCTAssertEqual(env["RANLIB"], "/fake/bin/ranlib")
        XCTAssertEqual(env["STRIP"], "/fake/bin/strip")

        let cflags = try XCTUnwrap(env["CFLAGS"])
        XCTAssertTrue(cflags.contains("-arch arm64"))
        XCTAssertTrue(cflags.contains("-isysroot /fake/sdk/iphoneos"))
        XCTAssertTrue(cflags.contains("-target arm64-apple-ios16.0"))

        let ldflags = try XCTUnwrap(env["LDFLAGS"])
        XCTAssertTrue(ldflags.contains("-arch arm64"))
        XCTAssertTrue(ldflags.contains("-target arm64-apple-ios16.0"))
    }

    func testSimulatorEnvTarget() throws {
        let env = AutotoolsEnv(toolchain: .mock(platform: .iOSSimulator)).render()
        let cflags = try XCTUnwrap(env["CFLAGS"])
        XCTAssertTrue(cflags.contains("arm64-apple-ios16.0-simulator"))
        XCTAssertTrue(cflags.contains("/fake/sdk/iphonesimulator"))
    }

    func testDefaultConfigureArgs() {
        let env = AutotoolsEnv(toolchain: .mock(platform: .iOSDevice))
        XCTAssertEqual(env.defaultConfigureArgs, [
            "--host=arm64-apple-darwin",
            "--enable-static",
            "--disable-shared"
        ])
    }
}
