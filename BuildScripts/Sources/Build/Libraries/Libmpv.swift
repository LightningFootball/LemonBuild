import Foundation

struct LibmpvBuilder: LibraryBuilder {
    let spec = LibrarySpec(
        name: "libmpv",
        version: "v0.41.0",
        source: .git(url: "https://github.com/mpv-player/mpv.git", ref: "v0.41.0"),
        buildSystem: .meson,
        dependencies: ["ffmpeg", "libass", "libplacebo", "moltenvk", "uchardet"],
        xcframeworkName: "Libmpv",
        moduleName: "Libmpv"
    )

    func buildSlice(context: BuildContext) throws -> InstallArtifact {
        try applyPatches(sourceDir: context.sourceDir)

        let meson = MesonBuilder(
            toolchain: context.toolchain,
            sourceDir: context.sourceDir,
            buildDir: context.buildDir,
            installDir: context.installDir,
            extraSetupArgs: Self.mesonFlags,
            extraEnv: context.pkgConfigEnv
        )
        try meson.configure()
        try meson.build()
        try meson.install()

        let staticLib = context.installDir.appendingPathComponent("lib/libmpv.a")
        let stage = context.installDir.appendingPathComponent("Headers")
        try HeadersStager.stage(
            source: context.installDir.appendingPathComponent("include"),
            stageRoot: stage,
            moduleName: spec.moduleName,
            umbrellaHeader: "mpv/client.h"
        )
        return InstallArtifact(staticLibrary: staticLib, headersRoot: stage)
    }

    /// Apply our in-tree patches + drop the new `context_moltenvk.m` into the
    /// source tree. Idempotent via a stamp file.
    private func applyPatches(sourceDir: URL) throws {
        let fm = FileManager.default
        let patchesDir = sourceDir
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("patches/mpv")
        let stampFile = sourceDir.appendingPathComponent(".lemonbuild-patches-applied")
        if fm.fileExists(atPath: stampFile.path) { return }
        guard fm.fileExists(atPath: patchesDir.path) else {
            throw NSError(
                domain: "LemonBuild.Libmpv",
                code: 30,
                userInfo: [NSLocalizedDescriptionKey: "patches/mpv/ not found at \(patchesDir.path)"]
            )
        }
        let patches = try fm.contentsOfDirectory(atPath: patchesDir.path)
            .filter { $0.hasSuffix(".patch") }
            .sorted()
        for p in patches {
            try Shell.run(
                "git", "-C", sourceDir.path,
                "apply", "--whitespace=nowarn",
                patchesDir.appendingPathComponent(p).path
            )
        }
        // Copy the new source file into place. Kept out of the .patch stream
        // because formatting a 140-line new-file hunk by hand is brittle
        // (`@@ -0,0 +1,N @@` line-count mismatch rejects the patch).
        let contextSource = patchesDir.appendingPathComponent("context_moltenvk.m")
        if fm.fileExists(atPath: contextSource.path) {
            let target = sourceDir
                .appendingPathComponent("video/out/vulkan/context_moltenvk.m")
            try? fm.removeItem(at: target)
            try fm.copyItem(at: contextSource, to: target)
        }
        try "applied\n".write(to: stampFile, atomically: true, encoding: .utf8)
    }

    /// iOS player build: turn off everything that isn't libmpv + vulkan +
    /// moltenvk + audiounit + hwdec(videotoolbox). No CLI, no Lua, no tests,
    /// no platform integrations other than Apple-Metal path.
    private static let mesonFlags: [String] = [
        "-Dgpl=false",
        "-Dlibmpv=true",
        "-Dcplayer=false",
        "-Dtests=false",
        "-Dbuild-date=false",

        // Vulkan + MoltenVK (the point of this whole exercise).
        "-Dvulkan=enabled",
        "-Dmoltenvk=enabled",

        // Apple audio.
        "-Daudiounit=enabled",
        "-Dcoreaudio=disabled",
        "-Davfoundation=disabled",

        // Apple-specific bits we do want.
        "-Dvideotoolbox-pl=enabled",

        // Kill everything else.
        "-Dcdda=disabled",
        "-Dcplugins=disabled",
        "-Ddvbin=disabled",
        "-Ddvdnav=disabled",
        "-Dcaca=disabled",
        "-Dcocoa=disabled",
        "-Dd3d11=disabled",
        "-Ddirect3d=disabled",
        "-Ddmabuf-wayland=disabled",
        "-Dgl=disabled",
        "-Dgl-cocoa=disabled",
        "-Dios-gl=disabled",
        "-Dvideotoolbox-gl=disabled",
        "-Dmacos-cocoa-cb=disabled",
        "-Dmacos-media-player=disabled",
        "-Dmacos-touchbar=disabled",
        "-Dswift-build=disabled",
        "-Dalsa=disabled",
        "-Djack=disabled",
        "-Dopenal=disabled",
        "-Daudiotrack=disabled",
        "-Daaudio=disabled",
        "-Dopensles=disabled",
        "-Doss-audio=disabled",
        "-Dpipewire=disabled",
        "-Dpulse=disabled",
        "-Dsdl2-audio=disabled",
        "-Dsndio=disabled",
        "-Dwasapi=disabled",
        "-Djavascript=disabled",
        "-Djpeg=disabled",
        "-Dlcms2=disabled",
        "-Dlibarchive=disabled",
        "-Dlibavdevice=disabled",
        "-Dlibbluray=disabled",
        "-Dlua=disabled",
        "-Drubberband=disabled",
        "-Dsdl2-gamepad=disabled",
        "-Dvapoursynth=disabled",
        "-Dzimg=disabled",
        "-Dzlib=enabled",

        // libass is a hard dependency in mpv (no meson option) — pkg-config
        // is enough. uchardet is opt-in.
        "-Duchardet=enabled",

        // Misc platform things we don't want.
        "-Dmanpage-build=disabled",
        "-Dhtml-build=disabled",
        "-Dpdf-build=disabled",
        "-Dx11=disabled",
        "-Dwayland=disabled",
        "-Dxv=disabled",
        "-Ddrm=disabled",
        "-Degl=disabled",
        "-Degl-android=disabled",
        "-Degl-angle=disabled",
        "-Degl-angle-lib=disabled",
        "-Degl-angle-win32=disabled",
        "-Degl-drm=disabled",
        "-Degl-wayland=disabled",
        "-Degl-x11=disabled",
        "-Dgl-dxinterop=disabled",
        "-Dgl-win32=disabled",
        "-Dgl-x11=disabled",
        "-Dplain-gl=disabled",
        "-Dvdpau=disabled",
        "-Dvdpau-gl-x11=disabled",
        "-Dvaapi=disabled",
        "-Dvaapi-drm=disabled",
        "-Dvaapi-wayland=disabled",
        "-Dvaapi-x11=disabled",
        "-Dd3d-hwaccel=disabled",
        "-Dd3d9-hwaccel=disabled",
        "-Dandroid-media-ndk=disabled",
        "-Dcuda-hwaccel=disabled",
        "-Dcuda-interop=disabled"
    ]
}
