import Foundation

/// Writes a `module.modulemap` file into a headers directory so that the
/// resulting `.xcframework` is importable as a Swift/Clang module.
enum ModuleMapWriter {
    /// Single-header umbrella. Use when one header transitively includes the
    /// public surface (e.g. `dav1d/dav1d.h`, `ass/ass.h`).
    static func write(to headersDir: URL, module: String, umbrellaHeader: String) throws {
        let content = """
        module \(module) {
            header "\(umbrellaHeader)"
            export *
        }

        """
        try writeModuleMap(content, to: headersDir)
    }

    /// Umbrella-directory mode. Use when headers reference each other via
    /// `<subdir/foo.h>` and no single header pulls the whole surface — Clang
    /// will index every `.h` under `headersDir` and let module-internal
    /// includes resolve through the module's own header list. Needed for
    /// MoltenVK (mvk_vulkan.h does `#include <vulkan/vulkan.h>`).
    ///
    /// `uses` declares cross-module dependencies so Clang resolves
    /// `#include <foreign/header.h>` in *our* headers against the foreign
    /// module's map (e.g. Libplacebo uses MoltenVK for Vulkan headers).
    static func writeUmbrellaDir(to headersDir: URL, module: String, uses: [String] = []) throws {
        var lines = ["module \(module) {", "    umbrella \".\""]
        for dep in uses {
            lines.append("    use \(dep)")
        }
        lines.append("    export *")
        lines.append("    module * { export * }")
        lines.append("}")
        lines.append("")
        try writeModuleMap(lines.joined(separator: "\n"), to: headersDir)
    }

    private static func writeModuleMap(_ content: String, to headersDir: URL) throws {
        let dest = headersDir.appendingPathComponent("module.modulemap")
        try FileManager.default.createDirectory(
            at: headersDir,
            withIntermediateDirectories: true
        )
        try content.write(to: dest, atomically: true, encoding: .utf8)
    }
}
