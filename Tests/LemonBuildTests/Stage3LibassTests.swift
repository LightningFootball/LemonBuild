import XCTest
import Libass

final class Stage3LibassTests: XCTestCase {
    func testAssLibraryAndRendererInit() throws {
        let library = try XCTUnwrap(ass_library_init(), "ass_library_init returned NULL")
        defer { ass_library_done(library) }

        let renderer = try XCTUnwrap(ass_renderer_init(library), "ass_renderer_init returned NULL")
        ass_renderer_done(renderer)
    }

    func testAssAddFontAcceptsMemoryFont() throws {
        // Synthesize a minimal, obviously-invalid font blob. libass doesn't
        // actually parse it until a track tries to render — `ass_add_font`
        // only stores the bytes, so a successful add is enough to prove the
        // FreeType/HarfBuzz-backed font plumbing compiled and linked.
        let library = try XCTUnwrap(ass_library_init(), "ass_library_init returned NULL")
        defer { ass_library_done(library) }

        let payload = Array("fake-font-blob".utf8)
        payload.withUnsafeBufferPointer { buf in
            let raw = UnsafeMutablePointer<CChar>(mutating: buf.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buf.count) { $0 })
            ass_add_font(library, "Sample", raw, Int32(buf.count))
        }
        // ass_add_font returns void; reaching this line without a link failure
        // is the assertion.
        XCTAssertTrue(true)
    }

    func testAssSetFontsDirSmoke() throws {
        let library = try XCTUnwrap(ass_library_init(), "ass_library_init returned NULL")
        defer { ass_library_done(library) }
        // This call is a pure setter; verifies we linked against libass's
        // configure surface without triggering fontconfig / CoreText paths.
        ass_set_fonts_dir(library, "/tmp/lemon-fonts-test")
    }
}
