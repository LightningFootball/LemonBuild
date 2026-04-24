import XCTest
@testable import Build

final class MesonCrossFileTests: XCTestCase {
    func testDeviceHeaderSections() {
        let content = MesonCrossFile(toolchain: .mock(platform: .iOSDevice)).render()
        XCTAssertTrue(content.contains("[binaries]"))
        XCTAssertTrue(content.contains("[host_machine]"))
        XCTAssertTrue(content.contains("[built-in options]"))
    }

    func testDeviceBinaryPaths() {
        let content = MesonCrossFile(toolchain: .mock(platform: .iOSDevice)).render()
        XCTAssertTrue(content.contains("c = '/fake/bin/clang'"))
        XCTAssertTrue(content.contains("cpp = '/fake/bin/clang++'"))
        XCTAssertTrue(content.contains("objc = '/fake/bin/clang'"))
        XCTAssertTrue(content.contains("ar = '/fake/bin/ar'"))
        XCTAssertTrue(content.contains("ranlib = '/fake/bin/ranlib'"))
        XCTAssertTrue(content.contains("strip = '/fake/bin/strip'"))
    }

    func testDeviceHostMachine() {
        let content = MesonCrossFile(toolchain: .mock(platform: .iOSDevice)).render()
        XCTAssertTrue(content.contains("system = 'darwin'"))
        XCTAssertTrue(content.contains("subsystem = 'ios'"))
        XCTAssertTrue(content.contains("cpu_family = 'aarch64'"))
        XCTAssertTrue(content.contains("cpu = 'arm64'"))
        XCTAssertTrue(content.contains("endian = 'little'"))
    }

    func testSimulatorHostMachine() {
        let content = MesonCrossFile(toolchain: .mock(platform: .iOSSimulator)).render()
        XCTAssertTrue(content.contains("subsystem = 'ios-simulator'"))
        XCTAssertTrue(content.contains("arm64-apple-ios16.0-simulator"))
    }

    func testBuiltInOptionsAreListLiterals() {
        let content = MesonCrossFile(toolchain: .mock(platform: .iOSDevice)).render()
        XCTAssertTrue(content.contains("c_args = ["))
        XCTAssertTrue(content.contains("c_link_args = ["))
        XCTAssertTrue(content.contains("'-arch', 'arm64'"))
        XCTAssertTrue(content.contains("'-isysroot', '/fake/sdk/iphoneos'"))
    }
}
