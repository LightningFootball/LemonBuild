import Foundation

/// Produces a per-slice headers root whose layout is
/// `<root>/<ModuleName>/{module.modulemap, …headers…}`.
///
/// Why the nesting: SPM's binary-target ingestion flattens every xcframework's
/// `Headers/module.modulemap` into a single `include/module.modulemap` path.
/// Wrapping each xcframework's headers in a module-name subdirectory keeps the
/// outputs distinct so multiple binary targets can coexist in one build graph.
enum HeadersStager {
    /// Populate `<stageRoot>/<moduleName>/` from `source` and drop a modulemap
    /// at the top of the subdirectory. Returns `stageRoot` — pass this to
    /// `XCFrameworkAssembler.Slice.headersDir`.
    @discardableResult
    static func stage(
        source: URL,
        stageRoot: URL,
        moduleName: String,
        umbrellaHeader: String
    ) throws -> URL {
        let fm = FileManager.default
        let moduleDir = stageRoot.appendingPathComponent(moduleName)
        try? fm.removeItem(at: moduleDir)
        try fm.createDirectory(at: moduleDir, withIntermediateDirectories: true)

        let entries = try fm.contentsOfDirectory(atPath: source.path)
        for entry in entries {
            let from = source.appendingPathComponent(entry)
            let to = moduleDir.appendingPathComponent(entry)
            try fm.copyItem(at: from, to: to)
        }

        try ModuleMapWriter.write(
            to: moduleDir,
            module: moduleName,
            umbrellaHeader: umbrellaHeader
        )
        return stageRoot
    }
}
