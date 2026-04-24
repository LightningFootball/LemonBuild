import XCTest
import Dav1d

final class Stage2Dav1dTests: XCTestCase {
    func testDav1dVersionIsReachable() throws {
        let cStr = try XCTUnwrap(dav1d_version(), "dav1d_version returned NULL")
        let version = String(cString: cStr)
        XCTAssertFalse(version.isEmpty, "dav1d_version is empty")
        XCTAssertTrue(version.contains("."),
                      "expected semver-like dav1d version, got \(version)")
    }

    func testDav1dDefaultSettingsRoundTrip() {
        var settings = Dav1dSettings()
        dav1d_default_settings(&settings)
        // Default thread counts are "auto" (0) until populated by the caller.
        XCTAssertGreaterThanOrEqual(settings.n_threads, 0)
        XCTAssertGreaterThanOrEqual(settings.max_frame_delay, 0)
    }
}
