import Foundation

struct LibplaceboBuilder: LibraryBuilder {
    let spec = LibrarySpec(
        name: "libplacebo",
        version: "v7.360.1",
        source: .git(url: "https://code.videolan.org/videolan/libplacebo.git", ref: "v7.360.1"),
        buildSystem: .meson,
        dependencies: ["shaderc", "moltenvk"],
        xcframeworkName: "Libplacebo",
        moduleName: "Libplacebo"
    )

    func buildSlice(context: BuildContext) throws -> InstallArtifact {
        try ensureJinja2Available()
        try ensureSubmodules(at: context.sourceDir)
        let vkRegistry = try ensureVulkanRegistry(workspace: context.buildDir.deletingLastPathComponent().deletingLastPathComponent())

        let meson = MesonBuilder(
            toolchain: context.toolchain,
            sourceDir: context.sourceDir,
            buildDir: context.buildDir,
            installDir: context.installDir,
            extraSetupArgs: [
                "-Dvulkan=enabled",
                "-Dvk-proc-addr=enabled",
                "-Dshaderc=enabled",
                "-Dglslang=disabled",
                "-Dlcms=disabled",
                "-Dxxhash=disabled",
                "-Dopengl=disabled",
                "-Dd3d11=disabled",
                "-Dgl-proc-addr=disabled",
                "-Ddovi=disabled",
                "-Dlibdovi=disabled",
                "-Dunwind=disabled",
                "-Dvulkan-registry=\(vkRegistry.path)",
                "-Ddemos=false",
                "-Dtests=false",
                "-Dbench=false",
                "-Dfuzz=false"
            ],
            extraEnv: context.pkgConfigEnv
        )
        try meson.configure()
        try meson.build()
        try meson.install()

        let staticLib = context.installDir.appendingPathComponent("lib/libplacebo.a")

        // libplacebo installs all backend headers (d3d11.h, opengl.h) even
        // when their meson feature is disabled. Drop them from the install
        // dir altogether — neither mpv nor any other downstream consumer on
        // iOS will compile against them, and the `#include <windows.h>` /
        // `<GL/gl.h>` blow up umbrella-dir module compilation later.
        let includeDir = context.installDir.appendingPathComponent("include/libplacebo")
        for h in ["d3d11.h", "opengl.h"] {
            try? FileManager.default.removeItem(at: includeDir.appendingPathComponent(h))
        }

        let stage = context.installDir.appendingPathComponent("Headers")
        try HeadersStager.stage(
            source: context.installDir.appendingPathComponent("include"),
            stageRoot: stage,
            moduleName: spec.moduleName,
            // libplacebo/vulkan.h does `#include <vulkan/vulkan.h>`; declare
            // MoltenVK as a used module so Clang cross-resolves via its map.
            style: .umbrellaDir(uses: ["MoltenVK"])
        )
        // libplacebo's public headers self-reference via `#include <libplacebo/…>`.
        // The HeadersStager wrap moves those under `Libplacebo/libplacebo/`, so the
        // angle-bracket form can't resolve — rewrite to same-dir quoted paths.
        let moduleContent = stage.appendingPathComponent("\(spec.moduleName)/libplacebo")
        try IncludeRewriter.rewriteSelfIncludes(
            in: moduleContent,
            prefixes: ["libplacebo"],
            replacement: { _, name, depth in
                // From libplacebo/*.h (depth 0), same-dir: "name".
                // From libplacebo/shaders/*.h (depth 1): "../name".
                String(repeating: "../", count: depth) + name
            },
            recursive: true
        )
        // `libplacebo/vulkan.h` does `#include <vulkan/vulkan.h>` — a
        // cross-module reference to MoltenVK. Clang's `use MoltenVK` directive
        // doesn't change angle-bracket search-path resolution; to resolve
        // *inside* our wrapped include tree, rewrite to the co-located path.
        // `depth + 2` climbs out of both the `libplacebo/` subdir and the
        // `Libplacebo/` module wrap, landing at the shared `include/` root.
        try IncludeRewriter.rewriteSelfIncludes(
            in: moduleContent,
            prefixes: ["vulkan", "vk_video"],
            replacement: { prefix, name, depth in
                let ups = String(repeating: "../", count: depth + 2)
                return "\(ups)MoltenVK/\(prefix)/\(name)"
            },
            recursive: true
        )
        // utils/dav1d.{h,_internal.h} and utils/libav.{h,_internal.h} are
        // FFmpeg / dav1d integration glue. We keep them in the install dir
        // because libmpv `#includes` them at compile time, but drop them
        // from the staged xcframework tree: their cross-module references
        // (`<libavformat/...>`, `<dav1d/...>`) can't be made to resolve
        // through Lemon's binary-target Clang module compilation.
        let stagedUtils = moduleContent.appendingPathComponent("utils")
        for h in ["dav1d.h", "dav1d_internal.h", "libav.h", "libav_internal.h"] {
            try? FileManager.default.removeItem(at: stagedUtils.appendingPathComponent(h))
        }
        return InstallArtifact(staticLibrary: staticLib, headersRoot: stage)
    }

    /// libplacebo's build runs a Python script (`tools/glsl_preproc/main.py`)
    /// under whichever interpreter meson is using, and that script imports
    /// `jinja2`. Homebrew's Python blocks a plain `pip install` under PEP 668,
    /// so use the official escape hatch once, then no-op on subsequent runs.
    /// libplacebo's build generates `src/vulkan/utils_gen.c` by parsing the
    /// Vulkan API registry (`vk.xml`). MoltenVK's binary release bundles
    /// vulkan.h but not the registry. MoltenVK 1.4.1 ships VK_HEADER_VERSION
    /// 334; pick a registry tag *older* than that (SDK 1.4.321) so the
    /// generator never references structs/enums that aren't in MoltenVK's
    /// bundled headers. An older registry is always a strict subset.
    private func ensureVulkanRegistry(workspace: URL) throws -> URL {
        let dest = workspace.appendingPathComponent("vulkan-registry/vk.xml")
        if FileManager.default.fileExists(atPath: dest.path) { return dest }
        try FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Shell.run(
            "curl", "-fL",
            "-o", dest.path,
            "https://raw.githubusercontent.com/KhronosGroup/Vulkan-Headers/vulkan-sdk-1.4.321.0/registry/vk.xml"
        )
        return dest
    }

    /// libplacebo depends on `fast_float` via a git submodule (C++ header-only,
    /// used for fp parsing). `Download.ensureGit` does shallow clones without
    /// submodules, so explicitly pull them here.
    private func ensureSubmodules(at sourceDir: URL) throws {
        try Shell.run(
            "git", "-C", sourceDir.path,
            "submodule", "update", "--init", "--recursive", "--depth=1"
        )
    }

    private func ensureJinja2Available() throws {
        if (try? Shell.run("/usr/bin/env", args: ["python3", "-c", "import jinja2"])) != nil {
            return
        }
        try Shell.run(
            "/usr/bin/env",
            args: ["python3", "-m", "pip", "install", "--break-system-packages", "--quiet", "jinja2"]
        )
    }
}
