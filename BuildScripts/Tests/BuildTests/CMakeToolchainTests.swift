import XCTest
@testable import Build

final class CMakeToolchainTests: XCTestCase {
    func testDeviceContent() {
        let content = CMakeToolchain(toolchain: .mock(platform: .iOSDevice)).render()
        XCTAssertTrue(content.contains("set(CMAKE_SYSTEM_NAME iOS)"))
        XCTAssertTrue(content.contains("set(CMAKE_SYSTEM_PROCESSOR arm64)"))
        XCTAssertTrue(content.contains("set(CMAKE_OSX_ARCHITECTURES arm64)"))
        XCTAssertTrue(content.contains("set(CMAKE_OSX_DEPLOYMENT_TARGET 16.0)"))
        XCTAssertTrue(content.contains("set(CMAKE_OSX_SYSROOT /fake/sdk/iphoneos)"))
        XCTAssertTrue(content.contains("set(CMAKE_C_COMPILER /fake/bin/clang)"))
        XCTAssertTrue(content.contains("set(CMAKE_CXX_COMPILER /fake/bin/clang++)"))
        XCTAssertTrue(content.contains("set(CMAKE_C_COMPILER_TARGET arm64-apple-ios16.0)"))
        XCTAssertTrue(content.contains("CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER"))
    }

    func testSimulatorContent() {
        let content = CMakeToolchain(toolchain: .mock(platform: .iOSSimulator)).render()
        XCTAssertTrue(content.contains("set(CMAKE_OSX_SYSROOT /fake/sdk/iphonesimulator)"))
        XCTAssertTrue(content.contains("set(CMAKE_C_COMPILER_TARGET arm64-apple-ios16.0-simulator)"))
        XCTAssertTrue(content.contains("-iphonesimulator"))
    }
}
