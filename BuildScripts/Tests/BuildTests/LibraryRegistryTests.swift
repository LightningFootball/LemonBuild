import XCTest
@testable import Build

final class LibraryRegistryTests: XCTestCase {
    func testDav1dIsRegistered() {
        let dav1d = LibraryRegistry.find("dav1d")
        XCTAssertNotNil(dav1d)
        XCTAssertEqual(dav1d?.spec.xcframeworkName, "Dav1d")
        XCTAssertEqual(dav1d?.spec.buildSystem, .meson)
    }

    func testFindIsCaseInsensitive() {
        XCTAssertNotNil(LibraryRegistry.find("DAV1D"))
        XCTAssertNotNil(LibraryRegistry.find("Dav1D"))
    }

    func testUnknownReturnsNil() {
        XCTAssertNil(LibraryRegistry.find("does-not-exist"))
    }

    func testBuildSystemKindHasExpectedCases() {
        let raw = LibrarySpec.BuildSystemKind.allCases.map(\.rawValue)
        XCTAssertEqual(Set(raw), ["meson", "cmake", "autotools", "xcodebuild"])
    }
}
