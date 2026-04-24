import Foundation

/// Produces a per-slice headers root whose layout is
/// `<root>/<ModuleName>/{module.modulemap, …headers…}`.
///
/// Why the nesting: SPM's binary-target ingestion flattens every xcframework's
/// `Headers/module.modulemap` into a single `include/module.modulemap` path.
/// Wrapping each xcframework's headers in a module-name subdirectory keeps the
/// outputs distinct so multiple binary targets can coexist in one build graph.
enum HeadersStager {
    enum ModuleMapStyle {
        /// Single-header umbrella; use when one header (`ass/ass.h` etc.)
        /// transitively pulls in everything public.
        case umbrellaHeader(String)
        /// Umbrella directory; Clang walks every `.h` under the staged module
        /// directory. Required when module-internal includes reference
        /// sibling headers via `<subdir/foo.h>` (e.g. MoltenVK).
        ///
        /// `uses` names other Clang modules this one pulls from via
        /// `#include` — Clang needs it to resolve `<foreign/header.h>`.
        case umbrellaDir(uses: [String] = [])
    }

    /// Populate `<stageRoot>/<moduleName>/` from `source` and drop a modulemap
    /// at the top of the subdirectory. Returns `stageRoot` — pass this to
    /// `XCFrameworkAssembler.Slice.headersDir`.
    @discardableResult
    static func stage(
        source: URL,
        stageRoot: URL,
        moduleName: String,
        style: ModuleMapStyle
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

        switch style {
        case .umbrellaHeader(let header):
            try ModuleMapWriter.write(to: moduleDir, module: moduleName, umbrellaHeader: header)
        case .umbrellaDir(let uses):
            try ModuleMapWriter.writeUmbrellaDir(to: moduleDir, module: moduleName, uses: uses)
        }
        return stageRoot
    }

    /// Back-compat convenience: most libraries just need a single umbrella header.
    @discardableResult
    static func stage(
        source: URL,
        stageRoot: URL,
        moduleName: String,
        umbrellaHeader: String
    ) throws -> URL {
        try stage(
            source: source,
            stageRoot: stageRoot,
            moduleName: moduleName,
            style: .umbrellaHeader(umbrellaHeader)
        )
    }
}
