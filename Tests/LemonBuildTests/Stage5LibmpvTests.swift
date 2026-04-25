import XCTest
import FFmpeg
import Libmpv

final class Stage5LibmpvTests: XCTestCase {
    func testAvVersionReachable() throws {
        // libavutil's `avutil_version` is a plain function that returns the
        // packed version number. Link success = FFmpeg archive wired up.
        let version = avutil_version()
        XCTAssertGreaterThan(version, 0)
        let major = (version >> 16) & 0xff
        XCTAssertGreaterThanOrEqual(major, 58, "expected ffmpeg ≥ 7.x (libavutil ≥ 58); got \(major)")
    }

    func testMpvCreateRoundTrip() throws {
        // mpv_create / mpv_terminate_destroy exercises the full link chain:
        // libmpv → libass / libplacebo / ffmpeg / uchardet / MoltenVK (even
        // though we don't spin up vulkan here).
        let handle = mpv_create()
        XCTAssertNotNil(handle)
        if let handle = handle {
            // Set a couple of smoke options — these don't touch any VO, so
            // they're safe inside a unit test on the simulator.
            _ = mpv_set_option_string(handle, "terminal", "no")
            _ = mpv_set_option_string(handle, "msg-level", "all=no")
            let initRC = mpv_initialize(handle)
            XCTAssertEqual(initRC, 0, "mpv_initialize returned \(initRC)")
            mpv_terminate_destroy(handle)
        }
    }

    func testMpvClientApiVersion() throws {
        // Imported as a macro-free function in recent libmpv: mpv_client_api_version().
        let v = mpv_client_api_version()
        XCTAssertGreaterThan(v, 0)
    }
}
