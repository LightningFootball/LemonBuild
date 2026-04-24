import XCTest
@testable import Build

final class ArchTests: XCTestCase {
    func testArm64Mappings() {
        let a = Arch.arm64
        XCTAssertEqual(a.clangArch, "arm64")
        XCTAssertEqual(a.cmakeProcessor, "arm64")
        XCTAssertEqual(a.mesonCPUFamily, "aarch64")
        XCTAssertEqual(a.mesonCPU, "arm64")
    }
}
