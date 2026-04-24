import XCTest
import Libplacebo
import MoltenVK

final class Stage4LibplaceboTests: XCTestCase {
    func testPlApiVersionExposed() throws {
        // PL_API_VER is a plain integer #define — Swift imports it.
        // libplacebo 7.x hovers around API 349+; we pinned v7.360.1.
        XCTAssertGreaterThanOrEqual(PL_API_VER, 349)
    }

    func testPlSymbolReachable() throws {
        // `pl_log_create` is behind a version-suffix macro for ABI safety, so
        // Swift can't see it directly. `pl_generate_bayer_matrix` is a plain
        // PL_API function — referencing it proves libplacebo is linked.
        var buf = [Float](repeating: 0, count: 4 * 4)
        buf.withUnsafeMutableBufferPointer { ptr in
            pl_generate_bayer_matrix(ptr.baseAddress, 4)
        }
        // Bayer matrix entries are deterministic values in [0, 1); just check
        // we actually wrote something.
        XCTAssertTrue(buf.contains { $0 != 0 })
    }

    func testMoltenVKVulkanLoaderReachable() throws {
        // `vkEnumerateInstanceVersion` is the Vulkan 1.1+ entry point that
        // MoltenVK exposes. Simulator has no real Metal device for us to spin
        // up an instance, so just resolve the symbol — link success alone
        // proves the MoltenVK archive is wired into the test binary.
        var apiVersion: UInt32 = 0
        let result = vkEnumerateInstanceVersion(&apiVersion)
        XCTAssertEqual(result, VK_SUCCESS)
        XCTAssertGreaterThan(apiVersion, 0)
    }
}
