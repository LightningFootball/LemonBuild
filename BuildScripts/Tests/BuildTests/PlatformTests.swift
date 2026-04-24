import XCTest
@testable import Build

final class PlatformTests: XCTestCase {
    func testSliceNames() {
        XCTAssertEqual(Platform.iOSDevice.sliceName, "ios-arm64")
        XCTAssertEqual(Platform.iOSSimulator.sliceName, "ios-arm64-simulator")
    }

    func testSDKNames() {
        XCTAssertEqual(Platform.iOSDevice.sdkName, "iphoneos")
        XCTAssertEqual(Platform.iOSSimulator.sdkName, "iphonesimulator")
    }

    func testTripleSuffix() {
        XCTAssertEqual(Platform.iOSDevice.tripleSuffix, "")
        XCTAssertEqual(Platform.iOSSimulator.tripleSuffix, "-simulator")
    }

    func testMesonSubsystem() {
        XCTAssertEqual(Platform.iOSDevice.mesonSubsystem, "ios")
        XCTAssertEqual(Platform.iOSSimulator.mesonSubsystem, "ios-simulator")
    }

    func testAllCasesPresent() {
        XCTAssertEqual(Set(Platform.allCases), [.iOSDevice, .iOSSimulator])
    }
}
