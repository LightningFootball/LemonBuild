import XCTest
@testable import Build

final class IncludeRewriterTests: XCTestCase {
    func testRewritesAngleBracketSelfInclude() throws {
        let dir = try makeTempDir("rewriter-angle")
        defer { try? FileManager.default.removeItem(at: dir) }

        let header = dir.appendingPathComponent("foo.h")
        try """
        #ifndef FOO_H
        #define FOO_H
        #include <libplacebo/common.h>
        void foo(void);
        #endif
        """.write(to: header, atomically: true, encoding: .utf8)

        try IncludeRewriter.rewriteSelfIncludes(
            in: dir,
            prefixes: ["libplacebo"],
            replacement: { _, name, _ in name }
        )

        let rewritten = try String(contentsOf: header, encoding: .utf8)
        XCTAssertTrue(rewritten.contains("#include \"common.h\""))
        XCTAssertFalse(rewritten.contains("<libplacebo/"))
    }

    func testRewritesQuotedSelfInclude() throws {
        let dir = try makeTempDir("rewriter-quoted")
        defer { try? FileManager.default.removeItem(at: dir) }

        let header = dir.appendingPathComponent("bar.h")
        try """
        #include "vk_video/vulkan_video_codec_h264std.h"
        """.write(to: header, atomically: true, encoding: .utf8)

        try IncludeRewriter.rewriteSelfIncludes(
            in: dir,
            prefixes: ["vk_video"],
            replacement: { prefix, name, _ in "../\(prefix)/\(name)" }
        )

        let rewritten = try String(contentsOf: header, encoding: .utf8)
        XCTAssertTrue(rewritten.contains("\"../vk_video/vulkan_video_codec_h264std.h\""),
                      "got: \(rewritten)")
    }

    func testDepthAwareReplacement() throws {
        let dir = try makeTempDir("rewriter-depth")
        defer { try? FileManager.default.removeItem(at: dir) }

        // Top-level header (depth 0)
        let top = dir.appendingPathComponent("top.h")
        try "#include <libplacebo/common.h>".write(to: top, atomically: true, encoding: .utf8)

        // Nested header (depth 1)
        let subdir = dir.appendingPathComponent("shaders")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        let nested = subdir.appendingPathComponent("colorspace.h")
        try "#include <libplacebo/gamut_mapping.h>".write(to: nested, atomically: true, encoding: .utf8)

        try IncludeRewriter.rewriteSelfIncludes(
            in: dir,
            prefixes: ["libplacebo"],
            replacement: { _, name, depth in
                String(repeating: "../", count: depth) + name
            },
            recursive: true
        )

        XCTAssertEqual(try String(contentsOf: top, encoding: .utf8),
                       "#include \"common.h\"")
        XCTAssertEqual(try String(contentsOf: nested, encoding: .utf8),
                       "#include \"../gamut_mapping.h\"")
    }

    func testLeavesUnrelatedIncludesAlone() throws {
        let dir = try makeTempDir("rewriter-untouched")
        defer { try? FileManager.default.removeItem(at: dir) }

        let header = dir.appendingPathComponent("baz.h")
        try """
        #include <stdio.h>
        #include <libavformat/avformat.h>
        #include "internal.h"
        """.write(to: header, atomically: true, encoding: .utf8)

        try IncludeRewriter.rewriteSelfIncludes(
            in: dir,
            prefixes: ["libplacebo"],
            replacement: { _, name, _ in name }
        )

        let rewritten = try String(contentsOf: header, encoding: .utf8)
        XCTAssertTrue(rewritten.contains("#include <stdio.h>"))
        XCTAssertTrue(rewritten.contains("#include <libavformat/avformat.h>"))
        XCTAssertTrue(rewritten.contains("#include \"internal.h\""))
    }

    func testNonRecursiveSkipsSubdirs() throws {
        let dir = try makeTempDir("rewriter-nonrecursive")
        defer { try? FileManager.default.removeItem(at: dir) }

        let subdir = dir.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        let nested = subdir.appendingPathComponent("inner.h")
        try "#include <libplacebo/x.h>".write(to: nested, atomically: true, encoding: .utf8)

        try IncludeRewriter.rewriteSelfIncludes(
            in: dir,
            prefixes: ["libplacebo"],
            replacement: { _, name, _ in name },
            recursive: false
        )

        XCTAssertEqual(try String(contentsOf: nested, encoding: .utf8),
                       "#include <libplacebo/x.h>",
                       "non-recursive walk should leave subdir untouched")
    }

    private func makeTempDir(_ name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lemonbuild-tests-\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
