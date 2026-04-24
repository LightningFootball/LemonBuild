import Foundation

/// MoltenVK ships prebuilt binaries via GitHub releases. Building from source
/// requires Vulkan-Headers, cereal, SPIRV-Cross, SPIRV-Tools, glslang — a
/// significantly heavier graph than just re-packaging the official tarball.
///
/// This builder:
///   1. Downloads `MoltenVK-all.tar` once and caches it under `work/moltenvk/.archives/`
///   2. Picks the matching slice out of the upstream `static/MoltenVK.xcframework`
///      (arm64 passthrough for device, `lipo -extract arm64` for the fat sim slice)
///   3. Copies the bundled Vulkan + MoltenVK headers into our install prefix
///   4. Writes a `vulkan.pc` so libplacebo can discover the Vulkan loader via pkg-config
struct MoltenVKBuilder: LibraryBuilder {
    let spec = LibrarySpec(
        name: "moltenvk",
        version: "1.4.1",
        source: .tarball(
            url: "https://github.com/KhronosGroup/MoltenVK/releases/download/v1.4.1/MoltenVK-all.tar",
            sha256: "2c498bf8c98b88ba1e84c1f153403d4c1a8490c122d9e2a3df238b25d4e10557"
        ),
        buildSystem: .xcodebuild,
        dependencies: [],
        xcframeworkName: "MoltenVK",
        moduleName: "MoltenVK"
    )

    func buildSlice(context: BuildContext) throws -> InstallArtifact {
        let fm = FileManager.default
        let upstreamXCFramework = context.sourceDir
            .appendingPathComponent("MoltenVK/MoltenVK/static/MoltenVK.xcframework")
        let upstreamHeaders = context.sourceDir
            .appendingPathComponent("MoltenVK/MoltenVK/include")

        let libDir = context.installDir.appendingPathComponent("lib")
        let includeDir = context.installDir.appendingPathComponent("include")
        try? fm.removeItem(at: context.installDir)
        try fm.createDirectory(at: libDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: includeDir, withIntermediateDirectories: true)

        let outLib = libDir.appendingPathComponent("libMoltenVK.a")
        switch context.toolchain.platform {
        case .iOSDevice:
            let src = upstreamXCFramework.appendingPathComponent("ios-arm64/libMoltenVK.a")
            try fm.copyItem(at: src, to: outLib)
        case .iOSSimulator:
            let src = upstreamXCFramework.appendingPathComponent("ios-arm64_x86_64-simulator/libMoltenVK.a")
            try Shell.run("lipo", "-extract", "arm64", src.path, "-output", outLib.path)
        }

        // Mirror the bundled Vulkan + MoltenVK headers into our install prefix.
        for subdir in ["MoltenVK", "vulkan", "vk_video"] {
            let from = upstreamHeaders.appendingPathComponent(subdir)
            guard fm.fileExists(atPath: from.path) else { continue }
            try fm.copyItem(at: from, to: includeDir.appendingPathComponent(subdir))
        }

        try writeVulkanPkgConfig(installDir: context.installDir, version: spec.version)

        // Drop Vulkan-Hpp (C++ bindings) and the non-iOS platform headers
        // that are part of the upstream Vulkan SDK. Umbrella mode walks every
        // file it finds; those platform headers reference types (HWND, zx_*,
        // IDirectFB, …) that don't exist on iOS and fail module compilation.
        try prunePlatformHeaders(from: includeDir.appendingPathComponent("vulkan"))

        let stage = context.installDir.appendingPathComponent("Headers")
        try HeadersStager.stage(
            source: includeDir,
            stageRoot: stage,
            moduleName: spec.moduleName,
            style: .umbrellaDir()
        )
        // Our `HeadersStager` wraps the headers under an extra
        // `Headers/MoltenVK/` directory so modulemaps don't collide in SPM's
        // `include/` flattening. That wrap also buries the `MoltenVK/`,
        // `vulkan/`, and `vk_video/` subdirectories one level deeper than the
        // upstream layout assumes, so `#include <MoltenVK/…>`, `#include
        // <vulkan/…>`, and `#include <vk_video/…>` self-references inside
        // MoltenVK's bundled headers can no longer resolve via `-I`. Rewrite
        // them to `../<subdir>/<file>`: from any sibling directory inside the
        // module root, `..` bounces back to that root, then re-enters.
        let moduleRoot = stage.appendingPathComponent(spec.moduleName)
        try IncludeRewriter.rewriteSelfIncludes(
            in: moduleRoot,
            prefixes: ["MoltenVK", "vulkan", "vk_video"],
            replacement: { prefix, name, depth in
                let ups = String(repeating: "../", count: max(depth, 1))
                return "\(ups)\(prefix)/\(name)"
            },
            recursive: true
        )
        return InstallArtifact(staticLibrary: outLib, headersRoot: stage)
    }

    /// Remove headers that can't compile on iOS: Vulkan-Hpp (`*.hpp`) and the
    /// platform-specific extension headers for Windows / Android / Fuchsia /
    /// DirectFB / GGP / OHOS / Screen / Wayland / Xcb / Xlib / SCI.
    private func prunePlatformHeaders(from dir: URL) throws {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: dir.path) else { return }
        let nonApplePlatforms: Set<String> = [
            "vulkan_android.h", "vulkan_directfb.h", "vulkan_fuchsia.h",
            "vulkan_ggp.h", "vulkan_ohos.h", "vulkan_screen.h",
            "vulkan_wayland.h", "vulkan_win32.h",
            "vulkan_xcb.h", "vulkan_xlib.h", "vulkan_xlib_xrandr.h",
            "vulkan_sci.h"
        ]
        // `vk_icd.h` / `vk_layer.h` are Vulkan loader internals — they
        // reference CAMetalLayer without a forward decl, which trips
        // umbrella-dir module compilation. Consumers never need them.
        let loaderInternals: Set<String> = ["vk_icd.h", "vk_layer.h"]
        for entry in entries where entry.hasSuffix(".hpp")
            || nonApplePlatforms.contains(entry)
            || loaderInternals.contains(entry) {
            try fm.removeItem(at: dir.appendingPathComponent(entry))
        }
    }


    /// libplacebo's meson resolves Vulkan via `dependency('vulkan')` — there is
    /// no upstream `vulkan.pc` with MoltenVK, so we synthesize one. Foundation /
    /// Metal / QuartzCore / IOSurface are the frameworks MoltenVK requires at
    /// runtime per the upstream README; expose them in `Libs` so downstream
    /// consumers that probe via pkg-config know what to link.
    private func writeVulkanPkgConfig(installDir: URL, version: String) throws {
        let pcDir = installDir.appendingPathComponent("lib/pkgconfig")
        try FileManager.default.createDirectory(at: pcDir, withIntermediateDirectories: true)
        let pc = """
        prefix=\(installDir.path)
        includedir=${prefix}/include
        libdir=${prefix}/lib

        Name: Vulkan-Loader
        Description: Vulkan API (via MoltenVK on Apple platforms)
        Version: \(version)
        Libs: -L${libdir} -lMoltenVK -framework Foundation -framework Metal -framework QuartzCore -framework IOSurface
        Cflags: -I${includedir}
        """
        try pc.write(
            to: pcDir.appendingPathComponent("vulkan.pc"),
            atomically: true,
            encoding: .utf8
        )
    }
}
