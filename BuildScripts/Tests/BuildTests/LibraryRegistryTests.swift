import XCTest
@testable import Build

final class LibraryRegistryTests: XCTestCase {
    func testStageOneHasNoLibraries() {
        // Stage 1 ships infrastructure only. As stages land, remove this test
        // and replace with registry assertions.
        XCTAssertTrue(LibraryRegistry.libraries.isEmpty)
    }

    func testFindOnEmptyRegistryReturnsNil() {
        XCTAssertNil(LibraryRegistry.find("dav1d"))
    }

    func testBuildSystemKindHasExpectedCases() {
        let raw = LibrarySpec.BuildSystemKind.allCases.map(\.rawValue)
        XCTAssertEqual(Set(raw), ["meson", "cmake", "autotools", "xcodebuild"])
    }
}
