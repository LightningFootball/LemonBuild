import XCTest
@testable import Build

final class BuildDriverTests: XCTestCase {
    /// libmpv → ffmpeg → dav1d / libass → freetype, fribidi, harfbuzz /
    /// libplacebo → shaderc, moltenvk / uchardet. The closure should land
    /// every one of those with no duplicates.
    func testTransitiveDepsForLibmpv() throws {
        let driver = BuildDriver(repoRoot: URL(fileURLWithPath: "/tmp/dummy"))
        guard let libmpv = LibraryRegistry.find("libmpv") else {
            XCTFail("libmpv not registered"); return
        }
        let closure = driver.transitiveDependencies(of: libmpv.spec)
        let expected: Set<String> = [
            "dav1d", "ffmpeg",
            "freetype", "fribidi", "harfbuzz", "libass",
            "shaderc", "moltenvk", "libplacebo",
            "uchardet"
        ]
        XCTAssertEqual(Set(closure), expected,
                       "missing or extra deps in libmpv's closure: \(closure)")
        XCTAssertEqual(closure.count, Set(closure).count,
                       "closure has duplicates: \(closure)")
    }

    func testTransitiveDepsAreTopologicallyOrdered() throws {
        let driver = BuildDriver(repoRoot: URL(fileURLWithPath: "/tmp/dummy"))
        guard let libass = LibraryRegistry.find("libass") else {
            XCTFail("libass not registered"); return
        }
        let closure = driver.transitiveDependencies(of: libass.spec)
        let positions = Dictionary(uniqueKeysWithValues: closure.enumerated().map { ($1, $0) })
        // freetype must come before harfbuzz (harfbuzz depends on freetype)
        XCTAssertLessThan(positions["freetype"]!, positions["harfbuzz"]!)
    }

    func testTransitiveDepsForLeafLibrary() throws {
        let driver = BuildDriver(repoRoot: URL(fileURLWithPath: "/tmp/dummy"))
        guard let dav1d = LibraryRegistry.find("dav1d") else {
            XCTFail("dav1d not registered"); return
        }
        let closure = driver.transitiveDependencies(of: dav1d.spec)
        XCTAssertEqual(closure, [], "dav1d declares no deps; closure should be empty")
    }

    func testLocateRepoRootFindsByMarker() throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory
            .appendingPathComponent("lemonbuild-locate-\(UUID().uuidString)")
        let buildScripts = temp.appendingPathComponent("BuildScripts")
        try fm.createDirectory(at: buildScripts, withIntermediateDirectories: true)
        try Data().write(to: buildScripts.appendingPathComponent("Package.swift"))
        defer { try? fm.removeItem(at: temp) }

        // Walking up from a deeper subdirectory should land on `temp`.
        let nested = temp.appendingPathComponent("BuildScripts/Sources/Build/Models")
        try fm.createDirectory(at: nested, withIntermediateDirectories: true)
        let resolved = BuildDriver.locateRepoRoot(from: nested)
        XCTAssertEqual(resolved.standardized.path, temp.standardized.path)
    }
}
